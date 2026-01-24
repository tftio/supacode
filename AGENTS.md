## Build Commands

```bash
make build-ghostty-xcframework # Rebuild GhosttyKit from Zig source (requires mise)
make build-app # Build macOS app (Debug) via xcodebuild
make run-app # Build and launch Debug app
make lint # Run swiftlint
make test # Run all tests
make format # Run swift-format
```

## Architecture

Supacode is a macOS orchestrator for running multiple coding agents in parallel, using GhosttyKit as the underlying terminal.

### Core Data Flow

```
AppFeature (root TCA store)
 ├─ RepositoriesFeature (repos + worktrees)
 ├─ SettingsFeature (appearance, updates, repo settings)
 └─ Workspace/Terminal/Updater clients (side effects + app services)

WorktreeTerminalManager (global terminal state)
 └─ WorktreeTerminalState (per worktree)
 └─ Bonsplit (tab/pane management)
 └─ GhosttySurfaceView[] (one per terminal tab)

GhosttyRuntime (shared singleton)
 └─ ghostty_app_t (single C instance)
 └─ ghostty_surface_t[] (independent terminal sessions)
```

### Source Layout

```
supacode/
├─ App/ # App entry point, shortcuts, window identifiers
├─ Domain/ # Core business models (Repository, Worktree, etc.)
├─ Features/ # TCA features by domain: ├─ App/ # AppFeature (root reducer) ├─ Repositories/ # Sidebar, worktree views and reducer ├─ Settings/ # Settings views, models, reducer ├─ Terminal/ # Terminal tab views and state └─ Updates/ # App update feature
├─ Clients/ # TCA dependency clients: ├─ Git/ # GitClient (shell out to git/wt) ├─ Repositories/ # Persistence, watcher clients └─ ... # Terminal, Workspace, Settings, Updater
├─ Infrastructure/ # Low-level integrations: └─ Ghostty/ # Runtime, SurfaceView, Bridge, Manager
├─ Commands/ # macOS menu command handlers
└─ Support/ # Utilities (paths, etc.)
```

### Key Dependencies

- **TCA (swift-composable-architecture)**: App state, reducers, and side effects
- **Bonsplit**: Tab/pane splitting UI for terminal management
- **GhosttyKit**: Terminal emulator (built from Zig source in ThirdParty/ghostty)
- **Sparkle**: Auto-update framework
- **swift-dependencies**: Dependency injection for TCA clients

## Ghostty Keybindings Handling

- Ghostty keybindings are handled via runtime action callbacks in `GhosttySurfaceBridge`, not by app menu shortcuts.
- App-level tab actions should be triggered by Ghostty actions (`GHOSTTY_ACTION_NEW_TAB` / `GHOSTTY_ACTION_CLOSE_TAB`) to honor user custom bindings.
- `GhosttySurfaceView.performKeyEquivalent` routes bound keys to Ghostty first; only unbound keys fall through to the app.

## Code Guidelines

Always read `./docs/swift-rules.md` before writing Swift code. Key points:
- Target macOS 26.0+, Swift 6.2+
- Use `@ObservableState` for TCA feature state; use `@Observable` for non-TCA shared stores; never `ObservableObject`
- Modern SwiftUI only: `foregroundStyle()`, `NavigationStack`, `Button` over `onTapGesture()`
- Prefer Swift-native APIs over Foundation where they exist

## UX Standards

- Buttons must have tooltips explaining the action and associated hotkey
- Use Dynamic Type, avoid hardcoded font sizes
- Components should be layout-agnostic (parents control layout, children control appearance)

## Rules

- After a task, ensure the app builds: `make build-app`
- Use Peekabo skill to verify UI behavior if necessary
- To inspect a Swift PM package, clone it with `gj get {git_url}`

## References

- `git@github.com:ghostty-org/ghostty.git` - Dive into this codebase when implementing Ghostty features
- `git@github.com:khoi/git-wt.git` - Our git worktree wrapper, can be modified as needed
- `git@github.com:vivy-company/aizen.git` - A competitor, also use ghostty
