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
PACKAGE_MODE="${RESTORIX_PACKAGE_MODE:-${RESTORIX_DISTRIBUTION_MODE:-local}}"
DEVELOPER_ID_APPLICATION="${RESTORIX_DEVELOPER_ID_APPLICATION:-${RESTORIX_SIGNING_IDENTITY:-}}"
DEVELOPMENT_TEAM="${RESTORIX_DEVELOPMENT_TEAM:-}"
NOTARY_KEYCHAIN_PROFILE="${RESTORIX_NOTARY_KEYCHAIN_PROFILE:-}"
NOTARY_APPLE_ID="${RESTORIX_NOTARY_APPLE_ID:-}"
NOTARY_PASSWORD="${RESTORIX_NOTARY_PASSWORD:-}"
NOTARY_TEAM_ID="${RESTORIX_NOTARY_TEAM_ID:-${DEVELOPMENT_TEAM}}"
NOTARIZE="${RESTORIX_NOTARIZE:-}"
STAPLE="${RESTORIX_STAPLE:-}"
GATEKEEPER_VERIFY="${RESTORIX_GATEKEEPER_VERIFY:-}"

usage() {
  cat <<EOF
usage: RESTORIX_PACKAGE_MODE=local|developer-id $0

Production Developer ID mode:
  RESTORIX_PACKAGE_MODE=developer-id
  RESTORIX_DEVELOPER_ID_APPLICATION="Developer ID Application: Name (TEAMID)"
  RESTORIX_NOTARIZE=1

Notary credentials can be supplied with either:
  RESTORIX_NOTARY_KEYCHAIN_PROFILE

or:
  RESTORIX_NOTARY_APPLE_ID
  RESTORIX_NOTARY_PASSWORD
  RESTORIX_NOTARY_TEAM_ID
EOF
}

if [[ $# -gt 0 ]]; then
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
fi

eval "$(bash "$ROOT_DIR/script/stamp_release_version.sh" --env)"

XCODEBUILD_COMMAND=(
  xcodebuild
  -project "$PROJECT_NAME"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -derivedDataPath "$DERIVED_DATA"
  build
  "MARKETING_VERSION=${RESTORIX_MARKETING_VERSION}"
  "CURRENT_PROJECT_VERSION=${RESTORIX_BUILD_VERSION}"
)

if [[ -n "${RESTORIX_XCODEBUILD_CODE_SIGNING_ALLOWED:-}" ]]; then
  XCODEBUILD_COMMAND+=("CODE_SIGNING_ALLOWED=${RESTORIX_XCODEBUILD_CODE_SIGNING_ALLOWED}")
fi

cd "$ROOT_DIR"

log() {
  printf '[restorix-package] %s\n' "$*"
}

# shellcheck source=script/lib/package_security.sh
source "$ROOT_DIR/script/lib/package_security.sh"

case "$PACKAGE_MODE" in
  local|developer-id) ;;
  *)
    echo "RESTORIX_PACKAGE_MODE must be local or developer-id, got: $PACKAGE_MODE" >&2
    exit 2
    ;;
esac

if [[ "$PACKAGE_MODE" == "developer-id" ]]; then
  : "${DEVELOPER_ID_APPLICATION:?RESTORIX_DEVELOPER_ID_APPLICATION is required for developer-id packaging.}"
  XCODEBUILD_COMMAND+=(
    "CODE_SIGNING_ALLOWED=YES"
    "CODE_SIGN_IDENTITY=$DEVELOPER_ID_APPLICATION"
    "CODE_SIGN_STYLE=Manual"
  )

  if [[ -n "$DEVELOPMENT_TEAM" ]]; then
    XCODEBUILD_COMMAND+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
  fi
fi

if [[ -z "$NOTARIZE" ]]; then
  if [[ "$PACKAGE_MODE" == "developer-id" ]]; then
    NOTARIZE=1
  else
    NOTARIZE=0
  fi
fi

if [[ -z "$STAPLE" ]]; then
  STAPLE="$NOTARIZE"
fi

if [[ -z "$GATEKEEPER_VERIFY" ]]; then
  if [[ "$PACKAGE_MODE" == "developer-id" ]]; then
    GATEKEEPER_VERIFY=1
  else
    GATEKEEPER_VERIFY=0
  fi
fi

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

require_tool() {
  local tool="$1"
  command -v "$tool" >/dev/null 2>&1 || {
    echo "Missing required tool: $tool" >&2
    exit 1
  }
}

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "xcodebuild requires a full Xcode developer directory." >&2
  echo "Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

require_tool cargo
require_tool ditto
require_tool hdiutil
require_tool xcrun
require_tool /usr/bin/codesign

if truthy "$GATEKEEPER_VERIFY"; then
  require_tool /usr/sbin/spctl
fi

log "Building CLI and macOS app in $PACKAGE_MODE package mode."
log "Stamping Restorix ${RESTORIX_MARKETING_VERSION} (${RESTORIX_BUILD_VERSION})."
cargo build --release -p restorix-cli

"${XCODEBUILD_COMMAND[@]}"

mkdir -p "$(dirname "$CLI_DEST")"
cp "$CLI_SOURCE" "$CLI_DEST"
chmod +x "$CLI_DEST"

sign_app_for_distribution
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

if truthy "$NOTARIZE"; then
  notarize_app_bundle
fi

ditto -c -k --keepParent "$DIST_APP" "$DIST_ZIP"
DIST_DMG_TMP="$(mktemp "$DIST_DIR/.Restorix-macos-standalone.XXXXXX.dmg")"
rm -f "$DIST_DMG_TMP"
hdiutil create -volname "$APP_NAME" -srcfolder "$DIST_APP" -ov -format UDZO "$DIST_DMG_TMP" >/dev/null
mv -f "$DIST_DMG_TMP" "$DIST_DMG"
DIST_DMG_TMP=""

if [[ "$PACKAGE_MODE" == "developer-id" ]]; then
  sign_dmg_with_identity
fi

if truthy "$NOTARIZE"; then
  submit_for_notarization "$DIST_DMG"
  if truthy "$STAPLE"; then
    staple_artifact "$DIST_DMG"
  fi
fi

if truthy "$GATEKEEPER_VERIFY"; then
  verify_zip_gatekeeper
  verify_dmg_gatekeeper
fi

echo "Standalone app: $DIST_APP"
echo "Zip package: $DIST_ZIP"
echo "DMG package: $DIST_DMG"
