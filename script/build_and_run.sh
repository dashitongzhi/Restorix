#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Restorix"
PROJECT_NAME="Restorix.xcodeproj"
SCHEME="Restorix"
CONFIGURATION="Debug"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
APP_BUNDLE="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
CLI_SOURCE="$ROOT_DIR/target/debug/restorix"
CLI_DEST="$APP_BUNDLE/Contents/Resources/restorix"

cd "$ROOT_DIR"

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "xcodebuild requires a full Xcode developer directory." >&2
  echo "Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

cargo build
xcodebuild \
  -project "$PROJECT_NAME" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build

mkdir -p "$(dirname "$CLI_DEST")"
cp "$CLI_SOURCE" "$CLI_DEST"
chmod +x "$CLI_DEST"

SIGN_OUTPUT="$(/usr/bin/codesign -dv --verbose=4 "$APP_BUNDLE" 2>&1 || true)"
SIGN_IDENTITY="$(awk -F= '/Authority=Apple Development/{print $2; exit}' <<<"$SIGN_OUTPUT")"
if [[ -n "$SIGN_IDENTITY" ]]; then
  /usr/bin/codesign --force --deep --sign "$SIGN_IDENTITY" --options runtime --timestamp=none "$APP_BUNDLE"
else
  /usr/bin/codesign --force --deep --sign - "$APP_BUNDLE"
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"Kral.Restorix\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
