#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=script/lib/package_security.sh
source "$ROOT_DIR/script/lib/package_security.sh"

DIST_DIR="${TMPDIR:-/tmp}"
DIST_APP="$DIST_DIR/Restorix-smoke.app"
STAPLE=0

log() { :; }
ditto() { :; }
submit_for_notarization() { :; }
staple_artifact() {
  echo "staple_artifact must not run when RESTORIX_STAPLE=0" >&2
  return 1
}

notarize_app_bundle
echo "Package security smoke passed"
