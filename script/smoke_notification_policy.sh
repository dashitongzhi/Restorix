#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SMOKE_BINARY="$(mktemp "${TMPDIR:-/tmp}/restorix-notification-policy.XXXXXX")"

cleanup() {
  rm -f "$SMOKE_BINARY"
}
trap cleanup EXIT

xcrun swiftc \
  "$ROOT_DIR/Restorix/Models/DiagnosticModels.swift" \
  "$ROOT_DIR/Restorix/Models/DockerModels.swift" \
  "$ROOT_DIR/Restorix/Models/BackupModels.swift" \
  "$ROOT_DIR/Restorix/Models/ScanModels.swift" \
  "$ROOT_DIR/Restorix/Models/Localization.swift" \
  "$ROOT_DIR/Restorix/Models/EnglishStrings.swift" \
  "$ROOT_DIR/Restorix/Models/SimplifiedChineseStrings.swift" \
  "$ROOT_DIR/Restorix/Services/NotificationPolicy.swift" \
  "$ROOT_DIR/Restorix/Services/NotificationAdapters.swift" \
  "$ROOT_DIR/Restorix/Services/NotificationCoordinator.swift" \
  "$ROOT_DIR/script/NotificationPolicySmoke.swift" \
  -framework UserNotifications \
  -o "$SMOKE_BINARY"

"$SMOKE_BINARY"
