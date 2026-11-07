#!/usr/bin/env bash
# Runs a command with the TimeTrack toolchain (Flutter, JDK 21, Android SDK).
#
# On the maintainer's Fedora host the toolchain only works inside the `flutter`
# toolbox, so the command is forwarded there (keeping the current directory).
# Inside the toolbox, or on machines without toolbox (CI, other agents), the
# command runs directly.
#
# Usage: tool/dev.sh <command> [args...]   e.g. tool/dev.sh dart test
set -euo pipefail

if [[ -f /run/.containerenv ]] || ! command -v toolbox >/dev/null 2>&1; then
  if [[ -f "$HOME/dev/sdk/env.sh" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/dev/sdk/env.sh"
  fi
  exec "$@"
fi

exec toolbox run -c flutter bash -c \
  'source "$HOME/dev/sdk/env.sh" && cd "$1" && shift && exec "$@"' _ "$PWD" "$@"
