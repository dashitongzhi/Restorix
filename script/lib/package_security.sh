#!/usr/bin/env bash

# Signing, notarization and Gatekeeper acceptance surface. The package
# orchestrator provides artifact paths, package mode and credential variables.

truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

notary_args() {
  if [[ -n "$NOTARY_KEYCHAIN_PROFILE" ]]; then
    printf '%s\0%s\0' --keychain-profile "$NOTARY_KEYCHAIN_PROFILE"
    return 0
  fi
  if [[ -n "$NOTARY_APPLE_ID" && -n "$NOTARY_PASSWORD" && -n "$NOTARY_TEAM_ID" ]]; then
    printf '%s\0%s\0%s\0%s\0%s\0%s\0' \
      --apple-id "$NOTARY_APPLE_ID" --password "$NOTARY_PASSWORD" --team-id "$NOTARY_TEAM_ID"
    return 0
  fi
  echo "Notarization requires RESTORIX_NOTARY_KEYCHAIN_PROFILE or RESTORIX_NOTARY_APPLE_ID/RESTORIX_NOTARY_PASSWORD/RESTORIX_NOTARY_TEAM_ID." >&2
  exit 2
}

submit_for_notarization() {
  local artifact="$1"
  local args=()
  while IFS= read -r -d '' arg; do args+=("$arg"); done < <(notary_args)
  log "Submitting $(basename "$artifact") for notarization."
  xcrun notarytool submit "$artifact" --wait "${args[@]}"
}

staple_artifact() {
  local artifact="$1"
  log "Stapling notarization ticket to $(basename "$artifact")."
  xcrun stapler staple "$artifact"
  xcrun stapler validate "$artifact"
}

sign_with_identity() {
  local path="$1"
  log "Signing $path with Developer ID."
  /usr/bin/codesign --force --sign "$DEVELOPER_ID_APPLICATION" --options runtime --timestamp "$path"
}

sign_dmg_with_identity() {
  log "Signing DMG with Developer ID."
  /usr/bin/codesign --force --sign "$DEVELOPER_ID_APPLICATION" --timestamp "$DIST_DMG"
  /usr/bin/codesign --verify --verbose=2 "$DIST_DMG"
}

sign_app_for_distribution() {
  if [[ "$PACKAGE_MODE" == "developer-id" ]]; then
    sign_with_identity "$CLI_DEST"
    /usr/bin/codesign --force --deep --sign "$DEVELOPER_ID_APPLICATION" --options runtime --timestamp "$BUILD_APP"
    return 0
  fi

  local sign_output
  local sign_identity
  sign_output="$(/usr/bin/codesign -dv --verbose=4 "$BUILD_APP" 2>&1 || true)"
  sign_identity="$(awk -F= '/Authority=Apple Development/{print $2; exit}' <<<"$sign_output")"
  if [[ -n "$sign_identity" ]]; then
    /usr/bin/codesign --force --sign "$sign_identity" --options runtime --timestamp=none "$CLI_DEST"
    /usr/bin/codesign --force --deep --sign "$sign_identity" --options runtime --timestamp=none "$BUILD_APP"
  else
    /usr/bin/codesign --force --sign - "$CLI_DEST"
    /usr/bin/codesign --force --deep --sign - "$BUILD_APP"
  fi
}

notarize_app_bundle() {
  local app_zip
  app_zip="$(mktemp "$DIST_DIR/.Restorix-notary-app.XXXXXX.zip")"
  rm -f "$app_zip"
  ditto -c -k --keepParent "$DIST_APP" "$app_zip"
  submit_for_notarization "$app_zip"
  rm -f "$app_zip"
  truthy "$STAPLE" && staple_artifact "$DIST_APP"
}

verify_zip_gatekeeper() {
  local extract_dir
  local extracted_app
  local result=0
  extract_dir="$(mktemp -d "${TMPDIR:-/tmp}/restorix-zip-assess.XXXXXX")"
  ditto -x -k "$DIST_ZIP" "$extract_dir"
  extracted_app="$extract_dir/$APP_NAME.app"
  if [[ ! -d "$extracted_app" ]]; then
    echo "Zip artifact does not contain $APP_NAME.app at its root." >&2
    rm -rf "$extract_dir"
    exit 1
  fi
  log "Running Gatekeeper assessment on app extracted from zip."
  /usr/sbin/spctl --assess --type execute --verbose=4 "$extracted_app" || result=$?
  rm -rf "$extract_dir"
  return "$result"
}

verify_dmg_gatekeeper() {
  local mount_dir
  local mounted_app
  local result=0
  mount_dir="$(mktemp -d "${TMPDIR:-/tmp}/restorix-dmg-assess.XXXXXX")"
  log "Running Gatekeeper assessment on DMG signature."
  /usr/sbin/spctl --assess --type open --context context:primary-signature --verbose=4 "$DIST_DMG"
  log "Mounting DMG for app Gatekeeper assessment."
  hdiutil attach "$DIST_DMG" -nobrowse -readonly -mountpoint "$mount_dir" >/dev/null
  mounted_app="$mount_dir/$APP_NAME.app"
  if [[ ! -d "$mounted_app" ]]; then
    hdiutil detach "$mount_dir" -force >/dev/null 2>&1 || true
    rmdir "$mount_dir" >/dev/null 2>&1 || true
    echo "DMG artifact does not contain $APP_NAME.app at its root." >&2
    exit 1
  fi
  /usr/sbin/spctl --assess --type execute --verbose=4 "$mounted_app" || result=$?
  hdiutil detach "$mount_dir" -force >/dev/null
  rmdir "$mount_dir" >/dev/null 2>&1 || true
  return "$result"
}
