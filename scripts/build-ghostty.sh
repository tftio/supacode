#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script_path="${script_dir}/$(basename "${BASH_SOURCE[0]}")"
srcroot="${SRCROOT:-$(cd "${script_dir}/.." && pwd)}"
repo_root="${srcroot}"
ghostty_dir="${srcroot}/ThirdParty/ghostty"
ghostty_submodule_path="${ghostty_dir#"${repo_root}/"}"
ghostty_build_root="${srcroot}/.build/ghostty"
ghostty_local_cache_dir="${ghostty_build_root}/.zig-cache"
ghostty_global_cache_dir="${ghostty_build_root}/.zig-global-cache"
ghostty_fingerprint_path="${ghostty_build_root}/fingerprint"
ghostty_legacy_prefix_path="${ghostty_dir}/zig-out"
ghostty_legacy_share_path="${ghostty_legacy_prefix_path}/share"
xcframework_path="${ghostty_build_root}/GhosttyKit.xcframework"
ghostty_resources_path="${ghostty_build_root}/share/ghostty"
ghostty_terminfo_path="${ghostty_build_root}/share/terminfo"

print_fingerprint() {
  (
    cd "${ghostty_dir}"
    {
      git rev-parse HEAD
      git diff --no-ext-diff --no-color HEAD -- . | shasum -a 256
      git ls-files --others --exclude-standard | LC_ALL=C sort | shasum -a 256
      shasum -a 256 "${script_path}" | awk '{print $1}'
      shasum -a 256 "${srcroot}/mise.toml" | awk '{print $1}'
    } | shasum -a 256 | awk '{print $1}'
  )
}

prepare_xcframework() {
  local modulemap
  find "${xcframework_path}" -path '*/Headers/module.modulemap' -print0 | while IFS= read -r -d '' modulemap; do
    cat > "${modulemap}" <<'EOF'
module GhosttyKit {
    header "ghostty.h"
    export *
}
EOF
  done
}

configure_zig_xcrun_shim() {
  if [ "$(uname -s)" != "Darwin" ] || [ "$(uname -m)" != "arm64" ]; then
    return
  fi

  local active_sdk
  active_sdk="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
  if [ -z "${active_sdk}" ] || [ ! -f "${active_sdk}/usr/lib/libSystem.tbd" ]; then
    return
  fi

  if sed -n '1,5p' "${active_sdk}/usr/lib/libSystem.tbd" | grep -q 'arm64-macos'; then
    return
  fi

  local fallback_sdk
  fallback_sdk=""
  local candidate
  for candidate in /Library/Developer/CommandLineTools/SDKs/MacOSX15*.sdk /Library/Developer/CommandLineTools/SDKs/MacOSX14*.sdk /Library/Developer/CommandLineTools/SDKs/MacOSX13*.sdk; do
    if [ -f "${candidate}/usr/lib/libSystem.tbd" ] &&
      sed -n '1,5p' "${candidate}/usr/lib/libSystem.tbd" | grep -q 'arm64-macos'; then
      fallback_sdk="${candidate}"
      break
    fi
  done

  if [ -z "${fallback_sdk}" ]; then
    return
  fi

  local fallback_sdk_version
  fallback_sdk_version="$(basename "${fallback_sdk}" | sed -E 's/^MacOSX//; s/[.]sdk$//')"

  local shim_dir
  shim_dir="${ghostty_build_root}/xcrun-shim"
  mkdir -p "${shim_dir}"
  cat > "${shim_dir}/xcrun" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "--sdk" ] && [ "\${2:-}" = "macosx" ] && [ "\${3:-}" = "--show-sdk-path" ]; then
  printf '%s\n' "${fallback_sdk}"
  exit 0
fi
if [ "\${1:-}" = "--sdk" ] && [ "\${2:-}" = "macosx" ] && [ "\${3:-}" = "--show-sdk-version" ]; then
  printf '%s\n' "${fallback_sdk_version}"
  exit 0
fi
exec /usr/bin/xcrun "\$@"
EOF
  chmod +x "${shim_dir}/xcrun"
  export PATH="${shim_dir}:${PATH}"
  echo "Using ${fallback_sdk} for Zig macOS SDK compatibility" >&2
}

ensure_ghostty_checkout() {
  if [ -f "${ghostty_dir}/build.zig" ]; then
    return
  fi

  git -C "${repo_root}" submodule sync --recursive -- "${ghostty_submodule_path}"
  git -C "${repo_root}" submodule update --init --recursive -- "${ghostty_submodule_path}"

  if [ ! -f "${ghostty_dir}/build.zig" ]; then
    echo "error: missing ${ghostty_dir} after submodule update" >&2
    exit 1
  fi
}

ensure_ghostty_checkout

if [ "${1:-}" = "--print-fingerprint" ]; then
  print_fingerprint
  exit 0
fi

fingerprint="$(print_fingerprint)"

rm -rf "${ghostty_legacy_prefix_path}"
mkdir -p "${ghostty_build_root}" "${ghostty_legacy_prefix_path}"
ln -s "${ghostty_build_root}/share" "${ghostty_legacy_share_path}"

if [ -f "${ghostty_fingerprint_path}" ] &&
  [ -d "${xcframework_path}" ] &&
  [ -d "${ghostty_resources_path}" ] &&
  [ -d "${ghostty_terminfo_path}" ] &&
  [ "$(cat "${ghostty_fingerprint_path}")" = "${fingerprint}" ]; then
  exit 0
fi

cd "${ghostty_dir}"
configure_zig_xcrun_shim
mise exec -- zig build -Doptimize=ReleaseFast -Demit-xcframework=true -Demit-macos-app=false -Dsentry=false --prefix "${ghostty_build_root}" --cache-dir "${ghostty_local_cache_dir}" --global-cache-dir "${ghostty_global_cache_dir}"
rsync -a --delete "${ghostty_dir}/macos/GhosttyKit.xcframework/" "${xcframework_path}/"
prepare_xcframework
printf '%s\n' "${fingerprint}" > "${ghostty_fingerprint_path}"
