#!/usr/bin/env bash

# Packaged-app acceptance surface. The orchestrator provides APP_BUNDLE,
# APP_EXECUTABLE, APP_RESOURCE_CLI, HOME_DIR, CONFIG_PATH, WORK_DIR and log/stop_app.

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
  local min_system_major
  min_system_version="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "${APP_BUNDLE}/Contents/Info.plist")"
  min_system_major="${min_system_version%%.*}"
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
      --stdout "${app_stdout}" --stderr "${app_stderr}" \
      --env "HOME=${app_home}" --env "CFFIXED_USER_HOME=${app_home}" \
      --env "RESTORIX_CONFIG=${CONFIG_PATH}" --env "RESTIC_PASSWORD=${PASSWORD}" \
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
      [[ -f "${app_status}" ]] && { result="$(cat "${app_status}")"; break; }
      sleep 0.25
    done
    [[ -f "${app_status}" ]] && break
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
  [[ -x "${APP_STAGED_CLI}" ]] || { echo "Restorix.app failed to stage its bundled CLI." >&2; exit 1; }
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

  for launch_attempt in 1 2; do
    result=0
    open_status=0
    rm -f "${app_stdout}" "${app_stderr}" "${app_status}"
    /usr/bin/open -n -g \
      --stdout "${app_stdout}" --stderr "${app_stderr}" \
      --env "HOME=${HOME_DIR}" --env "CFFIXED_USER_HOME=${HOME_DIR}" \
      --env "RESTORIX_CONFIG=${CONFIG_PATH}" \
      --env "RESTORIX_RELEASE_VERIFY_LAUNCH_AT_LOGIN=${action}" \
      --env "RESTORIX_RELEASE_STATUS_FILE=${app_status}" \
      "${APP_BUNDLE}" || open_status=$?

    if [[ "${open_status}" -ne 0 ]]; then
      echo "Restorix.app launch-at-login launch request failed: ${action}" >&2
      return "${open_status}"
    fi
    for ((i = 1; i <= APP_LAUNCH_WAIT_STEPS; i++)); do
      [[ -f "${app_status}" ]] && { result="$(cat "${app_status}")"; break; }
      sleep 0.25
    done
    [[ -f "${app_status}" ]] && break
    stop_app
    [[ "${launch_attempt}" -lt 2 ]] && sleep 1
  done

  if [[ ! -f "${app_status}" || "${result}" -ne 0 ]]; then
    echo "Restorix.app launch-at-login verification failed: ${action}" >&2
    sed -n '1,120p' "${app_stdout}" >&2 || true
    sed -n '1,120p' "${app_stderr}" >&2 || true
    stop_app
    return 1
  fi
  sed -n '1,120p' "${app_stdout}"
}

assert_config_launch_at_login() {
  local expected="$1"
  local config_json
  config_json="$(RESTORIX_CONFIG="${CONFIG_PATH}" "${RESTORIX_BIN}" config get --json)"
  printf '%s\n' "${config_json}" | grep -q "\"launch_at_login\": ${expected}" || {
    echo "Expected launch_at_login to be ${expected}, but config was:" >&2
    printf '%s\n' "${config_json}" >&2
    exit 1
  }
}

verify_launch_at_login_flow() {
  log "Verifying packaged launch-at-login registration, relaunch sync, and cleanup."
  # shellcheck disable=SC2034 # Read by the sourcing orchestrator's cleanup trap.
  LAUNCH_AT_LOGIN_VERIFICATION_STARTED=1
  run_app_verifier_action disable
  assert_config_launch_at_login false
  run_app_verifier_action enable
  assert_config_launch_at_login true
  run_app_verifier_action confirm-enabled
  assert_config_launch_at_login true
  run_app_verifier_action disable
  assert_config_launch_at_login false
}
