#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Restorix"
PROJECT_NAME="Restorix.xcodeproj"
SCHEME="Restorix"
CONFIGURATION="Release"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/build/PackageDerivedData"
BUILD_APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
CLI_SOURCE="$ROOT_DIR/target/release/restorix"
CLI_DEST="$BUILD_APP/Contents/Resources/restorix"
DIST_DIR="$ROOT_DIR/dist"
DIST_APP="$DIST_DIR/$APP_NAME.app"
DIST_ZIP="$DIST_DIR/Restorix-macos-standalone.zip"
DIST_DMG="$DIST_DIR/Restorix-macos-standalone.dmg"
DIST_DMG_TMP=""
XCODEBUILD_COMMAND=(
  xcodebuild
  -project "$PROJECT_NAME"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -derivedDataPath "$DERIVED_DATA"
  build
)

if [[ -n "${RESTORIX_XCODEBUILD_CODE_SIGNING_ALLOWED:-}" ]]; then
  XCODEBUILD_COMMAND+=("CODE_SIGNING_ALLOWED=${RESTORIX_XCODEBUILD_CODE_SIGNING_ALLOWED}")
fi

cd "$ROOT_DIR"
cleanup() {
  [[ -z "$DIST_DMG_TMP" ]] || rm -f "$DIST_DMG_TMP"
}
trap cleanup EXIT

detach_existing_dist_dmg() {
  local devices
  devices="$(
    hdiutil info | awk -v image_path="$DIST_DMG" '
      $1 == "image-path" && $3 == image_path {
        in_image = 1
        next
      }
      /^=+$/ {
        in_image = 0
      }
      in_image && $1 ~ /^\/dev\/disk[0-9]+$/ {
        print $1
      }
    '
  )"

  for device in $devices; do
    hdiutil detach "$device" -force >/dev/null 2>&1 || true
  done
}

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "xcodebuild requires a full Xcode developer directory." >&2
  echo "Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

cargo build --release -p restorix-cli

"${XCODEBUILD_COMMAND[@]}"

mkdir -p "$(dirname "$CLI_DEST")"
cp "$CLI_SOURCE" "$CLI_DEST"
chmod +x "$CLI_DEST"

SIGN_OUTPUT="$(/usr/bin/codesign -dv --verbose=4 "$BUILD_APP" 2>&1 || true)"
SIGN_IDENTITY="$(awk -F= '/Authority=Apple Development/{print $2; exit}' <<<"$SIGN_OUTPUT")"
if [[ -n "$SIGN_IDENTITY" ]]; then
  /usr/bin/codesign --force --deep --sign "$SIGN_IDENTITY" --options runtime --timestamp=none "$BUILD_APP"
else
  /usr/bin/codesign --force --deep --sign - "$BUILD_APP"
fi

/usr/bin/codesign --verify --deep --strict --verbose=2 "$BUILD_APP"
CLI_CHECK="$(mktemp -t restorix-cli-check)"
cp "$CLI_DEST" "$CLI_CHECK"
chmod +x "$CLI_CHECK"
"$CLI_CHECK" --help >/dev/null
rm -f "$CLI_CHECK"

detach_existing_dist_dmg
rm -rf "$DIST_APP" "$DIST_ZIP" "$DIST_DMG"
mkdir -p "$DIST_DIR"
ditto "$BUILD_APP" "$DIST_APP"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$DIST_APP"
ditto -c -k --keepParent "$DIST_APP" "$DIST_ZIP"
DIST_DMG_TMP="$(mktemp "$DIST_DIR/.Restorix-macos-standalone.XXXXXX.dmg")"
rm -f "$DIST_DMG_TMP"
hdiutil create -volname "$APP_NAME" -srcfolder "$DIST_APP" -ov -format UDZO "$DIST_DMG_TMP" >/dev/null
mv -f "$DIST_DMG_TMP" "$DIST_DMG"
DIST_DMG_TMP=""

echo "Standalone app: $DIST_APP"
echo "Zip package: $DIST_ZIP"
echo "DMG package: $DIST_DMG"
