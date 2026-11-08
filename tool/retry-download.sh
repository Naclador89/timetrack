#!/usr/bin/env bash
# Runs a command and retries it, with growing pauses, only when a build hook's
# download failed its hash check. GitHub release downloads (used by the sqlite3
# hook) sometimes return an error page for a while; real failures are not retried.
#
# Usage: tool/retry-download.sh <command> [args...]   e.g. tool/retry-download.sh dart test
set -uo pipefail

log=$(mktemp)
trap 'rm -f "$log"' EXIT

for attempt in 1 2 3 4 5; do
  "$@" 2>&1 | tee "$log"
  status=${PIPESTATUS[0]}
  if [[ $status -eq 0 ]] || ! grep -q 'Hash of downloaded file' "$log"; then
    exit "$status"
  fi
  echo "::warning::Hook download failed its hash check (attempt $attempt), retrying in $((attempt * 30)) s"
  sleep $((attempt * 30))
done
exit "$status"
