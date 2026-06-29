#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:---check}"

usage() {
  cat >&2 <<'USAGE'
Usage: script/stamp_release_version.sh [--check|--env]

Derives one Restorix release version for Cargo and Xcode packaging.
For tagged GitHub releases, the tag must be vX.Y.Z and must match the Cargo
workspace package version. The script emits MARKETING_VERSION and
CURRENT_PROJECT_VERSION values for xcodebuild so app bundle metadata cannot
drift from the Rust crate version.
USAGE
}

if [[ "$MODE" != "--check" && "$MODE" != "--env" ]]; then
  usage
  exit 64
fi

cd "$ROOT_DIR"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to parse cargo metadata for release version stamping." >&2
  exit 1
fi

cargo_metadata_json="$(cargo metadata --no-deps --format-version=1)"

cargo_version_for_package() {
  local package_name="$1"
  RESTORIX_CARGO_METADATA_JSON="$cargo_metadata_json" python3 - "$package_name" <<'PY'
import json
import os
import sys

package_name = sys.argv[1]
metadata = json.loads(os.environ["RESTORIX_CARGO_METADATA_JSON"])

for package in metadata["packages"]:
    if package["name"] == package_name:
        print(package["version"])
        raise SystemExit(0)

print(f"Cargo package not found: {package_name}", file=sys.stderr)
raise SystemExit(1)
PY
}

tag_version_from_environment() {
  if [[ -n "${RESTORIX_RELEASE_VERSION:-}" ]]; then
    printf '%s\n' "$RESTORIX_RELEASE_VERSION"
    return
  fi

  if [[ "${GITHUB_REF_TYPE:-}" == "tag" && -n "${GITHUB_REF_NAME:-}" ]]; then
    printf '%s\n' "$GITHUB_REF_NAME"
    return
  fi

  if [[ "${GITHUB_REF:-}" == refs/tags/* ]]; then
    printf '%s\n' "${GITHUB_REF#refs/tags/}"
  fi
}

normalize_tag_version() {
  local raw_version="$1"

  if [[ "$raw_version" != v* ]]; then
    echo "Release tags must use vX.Y.Z format; got '$raw_version'." >&2
    exit 65
  fi

  printf '%s\n' "${raw_version#v}"
}

validate_marketing_version() {
  local version="$1"

  if [[ ! "$version" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]]; then
    echo "Restorix release version must be X.Y.Z for Cargo and CFBundleShortVersionString; got '$version'." >&2
    exit 65
  fi
}

validate_build_version() {
  local version="$1"

  if [[ ! "$version" =~ ^[0-9]+([.][0-9]+){0,2}$ ]]; then
    echo "Restorix build version must be numeric for CFBundleVersion; got '$version'." >&2
    exit 65
  fi
}

cli_version="$(cargo_version_for_package restorix-cli)"
core_version="$(cargo_version_for_package restorix-core)"

if [[ "$cli_version" != "$core_version" ]]; then
  echo "Restorix crate versions differ: restorix-cli=$cli_version, restorix-core=$core_version." >&2
  exit 65
fi

raw_tag_version="$(tag_version_from_environment || true)"
if [[ -n "$raw_tag_version" ]]; then
  release_version="$(normalize_tag_version "$raw_tag_version")"
else
  release_version="$cli_version"
fi

validate_marketing_version "$release_version"

if [[ "$release_version" != "$cli_version" ]]; then
  echo "Release version $release_version does not match Cargo crate version $cli_version." >&2
  echo "Update [workspace.package].version before tagging the release." >&2
  exit 65
fi

build_version="${RESTORIX_BUILD_VERSION:-${GITHUB_RUN_NUMBER:-1}}"
validate_build_version "$build_version"

case "$MODE" in
  --env)
    printf "export RESTORIX_RELEASE_VERSION='%s'\n" "$release_version"
    printf "export RESTORIX_MARKETING_VERSION='%s'\n" "$release_version"
    printf "export RESTORIX_BUILD_VERSION='%s'\n" "$build_version"
    ;;
  --check)
    echo "Restorix release version: $release_version"
    echo "Restorix build version: $build_version"
    echo "Restorix crates: restorix-cli=$cli_version, restorix-core=$core_version"
    ;;
esac
