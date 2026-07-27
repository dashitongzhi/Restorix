#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER_SOURCE="$ROOT_DIR/Restorix/Services/CLICommandRunner.swift"
PROCESS_SUPPORT_SOURCE="$ROOT_DIR/Restorix/Services/CLIProcessSupport.swift"
LOCATOR_SOURCE="$ROOT_DIR/Restorix/Services/CLIExecutableLocator.swift"
BRIDGE_SOURCE="$ROOT_DIR/Restorix/Services/CoreBridge.swift"
SETTINGS_CORE_SOURCE="$ROOT_DIR/Restorix/Services/SettingsCoreBridging.swift"
KEYCHAIN_SOURCE="$ROOT_DIR/Restorix/Services/KeychainCredentialStore.swift"
DOCKER_MODELS_SOURCE="$ROOT_DIR/Restorix/Models/DockerModels.swift"
BACKUP_MODELS_SOURCE="$ROOT_DIR/Restorix/Models/BackupModels.swift"
SCAN_MODELS_SOURCE="$ROOT_DIR/Restorix/Models/ScanModels.swift"
SETTINGS_MODELS_SOURCE="$ROOT_DIR/Restorix/Models/SettingsModels.swift"
DIAGNOSTIC_MODELS_SOURCE="$ROOT_DIR/Restorix/Models/DiagnosticModels.swift"
LOCALIZATION_SOURCE="$ROOT_DIR/Restorix/Models/Localization.swift"
ENGLISH_STRINGS_SOURCE="$ROOT_DIR/Restorix/Models/EnglishStrings.swift"
CHINESE_STRINGS_SOURCE="$ROOT_DIR/Restorix/Models/SimplifiedChineseStrings.swift"
MARKDOWN_RENDERER_SOURCE="$ROOT_DIR/Restorix/Services/MarkdownReportRenderer.swift"
MARKDOWN_LOCALIZATION_SOURCE="$ROOT_DIR/Restorix/Services/MarkdownReportLocalization.swift"
SMOKE_SOURCE="$ROOT_DIR/script/CLICommandRunnerSmoke.swift"
SMOKE_SUPPORT_SOURCE="$ROOT_DIR/script/CLICommandRunnerSmokeSupport.swift"
FIXTURE="$ROOT_DIR/script/fixtures/cli_command_fixture.sh"
SMOKE_BINARY="$(mktemp "${TMPDIR:-/tmp}/restorix-cli-command-runner.XXXXXX")"
CONTRACT_FIXTURE="$(mktemp "${TMPDIR:-/tmp}/restorix-scan-contract.XXXXXX")"

cleanup() {
  rm -f "$SMOKE_BINARY" "$CONTRACT_FIXTURE"
}
trap cleanup EXIT

cargo run --quiet -p restorix-core --example scan_contract_fixture > "$CONTRACT_FIXTURE"

xcrun swiftc \
  "$RUNNER_SOURCE" \
  "$PROCESS_SUPPORT_SOURCE" \
  "$LOCATOR_SOURCE" \
  "$SETTINGS_CORE_SOURCE" \
  "$BRIDGE_SOURCE" \
  "$KEYCHAIN_SOURCE" \
  "$DIAGNOSTIC_MODELS_SOURCE" \
  "$DOCKER_MODELS_SOURCE" \
  "$BACKUP_MODELS_SOURCE" \
  "$SCAN_MODELS_SOURCE" \
  "$SETTINGS_MODELS_SOURCE" \
  "$LOCALIZATION_SOURCE" \
  "$ENGLISH_STRINGS_SOURCE" \
  "$CHINESE_STRINGS_SOURCE" \
  "$MARKDOWN_RENDERER_SOURCE" \
  "$MARKDOWN_LOCALIZATION_SOURCE" \
  "$SMOKE_SUPPORT_SOURCE" \
  "$SMOKE_SOURCE" \
  -framework Security \
  -o "$SMOKE_BINARY"
"$SMOKE_BINARY" "$FIXTURE" "$CONTRACT_FIXTURE"
