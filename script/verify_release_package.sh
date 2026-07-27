#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="${ROOT_DIR}/dist/Restorix.app"
APP_EXECUTABLE="${APP_BUNDLE}/Contents/MacOS/Restorix"
CLI_EXECUTABLE="${APP_BUNDLE}/Contents/Resources/restorix"

cd "${ROOT_DIR}"

echo "[restorix-release] Packaging Restorix.app."
bash "${ROOT_DIR}/script/package_app.sh"

verify_universal_binary() {
  local binary="$1"
  local label="$2"

  if [[ ! -f "$binary" ]]; then
    echo "[restorix-release] Missing ${label}: ${binary}" >&2
    return 1
  fi

  local architecture
  for architecture in arm64 x86_64; do
    if ! lipo "$binary" -verify_arch "$architecture"; then
      echo "[restorix-release] ${label} must contain both arm64 and x86_64 slices." >&2
      lipo -archs "$binary" >&2 || true
      return 1
    fi
  done

  echo "[restorix-release] ${label} architectures: $(lipo -archs "$binary")"
}

echo "[restorix-release] Verifying universal release binaries."
verify_universal_binary "$APP_EXECUTABLE" "Restorix app executable"
verify_universal_binary "$CLI_EXECUTABLE" "embedded restorix CLI"

echo "[restorix-release] Running packaged app smoke flow."
bash "${ROOT_DIR}/script/smoke_restic_flow.sh" --app-bundle "${APP_BUNDLE}"

echo "Restorix packaged release verification passed."
