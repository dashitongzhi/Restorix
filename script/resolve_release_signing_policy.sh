#!/usr/bin/env bash
set -euo pipefail

github_output="${GITHUB_OUTPUT:-}"
github_ref="${GITHUB_REF:-}"
allow_unsigned="${RESTORIX_ALLOW_UNSIGNED_CI_ARTIFACTS:-false}"

cert_base64="${MACOS_DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64:-}"
cert_password="${MACOS_DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD:-}"
developer_id_application="${MACOS_DEVELOPER_ID_APPLICATION:-}"
development_team="${MACOS_DEVELOPMENT_TEAM:-}"
notary_apple_id="${MACOS_NOTARY_APPLE_ID:-}"
notary_password="${MACOS_NOTARY_PASSWORD:-}"
notary_team_id="${MACOS_NOTARY_TEAM_ID:-${development_team}}"

is_public_v_release=false
if [[ "$github_ref" == refs/tags/v* ]]; then
  is_public_v_release=true
fi

truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

write_policy_value() {
  local output_name="$1"
  local env_name="$2"
  local value="$3"

  if [[ -n "$github_output" ]]; then
    printf '%s=%s\n' "$output_name" "$value" >> "$github_output"
  else
    printf 'export %s=%q\n' "$env_name" "$value"
  fi
}

configure_unsigned_ci_artifacts() {
  write_policy_value package_mode RESTORIX_PACKAGE_MODE local
  write_policy_value notarize RESTORIX_NOTARIZE 0
  write_policy_value staple RESTORIX_STAPLE 0
  write_policy_value gatekeeper_verify RESTORIX_GATEKEEPER_VERIFY 0
  write_policy_value xcodebuild_code_signing_allowed RESTORIX_XCODEBUILD_CODE_SIGNING_ALLOWED NO
}

if [[ "$is_public_v_release" != true ]] && truthy "$allow_unsigned"; then
  echo "Building unsigned CI artifacts for an explicit non-release smoke run."
  configure_unsigned_ci_artifacts
  exit 0
fi

if [[ -z "$cert_base64" ]]; then
  if [[ "$is_public_v_release" == true ]]; then
    echo "Public v* releases require MACOS_DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64; refusing to build unsigned release artifacts." >&2
    exit 2
  fi

  if ! truthy "$allow_unsigned"; then
    echo "Unsigned CI artifacts require explicit RESTORIX_ALLOW_UNSIGNED_CI_ARTIFACTS=true." >&2
    exit 2
  fi

  echo "Developer ID certificate secret is not configured; building unsigned CI artifacts for an explicit non-release smoke run."
  configure_unsigned_ci_artifacts
  exit 0
fi

if [[ -z "$cert_password" || -z "$developer_id_application" ]]; then
  echo "Developer ID signing requires MACOS_DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD and MACOS_DEVELOPER_ID_APPLICATION secrets." >&2
  exit 2
fi

if [[ -z "$notary_apple_id" || -z "$notary_password" || -z "$notary_team_id" ]]; then
  echo "Developer ID release packaging requires MACOS_NOTARY_APPLE_ID, MACOS_NOTARY_PASSWORD, and MACOS_NOTARY_TEAM_ID or MACOS_DEVELOPMENT_TEAM secrets." >&2
  exit 2
fi

write_policy_value package_mode RESTORIX_PACKAGE_MODE developer-id
write_policy_value notarize RESTORIX_NOTARIZE 1
write_policy_value staple RESTORIX_STAPLE 1
write_policy_value gatekeeper_verify RESTORIX_GATEKEEPER_VERIFY 1
write_policy_value xcodebuild_code_signing_allowed RESTORIX_XCODEBUILD_CODE_SIGNING_ALLOWED YES

echo "Developer ID signing and notarization are configured for release packaging."
