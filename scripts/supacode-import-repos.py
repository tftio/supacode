#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""
Additively import repository roots into ~/.supacode/{settings,sidebar}.json.

Layout assumed for every accepted argument:

    {reponame}/.git        bare clone (HEAD + objects + refs at the root)
    {reponame}/{branch}    linked worktree (sibling of .git)

Each invocation is *additive*: previously-imported repositories and the
sidebar groups they belong to are preserved. The script writes/refreshes:

    - global.worktreeDirectoryNaming = "replaceSlashesWithUnderscores"
    - repositories[<rid>].worktreeBaseDirectoryPath for each imported repo
      (other per-repo settings — scripts, openActionID, etc. — are kept)
    - one sidebar group per run, named after the common parent of the
      supplied paths; if the group already exists its repository list is
      replaced, and re-imported repos are removed from any other group
    - one sidebar section per imported repo (only created if missing, so
      existing pin/archive state is preserved)

Usage:
    supacode-import-repos.py <path>...

Typically the args come from a shell glob:

    supacode-import-repos.py ~/Projects/tftio/*
    supacode-import-repos.py ~/Work/Repositories/*
"""

from __future__ import annotations

import json
import os
import shutil
import sys
from datetime import datetime
from pathlib import Path

SUPACODE_DIR = Path.home() / ".supacode"
SETTINGS_PATH = SUPACODE_DIR / "settings.json"
SIDEBAR_PATH = SUPACODE_DIR / "sidebar.json"


# ---------------------------------------------------------------------------
# Pattern detection
# ---------------------------------------------------------------------------

def is_bare_git_dir(path: Path) -> bool:
    """Match supacode's heuristic at Repository.isGitRepository(at:)."""
    head = path / "HEAD"
    objects = path / "objects"
    refs = path / "refs"
    if not head.is_file():
        return False
    if not objects.is_dir() or not refs.is_dir():
        return False
    return True


def find_worktrees(repo_root: Path) -> list[Path]:
    worktrees: list[Path] = []
    for entry in sorted(repo_root.iterdir()):
        if not entry.is_dir() or entry.name == ".git":
            continue
        marker = entry / ".git"
        if marker.is_file():
            worktrees.append(entry)
    return worktrees


def classify(repo_root: Path) -> tuple[bool, str, list[Path]]:
    if not repo_root.is_dir():
        return False, "not a directory", []
    git_dir = repo_root / ".git"
    if not git_dir.is_dir():
        return False, "no .git directory at root", []
    if not is_bare_git_dir(git_dir):
        return False, ".git is not a bare-style git dir (missing HEAD/objects/refs)", []
    worktrees = find_worktrees(repo_root)
    if not worktrees:
        return False, "no linked-worktree siblings of .git", []
    return True, "", worktrees


# ---------------------------------------------------------------------------
# OrderedDictionary <-> alternating-array helpers
# ---------------------------------------------------------------------------
# Swift's OrderedDictionary (and [String: T]) encode as a flat
# [k, v, k, v, ...] JSON array. We round-trip through plain Python dicts
# while preserving order via insertion order (Python 3.7+ dict guarantee).

def alt_to_dict(arr: list | None) -> dict:
    if not arr:
        return {}
    if len(arr) % 2 != 0:
        raise ValueError(f"alternating array has odd length: {len(arr)}")
    out: dict = {}
    for i in range(0, len(arr), 2):
        out[arr[i]] = arr[i + 1]
    return out


def dict_to_alt(d: dict) -> list:
    out: list = []
    for k, v in d.items():
        out.append(k)
        out.append(v)
    return out


# ---------------------------------------------------------------------------
# Repo / sidebar value builders
# ---------------------------------------------------------------------------

def trailing_slash(p: Path) -> str:
    return str(p) + "/"


def repo_id_for(repo_root: Path) -> str:
    return trailing_slash(repo_root / ".git")


def worktree_id_for(worktree: Path) -> str:
    return trailing_slash(worktree)


def default_section(worktree_ids: list[str]) -> dict:
    items_array: list = []
    for wid in worktree_ids:
        items_array.append(wid)
        items_array.append({})
    buckets_array: list = [
        "unpinned",
        {"items": items_array},
        "pinned",
        {"items": []},
    ]
    return {"buckets": buckets_array, "collapsed": False}


def default_repo_settings(worktree_base: Path) -> dict:
    return {
        "archiveScript": "",
        "deleteScript": "",
        "openActionID": "auto",
        "runScript": "",
        "scripts": [],
        "setupScript": "",
        "worktreeBaseDirectoryPath": str(worktree_base),
    }


# ---------------------------------------------------------------------------
# IO
# ---------------------------------------------------------------------------

def common_parent(paths: list[Path]) -> Path:
    if len(paths) == 1:
        return paths[0].parent
    return Path(os.path.commonpath([str(p) for p in paths]))


def backup(path: Path) -> Path | None:
    if not path.exists():
        return None
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    dest = path.with_suffix(path.suffix + f".bak-{stamp}")
    shutil.copy2(path, dest)
    return dest


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    with path.open() as f:
        return json.load(f)


def write_json(path: Path, data: dict) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w") as f:
        json.dump(data, f, indent=2, sort_keys=True)
        f.write("\n")
    tmp.replace(path)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(argv: list[str]) -> int:
    if not argv:
        print("usage: supacode-import-repos.py <repo-root>...", file=sys.stderr)
        return 2

    candidates = [Path(a).expanduser().resolve() for a in argv]
    accepted: list[tuple[Path, list[Path]]] = []
    rejected: list[tuple[Path, str]] = []
    for cand in candidates:
        ok, reason, worktrees = classify(cand)
        (accepted if ok else rejected).append(
            (cand, worktrees) if ok else (cand, reason)
        )

    if rejected:
        print("Skipped (does not match {reponame}/.git + sibling worktree pattern):", file=sys.stderr)
        for path, reason in rejected:
            print(f"  {path}: {reason}", file=sys.stderr)

    if not accepted:
        print("No repositories matched the pattern; nothing to write.", file=sys.stderr)
        return 1

    group_root = common_parent([p for p, _ in accepted])
    group_title = str(group_root)
    group_id = group_title  # user said groups are renamed in-app.
    accepted_repo_ids = [repo_id_for(p) for p, _ in accepted]
    accepted_repo_id_set = set(accepted_repo_ids)

    # ---- settings.json (additive) ----
    settings = load_json(SETTINGS_PATH)
    settings.setdefault("global", {})
    settings["global"]["worktreeDirectoryNaming"] = "replaceSlashesWithUnderscores"
    settings.setdefault("pinnedWorktreeIDs", [])
    repositories: dict = settings.setdefault("repositories", {})
    repository_roots: list = settings.setdefault("repositoryRoots", [])
    existing_roots = set(repository_roots)
    for repo_root, _ in accepted:
        rid = repo_id_for(repo_root)
        existing = repositories.get(rid)
        if existing is None:
            repositories[rid] = default_repo_settings(repo_root)
        else:
            # Preserve user-set scripts / openActionID; only ensure the
            # base path points at the parent of `.git` so new worktrees
            # land as siblings of `main`.
            existing["worktreeBaseDirectoryPath"] = str(repo_root)
        # `repositoryRoots` is the canonical "which repos to load"
        # list the app reads on launch. Without it, sidebar sections
        # exist but no repository is discovered.
        if rid not in existing_roots:
            repository_roots.append(rid)
            existing_roots.add(rid)

    # ---- sidebar.json (additive) ----
    sidebar = load_json(SIDEBAR_PATH)
    sidebar["schemaVersion"] = sidebar.get("schemaVersion", 1)

    sections = alt_to_dict(sidebar.get("sections"))
    for repo_root, worktrees in accepted:
        rid = repo_id_for(repo_root)
        if rid not in sections:
            sections[rid] = default_section([worktree_id_for(w) for w in worktrees])
        # If the section already exists we leave it alone — the user may
        # have pinned or archived worktrees we don't want to clobber.
    sidebar["sections"] = dict_to_alt(sections)

    groups = alt_to_dict(sidebar.get("groups"))
    # Remove the just-imported repo IDs from any *other* group to avoid
    # duplicates, then upsert this run's group.
    for gid, group in list(groups.items()):
        if gid == group_id:
            continue
        ids = group.get("repositoryIDs", [])
        new_ids = [r for r in ids if r not in accepted_repo_id_set]
        if new_ids != ids:
            group["repositoryIDs"] = new_ids
    existing_group = groups.get(group_id, {})
    groups[group_id] = {
        "title": existing_group.get("title", group_title),
        "collapsed": existing_group.get("collapsed", False),
        "repositoryIDs": accepted_repo_ids,
        **({"color": existing_group["color"]} if "color" in existing_group else {}),
    }
    sidebar["groups"] = dict_to_alt(groups)

    # ---- write ----
    settings_backup = backup(SETTINGS_PATH)
    sidebar_backup = backup(SIDEBAR_PATH)
    write_json(SETTINGS_PATH, settings)
    write_json(SIDEBAR_PATH, sidebar)

    print(f"Imported {len(accepted)} repositories into group '{group_title}':")
    for repo_root, worktrees in accepted:
        print(f"  {repo_root}  ({len(worktrees)} worktree(s))")
    if settings_backup:
        print(f"settings.json backup: {settings_backup}")
    if sidebar_backup:
        print(f"sidebar.json backup:  {sidebar_backup}")
    print("Restart Supacode (or reload) to pick up the new state.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
