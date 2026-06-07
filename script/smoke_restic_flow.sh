#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESTORIX_BIN="${ROOT_DIR}/target/debug/restorix"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/restorix-smoke.XXXXXX")"
CONFIG_PATH="${WORK_DIR}/config.json"
REPO_PATH="${WORK_DIR}/restic-repo"
PASSWORD="restorix-smoke-password"
PROTECTED_VOLUME="restorix_smoke_protected"
UNPROTECTED_VOLUME="restorix_smoke_unprotected"

cleanup() {
  docker volume rm "${PROTECTED_VOLUME}" "${UNPROTECTED_VOLUME}" >/dev/null 2>&1 || true
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

cd "${ROOT_DIR}"
cargo build -p restorix-cli >/dev/null

command -v docker >/dev/null
command -v restic >/dev/null
docker info >/dev/null

docker volume create "${PROTECTED_VOLUME}" >/dev/null
docker volume create "${UNPROTECTED_VOLUME}" >/dev/null

RESTORIX_CONFIG="${CONFIG_PATH}" \
RESTIC_PASSWORD="${PASSWORD}" \
restic -r "${REPO_PATH}" init >/dev/null

printf 'restorix smoke test\n' | \
  RESTIC_PASSWORD="${PASSWORD}" \
  restic -r "${REPO_PATH}" backup \
    --stdin \
    --stdin-filename "/var/lib/docker/volumes/${PROTECTED_VOLUME}/_data/demo.txt" >/dev/null

RESTORIX_CONFIG="${CONFIG_PATH}" \
"${RESTORIX_BIN}" repo add \
  --tool restic \
  --name "Smoke Restic" \
  --location "${REPO_PATH}" \
  --password-env-key RESTIC_PASSWORD >/dev/null

SCAN_JSON="$(
  RESTORIX_CONFIG="${CONFIG_PATH}" \
  RESTIC_PASSWORD="${PASSWORD}" \
  "${RESTORIX_BIN}" scan --json
)"

printf '%s\n' "${SCAN_JSON}" | grep -q "\"name\": \"${PROTECTED_VOLUME}\""
printf '%s\n' "${SCAN_JSON}" | grep -q "\"status\": \"Protected\""
printf '%s\n' "${SCAN_JSON}" | grep -q "\"name\": \"${UNPROTECTED_VOLUME}\""
printf '%s\n' "${SCAN_JSON}" | grep -q "\"status\": \"Unprotected\""

REPORT="$(
  RESTORIX_CONFIG="${CONFIG_PATH}" \
  RESTIC_PASSWORD="${PASSWORD}" \
  "${RESTORIX_BIN}" report markdown --language zh-Hans
)"

printf '%s\n' "${REPORT}" | grep -q "Restorix 报告"
printf '%s\n' "${REPORT}" | grep -q "${PROTECTED_VOLUME}"
printf '%s\n' "${REPORT}" | grep -q "${UNPROTECTED_VOLUME}"

echo "Restorix smoke flow passed."
echo "Protected volume: ${PROTECTED_VOLUME}"
echo "Unprotected volume: ${UNPROTECTED_VOLUME}"
