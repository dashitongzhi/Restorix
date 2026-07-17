#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER_SOURCE="$ROOT_DIR/Restorix/Services/CLICommandRunner.swift"
BRIDGE_SOURCE="$ROOT_DIR/Restorix/Services/CoreBridge.swift"
KEYCHAIN_SOURCE="$ROOT_DIR/Restorix/Services/KeychainCredentialStore.swift"
MODELS_SOURCE="$ROOT_DIR/Restorix/Models/AppModels.swift"
LOCALIZATION_SOURCE="$ROOT_DIR/Restorix/Models/Localization.swift"
SMOKE_SOURCE="$ROOT_DIR/script/CLICommandRunnerSmoke.swift"
FIXTURE="$ROOT_DIR/script/fixtures/cli_command_fixture.sh"
SMOKE_BINARY="$(mktemp "${TMPDIR:-/tmp}/restorix-cli-command-runner.XXXXXX")"

cleanup() {
  rm -f "$SMOKE_BINARY"
}
trap cleanup EXIT

xcrun swiftc \
  "$RUNNER_SOURCE" \
  "$BRIDGE_SOURCE" \
  "$KEYCHAIN_SOURCE" \
  "$MODELS_SOURCE" \
  "$LOCALIZATION_SOURCE" \
  "$SMOKE_SOURCE" \
  -framework Security \
  -o "$SMOKE_BINARY"
"$SMOKE_BINARY" "$FIXTURE"
