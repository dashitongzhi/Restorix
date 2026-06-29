#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="${ROOT_DIR}/dist/Restorix.app"

cd "${ROOT_DIR}"

echo "[restorix-release] Packaging Restorix.app."
bash "${ROOT_DIR}/script/package_app.sh"

echo "[restorix-release] Running packaged app smoke flow."
bash "${ROOT_DIR}/script/smoke_restic_flow.sh" --app-bundle "${APP_BUNDLE}"

echo "Restorix packaged release verification passed."
