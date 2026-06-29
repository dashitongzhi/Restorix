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
PROTECTED_VOLUME="restorix_smoke_protected"
UNPROTECTED_VOLUME="restorix_smoke_unprotected"

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

cleanup() {
  if [[ "${LAUNCH_AT_LOGIN_VERIFICATION_STARTED}" -eq 1 && -n "${APP_EXECUTABLE}" && -x "${APP_EXECUTABLE}" ]]; then
    run_app_verifier_action disable >/dev/null 2>&1 || true
  fi
  stop_app
  docker volume rm "${PROTECTED_VOLUME}" "${UNPROTECTED_VOLUME}" >/dev/null 2>&1 || true
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
docker info >/dev/null

verify_app_bundle() {
  log "Verifying app bundle at ${APP_BUNDLE}."

  [[ -d "${APP_BUNDLE}" ]] || {
    echo "Missing app bundle: ${APP_BUNDLE}" >&2
    exit 1
  }

  [[ -x "${APP_EXECUTABLE}" ]] || {
    echo "Missing executable app binary: ${APP_EXECUTABLE}" >&2
    exit 1
  }

  [[ -x "${APP_RESOURCE_CLI}" ]] || {
    echo "Missing bundled CLI: ${APP_RESOURCE_CLI}" >&2
    exit 1
  }

  local declared_executable
  declared_executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${APP_BUNDLE}/Contents/Info.plist")"
  if [[ "${declared_executable}" != "${APP_NAME}" ]]; then
    echo "CFBundleExecutable is ${declared_executable}; expected ${APP_NAME}." >&2
    exit 1
  fi

  local min_system_version
  min_system_version="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "${APP_BUNDLE}/Contents/Info.plist")"
  local min_system_major="${min_system_version%%.*}"
  if ! [[ "${MAX_DEPLOYMENT_MAJOR}" =~ ^[0-9]+$ ]]; then
    echo "RESTORIX_MAX_DEPLOYMENT_MAJOR must be an integer, got: ${MAX_DEPLOYMENT_MAJOR}" >&2
    exit 2
  fi
  if [[ "${min_system_major}" =~ ^[0-9]+$ ]] && (( min_system_major > MAX_DEPLOYMENT_MAJOR )); then
    echo "LSMinimumSystemVersion is ${min_system_version}; expected macOS ${MAX_DEPLOYMENT_MAJOR}.x or lower for release coverage." >&2
    echo "Override RESTORIX_MAX_DEPLOYMENT_MAJOR only for an intentional narrow-platform release." >&2
    exit 1
  fi

  /usr/bin/codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}" >/dev/null
}

verify_app_launch_and_cli_staging() {
  log "Launching Restorix.app to verify bundled CLI staging."

  local app_home="${HOME_DIR}"
  APP_STAGED_CLI="${app_home}/Library/Application Support/${APP_NAME}/bin/restorix"
  local app_stdout="${WORK_DIR}/app.stdout"
  local app_stderr="${WORK_DIR}/app.stderr"
  local app_status="${WORK_DIR}/app.status"
  local result=0
  local open_status=0
  local launch_attempt=0

  mkdir -p "${app_home}"

  for launch_attempt in 1 2; do
    result=0
    open_status=0
    rm -f "${app_stdout}" "${app_stderr}" "${app_status}"

    /usr/bin/open -n -g \
      --stdout "${app_stdout}" \
      --stderr "${app_stderr}" \
      --env "HOME=${app_home}" \
      --env "CFFIXED_USER_HOME=${app_home}" \
      --env "RESTORIX_CONFIG=${CONFIG_PATH}" \
      --env "RESTIC_PASSWORD=${PASSWORD}" \
      --env "RESTORIX_RELEASE_VERIFY_CLI_STAGING=1" \
      --env "RESTORIX_RELEASE_EXPECT_STAGED_CLI=${APP_STAGED_CLI}" \
      --env "RESTORIX_RELEASE_STATUS_FILE=${app_status}" \
      "${APP_BUNDLE}" || open_status=$?

    if [[ "${open_status}" -ne 0 ]]; then
      echo "Restorix.app CLI staging launch request failed." >&2
      sed -n '1,120p' "${app_stdout}" >&2 || true
      sed -n '1,120p' "${app_stderr}" >&2 || true
      exit "${open_status}"
    fi

    for ((i = 1; i <= APP_LAUNCH_WAIT_STEPS; i++)); do
      if [[ -f "${app_status}" ]]; then
        result="$(cat "${app_status}")"
        break
      fi

      sleep 0.25
    done

    if [[ -f "${app_status}" ]]; then
      break
    fi

    stop_app
    if [[ "${launch_attempt}" -lt 2 ]]; then
      log "Restorix.app did not write CLI staging status; retrying launch."
      sleep 1
    fi
  done

  if [[ ! -f "${app_status}" ]]; then
    echo "Restorix.app timed out before staging its bundled CLI." >&2
    sed -n '1,120p' "${app_stdout}" >&2 || true
    sed -n '1,120p' "${app_stderr}" >&2 || true
    stop_app
    exit 1
  fi

  if [[ "${result}" -ne 0 ]]; then
    echo "Restorix.app CLI staging verification launch failed." >&2
    sed -n '1,120p' "${app_stdout}" >&2 || true
    sed -n '1,120p' "${app_stderr}" >&2 || true
    exit "${result}"
  fi

  if [[ ! -x "${APP_STAGED_CLI}" ]]; then
    echo "Restorix.app failed to stage its bundled CLI." >&2
    sed -n '1,120p' "${app_stdout}" >&2 || true
    sed -n '1,120p' "${app_stderr}" >&2 || true
    exit 1
  fi

  cmp -s "${APP_RESOURCE_CLI}" "${APP_STAGED_CLI}" || {
    echo "Staged CLI does not match bundled Contents/Resources/restorix." >&2
    exit 1
  }

  "${APP_STAGED_CLI}" --help >/dev/null
}

run_app_verifier_action() {
  local action="$1"
  local app_stdout="${WORK_DIR}/launch-at-login-${action}.stdout"
  local app_stderr="${WORK_DIR}/launch-at-login-${action}.stderr"
  local app_status="${WORK_DIR}/launch-at-login-${action}.status"
  local result=0
  local open_status=0
  local launch_attempt=0

  for launch_attempt in 1 2; do
    result=0
    open_status=0
    rm -f "${app_stdout}" "${app_stderr}" "${app_status}"

    /usr/bin/open -n -g \
      --stdout "${app_stdout}" \
      --stderr "${app_stderr}" \
      --env "HOME=${HOME_DIR}" \
      --env "CFFIXED_USER_HOME=${HOME_DIR}" \
      --env "RESTORIX_CONFIG=${CONFIG_PATH}" \
      --env "RESTORIX_RELEASE_VERIFY_LAUNCH_AT_LOGIN=${action}" \
      --env "RESTORIX_RELEASE_STATUS_FILE=${app_status}" \
      "${APP_BUNDLE}" || open_status=$?

    if [[ "${open_status}" -ne 0 ]]; then
      echo "Restorix.app launch-at-login launch request failed: ${action}" >&2
      sed -n '1,120p' "${app_stdout}" >&2 || true
      sed -n '1,120p' "${app_stderr}" >&2 || true
      return "${open_status}"
    fi

    for ((i = 1; i <= APP_LAUNCH_WAIT_STEPS; i++)); do
      if [[ -f "${app_status}" ]]; then
        result="$(cat "${app_status}")"
        break
      fi
      sleep 0.25
    done

    if [[ -f "${app_status}" ]]; then
      break
    fi

    stop_app
    if [[ "${launch_attempt}" -lt 2 ]]; then
      log "Restorix.app did not write launch-at-login status for ${action}; retrying launch."
      sleep 1
    fi
  done

  if [[ ! -f "${app_status}" ]]; then
    echo "Restorix.app launch-at-login verification action timed out: ${action}" >&2
    sed -n '1,120p' "${app_stdout}" >&2 || true
    sed -n '1,120p' "${app_stderr}" >&2 || true
    stop_app
    return 1
  fi

  if [[ "${result}" -ne 0 ]]; then
    echo "Restorix.app launch-at-login verification action failed: ${action}" >&2
    sed -n '1,120p' "${app_stdout}" >&2 || true
    sed -n '1,120p' "${app_stderr}" >&2 || true
    return "${result}"
  fi

  sed -n '1,120p' "${app_stdout}"
}

assert_config_launch_at_login() {
  local expected="$1"
  local config_json

  config_json="$(
    RESTORIX_CONFIG="${CONFIG_PATH}" \
    "${RESTORIX_BIN}" config get --json
  )"

  printf '%s\n' "${config_json}" | grep -q "\"launch_at_login\": ${expected}" || {
    echo "Expected launch_at_login to be ${expected}, but config was:" >&2
    printf '%s\n' "${config_json}" >&2
    exit 1
  }
}

verify_launch_at_login_flow() {
  log "Verifying packaged launch-at-login registration, relaunch sync, and cleanup."
  LAUNCH_AT_LOGIN_VERIFICATION_STARTED=1

  log "Resetting launch-at-login to disabled before verification."
  run_app_verifier_action disable
  assert_config_launch_at_login false

  log "Enabling launch-at-login from Restorix.app."
  run_app_verifier_action enable
  assert_config_launch_at_login true

  log "Relaunching Restorix.app to confirm macOS login item state and config remain enabled."
  run_app_verifier_action confirm-enabled
  assert_config_launch_at_login true

  log "Disabling launch-at-login after verification."
  run_app_verifier_action disable
  assert_config_launch_at_login false
}

if [[ -n "${APP_BUNDLE}" ]]; then
  verify_app_bundle
  verify_app_launch_and_cli_staging
  RESTORIX_BIN="${APP_STAGED_CLI}"
elif [[ ! -x "${RESTORIX_BIN}" ]]; then
  echo "Missing restorix binary: ${RESTORIX_BIN}" >&2
  exit 1
fi

log "Creating smoke Docker volumes."
docker volume create "${PROTECTED_VOLUME}" >/dev/null
docker volume create "${UNPROTECTED_VOLUME}" >/dev/null

log "Initializing temporary restic repository."
RESTORIX_CONFIG="${CONFIG_PATH}" \
RESTIC_PASSWORD="${PASSWORD}" \
restic -r "${REPO_PATH}" init >/dev/null

log "Creating protected-volume snapshot."
printf 'restorix smoke test\n' | \
  RESTIC_PASSWORD="${PASSWORD}" \
  restic -r "${REPO_PATH}" backup \
    --stdin \
    --stdin-filename "/var/lib/docker/volumes/${PROTECTED_VOLUME}/_data/demo.txt" >/dev/null

log "Adding repository through ${RESTORIX_BIN}."
RESTORIX_CONFIG="${CONFIG_PATH}" \
"${RESTORIX_BIN}" repo add \
  --tool restic \
  --name "Smoke Restic" \
  --location "${REPO_PATH}" \
  --password-env-key RESTIC_PASSWORD >/dev/null

log "Scanning Docker volumes through ${RESTORIX_BIN}."
SCAN_JSON="$(
  RESTORIX_CONFIG="${CONFIG_PATH}" \
  RESTIC_PASSWORD="${PASSWORD}" \
  "${RESTORIX_BIN}" scan --json
)"

printf '%s\n' "${SCAN_JSON}" | grep -q "\"name\": \"${PROTECTED_VOLUME}\""
printf '%s\n' "${SCAN_JSON}" | grep -q "\"status\": \"Protected\""
printf '%s\n' "${SCAN_JSON}" | grep -q "\"name\": \"${UNPROTECTED_VOLUME}\""
printf '%s\n' "${SCAN_JSON}" | grep -q "\"status\": \"Unprotected\""

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
