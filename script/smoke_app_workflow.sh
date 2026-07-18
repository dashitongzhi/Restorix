#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SMOKE_BINARY="$(mktemp "${TMPDIR:-/tmp}/restorix-app-workflow.XXXXXX")"

cleanup() {
  rm -f "$SMOKE_BINARY"
}
trap cleanup EXIT

xcrun swiftc \
  "$ROOT_DIR/Restorix/Services/CLICommandRunner.swift" \
  "$ROOT_DIR/Restorix/Services/CLIProcessSupport.swift" \
  "$ROOT_DIR/Restorix/Services/CLIExecutableLocator.swift" \
  "$ROOT_DIR/Restorix/Services/SettingsCoreBridging.swift" \
  "$ROOT_DIR/Restorix/Services/CoreBridge.swift" \
  "$ROOT_DIR/Restorix/Services/KeychainCredentialStore.swift" \
  "$ROOT_DIR/Restorix/Services/NotificationPolicy.swift" \
  "$ROOT_DIR/Restorix/Services/NotificationAdapters.swift" \
  "$ROOT_DIR/Restorix/Services/NotificationCoordinator.swift" \
  "$ROOT_DIR/Restorix/Services/AppWorkflow.swift" \
  "$ROOT_DIR/Restorix/Models/DiagnosticModels.swift" \
  "$ROOT_DIR/Restorix/Models/DockerModels.swift" \
  "$ROOT_DIR/Restorix/Models/BackupModels.swift" \
  "$ROOT_DIR/Restorix/Models/ScanModels.swift" \
  "$ROOT_DIR/Restorix/Models/SettingsModels.swift" \
  "$ROOT_DIR/Restorix/Models/Localization.swift" \
  "$ROOT_DIR/Restorix/Models/EnglishStrings.swift" \
  "$ROOT_DIR/Restorix/Models/SimplifiedChineseStrings.swift" \
  "$ROOT_DIR/script/AppWorkflowSmoke.swift" \
  -framework Security \
  -framework UserNotifications \
  -o "$SMOKE_BINARY"

"$SMOKE_BINARY"
