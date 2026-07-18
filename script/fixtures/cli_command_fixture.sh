#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  success)
    printf 'ok\n'
    ;;
  partial)
    printf '{"errors":["docker unavailable"]}\n'
    exit 2
    ;;
  failure)
    printf 'fixture failed\n' >&2
    exit 3
    ;;
  timeout)
    sleep 5
    ;;
  repo)
    if [[ "${2:-}" == "list" ]]; then
      printf '[]\n'
    else
      printf 'unsupported repository action\n' >&2
      exit 64
    fi
    ;;
  scan)
    printf '%s\n' '{"summary":{"scanned_at":"2026-07-17T00:00:00Z","platform":"MacOS","docker_available":false,"docker_running":false,"restic_available":false,"total_containers":0,"total_volumes":0,"protected_count":0,"unprotected_count":0,"stale_count":0,"unknown_count":0,"error_count":1},"containers":[],"volumes":[],"repositories":[],"snapshots":[],"volume_health":[],"warnings":[],"errors":[{"code":"docker_unavailable","context":{"detail":"docker unavailable"},"message":"docker unavailable"}]}'
    exit 2
    ;;
  report)
    printf '# Restorix Report\n\n## Errors\n- docker unavailable\n'
    exit 2
    ;;
  *)
    printf 'unknown fixture action\n' >&2
    exit 64
    ;;
esac
