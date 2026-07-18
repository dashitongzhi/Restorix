#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SMOKE_BINARY="$(mktemp "${TMPDIR:-/tmp}/restorix-settings-coordinator.XXXXXX")"

cleanup() {
  rm -f "$SMOKE_BINARY"
}
trap cleanup EXIT

xcrun swiftc \
  "$ROOT_DIR/Restorix/Models/DockerModels.swift" \
  "$ROOT_DIR/Restorix/Models/BackupModels.swift" \
  "$ROOT_DIR/Restorix/Models/SettingsModels.swift" \
  "$ROOT_DIR/Restorix/Services/SettingsCoreBridging.swift" \
  "$ROOT_DIR/Restorix/Services/SettingsCoordinator.swift" \
  "$ROOT_DIR/script/SettingsCoordinatorSmoke.swift" \
  -framework AppKit \
  -framework ServiceManagement \
  -o "$SMOKE_BINARY"

"$SMOKE_BINARY"
