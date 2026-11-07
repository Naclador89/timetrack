#!/usr/bin/env bash
# Builds the Linux app opening at ROUTE, runs it with an isolated data folder and
# sync disabled (it must never reach the user's real Nextcloud),
# and saves a screenshot of its window. Maintainer machine only (toolbox
# `flutter` with xwd, ImageMagick and xdotool; X11 via XWayland).
#
# Usage: tool/screenshot.sh /calendar out.png [data-dir]
#   data-dir defaults to a temp folder; seed it with sample data first:
#   (cd packages/core && ../../tool/dev.sh dart run tool/seed_demo.dart \
#      <data-dir>/io.github.naclador89.timetrack/timetrack.sqlite)
set -euo pipefail
ROUTE=${1:?route}
OUT=$(realpath -m "${2:?output png}")
DATA=$(realpath -m "${3:-$(mktemp -d)}")
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT/app"
"$ROOT/tool/dev.sh" flutter build linux --debug --dart-define=INITIAL_ROUTE="$ROUTE" --dart-define=TIMETRACK_DISABLE_SYNC=true >/dev/null
"$ROOT/tool/dev.sh" bash -c '
  export XDG_DATA_HOME="$1" GDK_BACKEND=x11
  build/linux/x64/debug/bundle/timetrack >/dev/null 2>&1 &
  PID=$!
  WIN=$(timeout 30 xdotool search --sync --onlyvisible --name TimeTrack | head -1)
  xdotool sleep 4
  xwd -id "$WIN" -silent | magick xwd:- "$2"
  kill $PID' _ "$DATA" "$OUT"
echo "$OUT"
