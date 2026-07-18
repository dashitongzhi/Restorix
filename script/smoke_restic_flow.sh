#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESTORIX_BIN="${ROOT_DIR}/target/debug/restorix"
APP_NAME="Restorix"
APP_BUNDLE=""
APP_EXECUTABLE=""
APP_RESOURCE_CLI=""
APP_STAGED_CLI=""
BUILD_CLI=1
LAUNCH_AT_LOGIN_VERIFICATION_STARTED=0
MAX_DEPLOYMENT_MAJOR="${RESTORIX_MAX_DEPLOYMENT_MAJOR:-15}"
APP_LAUNCH_WAIT_STEPS="${RESTORIX_APP_LAUNCH_WAIT_STEPS:-240}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/restorix-smoke.XXXXXX")"
HOME_DIR="${WORK_DIR}/home"
CONFIG_PATH="${WORK_DIR}/config.json"
REPO_PATH="${WORK_DIR}/restic-repo"
PASSWORD="restorix-smoke-password"
SMOKE_RUN_ID="${RESTORIX_SMOKE_RUN_ID:-$(uuidgen | tr '[:upper:]' '[:lower:]')}"
SMOKE_LABEL_KEY="restorix.smoke-run"
SMOKE_LABEL_VALUE="${SMOKE_RUN_ID}"
PROTECTED_VOLUME="restorix_smoke_protected_${SMOKE_RUN_ID}"
UNPROTECTED_VOLUME="restorix_smoke_unprotected_${SMOKE_RUN_ID}"
CREATED_VOLUMES=()

log() {
  printf '[restorix-smoke] %s\n' "$*"
}

stop_app() {
  if [[ -z "${APP_PID:-}" ]]; then
    [[ -n "${APP_EXECUTABLE}" ]] && pkill -TERM -f "${APP_EXECUTABLE}" >/dev/null 2>&1 || true
    return 0
  fi

  kill "${APP_PID}" >/dev/null 2>&1 || true
  for _ in {1..20}; do
    if ! kill -0 "${APP_PID}" >/dev/null 2>&1; then
      wait "${APP_PID}" >/dev/null 2>&1 || true
      APP_PID=""
      [[ -n "${APP_EXECUTABLE}" ]] && pkill -TERM -f "${APP_EXECUTABLE}" >/dev/null 2>&1 || true
      return 0
    fi
    sleep 0.1
  done

  kill -KILL "${APP_PID}" >/dev/null 2>&1 || true
  wait "${APP_PID}" >/dev/null 2>&1 || true
  APP_PID=""
  [[ -n "${APP_EXECUTABLE}" ]] && pkill -KILL -f "${APP_EXECUTABLE}" >/dev/null 2>&1 || true
}

# shellcheck source=script/lib/app_bundle_smoke.sh
source "${ROOT_DIR}/script/lib/app_bundle_smoke.sh"

cleanup() {
  if [[ "${LAUNCH_AT_LOGIN_VERIFICATION_STARTED}" -eq 1 && -n "${APP_EXECUTABLE}" && -x "${APP_EXECUTABLE}" ]]; then
    run_app_verifier_action disable >/dev/null 2>&1 || true
  fi
  stop_app
  if (( ${#CREATED_VOLUMES[@]} > 0 )); then
    for volume in "${CREATED_VOLUMES[@]}"; do
      label_value="$(docker volume inspect "$volume" --format "{{ index .Labels \"${SMOKE_LABEL_KEY}\" }}" 2>/dev/null || true)"
      if [[ "$label_value" == "$SMOKE_LABEL_VALUE" ]]; then
        docker volume rm "$volume" >/dev/null 2>&1 || true
      fi
    done
  fi
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

cd "${ROOT_DIR}"

usage() {
  cat <<EOF
usage: $0 [--restorix-bin PATH] [--app-bundle PATH] [--skip-build]

Runs the restic/docker smoke flow. By default it builds and exercises
target/debug/restorix. With --app-bundle, it verifies Restorix.app and exercises
the bundled Contents/Resources/restorix CLI.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --restorix-bin)
      [[ $# -ge 2 ]] || {
        usage >&2
        exit 2
      }
      RESTORIX_BIN="$2"
      BUILD_CLI=0
      shift 2
      ;;
    --app-bundle)
      [[ $# -ge 2 ]] || {
        usage >&2
        exit 2
      }
      APP_BUNDLE="$2"
      BUILD_CLI=0
      shift 2
      ;;
    --skip-build)
      BUILD_CLI=0
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -n "${APP_BUNDLE}" ]]; then
  APP_BUNDLE="$(cd "$(dirname "${APP_BUNDLE}")" && pwd)/$(basename "${APP_BUNDLE}")"
  APP_EXECUTABLE="${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
  APP_RESOURCE_CLI="${APP_BUNDLE}/Contents/Resources/restorix"
  RESTORIX_BIN="${APP_RESOURCE_CLI}"
fi

if [[ "${BUILD_CLI}" -eq 1 ]]; then
  log "Building debug CLI."
  cargo build -p restorix-cli >/dev/null
fi

if ! [[ "${APP_LAUNCH_WAIT_STEPS}" =~ ^[0-9]+$ ]] || (( APP_LAUNCH_WAIT_STEPS < 1 )); then
  echo "RESTORIX_APP_LAUNCH_WAIT_STEPS must be a positive integer, got: ${APP_LAUNCH_WAIT_STEPS}" >&2
  exit 2
fi

log "Checking Docker and restic prerequisites."
command -v docker >/dev/null
command -v restic >/dev/null
command -v jq >/dev/null
docker info >/dev/null

if [[ -n "${APP_BUNDLE}" ]]; then
  verify_app_bundle
  verify_app_launch_and_cli_staging
  RESTORIX_BIN="${APP_STAGED_CLI}"
elif [[ ! -x "${RESTORIX_BIN}" ]]; then
  echo "Missing restorix binary: ${RESTORIX_BIN}" >&2
  exit 1
fi

create_smoke_volume() {
  local volume="$1"

  if docker volume inspect "$volume" >/dev/null 2>&1; then
    echo "Refusing to reuse an existing Docker volume: $volume" >&2
    exit 1
  fi

  docker volume create --label "${SMOKE_LABEL_KEY}=${SMOKE_LABEL_VALUE}" "$volume" >/dev/null
  CREATED_VOLUMES+=("$volume")
}

assert_volume_status() {
  local volume="$1"
  local expected_status="$2"

  printf '%s\n' "${SCAN_JSON}" | jq -e \
    --arg volume "$volume" \
    --arg expected_status "$expected_status" \
    'any(.volume_health[]?; .volume.name == $volume and .status == $expected_status)' >/dev/null
}

log "Creating smoke Docker volumes."
create_smoke_volume "${PROTECTED_VOLUME}"
create_smoke_volume "${UNPROTECTED_VOLUME}"

log "Initializing temporary restic repository."
RESTORIX_CONFIG="${CONFIG_PATH}" \
RESTIC_PASSWORD="${PASSWORD}" \
restic -r "${REPO_PATH}" init >/dev/null

log "Creating protected-volume snapshot."
printf 'restorix smoke test\n' | \
  RESTIC_PASSWORD="${PASSWORD}" \
  restic -r "${REPO_PATH}" backup \
    --stdin \
    --stdin-filename "/var/lib/docker/volumes/${PROTECTED_VOLUME}/_data" >/dev/null

log "Adding repository through ${RESTORIX_BIN}."
RESTORIX_CONFIG="${CONFIG_PATH}" \
"${RESTORIX_BIN}" repo add \
  --tool restic \
  --name "Smoke Restic" \
  --location "${REPO_PATH}" \
  --password-env-key RESTIC_PASSWORD \
  --expected-hostname "$(hostname)" >/dev/null

log "Scanning Docker volumes through ${RESTORIX_BIN}."
SCAN_JSON="$(
  RESTORIX_CONFIG="${CONFIG_PATH}" \
  RESTIC_PASSWORD="${PASSWORD}" \
  "${RESTORIX_BIN}" scan --json
)"

assert_volume_status "${PROTECTED_VOLUME}" "Protected"
assert_volume_status "${UNPROTECTED_VOLUME}" "Unprotected"

log "Rendering Markdown report through ${RESTORIX_BIN}."
REPORT="$(
  RESTORIX_CONFIG="${CONFIG_PATH}" \
  RESTIC_PASSWORD="${PASSWORD}" \
  "${RESTORIX_BIN}" report markdown --language zh-Hans
)"

printf '%s\n' "${REPORT}" | grep -q "Restorix 报告"
printf '%s\n' "${REPORT}" | grep -q "${PROTECTED_VOLUME}"
printf '%s\n' "${REPORT}" | grep -q "${UNPROTECTED_VOLUME}"

if [[ -n "${APP_BUNDLE}" ]]; then
  verify_launch_at_login_flow
fi

echo "Restorix smoke flow passed."
if [[ -n "${APP_BUNDLE}" ]]; then
  echo "App bundle: ${APP_BUNDLE}"
fi
echo "CLI binary: ${RESTORIX_BIN}"
echo "Protected volume: ${PROTECTED_VOLUME}"
echo "Unprotected volume: ${UNPROTECTED_VOLUME}"
