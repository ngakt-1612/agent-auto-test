#!/bin/bash
# Event tracking Library 2.9.0 on the paired iPhone: run one test method, pull the app's event sink back.
#   scripts/run-genius-290-event-tracking-library.sh test01_browseFilterSelectDeleteCancel
# Output in $G290_OUT: <run>.log (ETSTEP/ETNOTE markers) + <run>.jsonl (events the app tracked).
set -u
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export G290_OUT="${G290_OUT:-$ROOT/plans/261021-0944-genius-290-event-tracking-library-autotest/runs}"
export G290_UDID="${G290_UDID:-00008101-001A4C921E11001E}"
COREDEVICE="${G290_COREDEVICE:-3869BBF0-7BD4-596F-9389-E70C49E759D8}"
BUNDLE="aiphotogenerator.aifaceeditor.aivideogenerator.aibeauty"
METHOD="$1"
NAME="et-${METHOD%%_*}-$(date +%H%M%S)"

"$ROOT/scripts/run-genius-290-device-suite.sh" RUN_G290_ET_LIB "Genius290EventTrackingLibraryUITests/$METHOD" "$NAME"
# The suite runner appends its own -HHMMSS to the run name.
LOG="$(ls -t "$G290_OUT/$NAME"-*.log | head -1)"; NAME="$(basename "$LOG" .log)"
SINK="$(grep -o 'ETSINK|[^ ]*' "$LOG" | tail -1 | cut -d'|' -f2 | tr -d '\r')"
[ -n "$SINK" ] || { echo "no ETSINK in $LOG"; exit 1; }
# `copy from` only accepts a directory source here — pull Documents/, keep this run's file.
rm -rf "$G290_OUT/pull" && mkdir -p "$G290_OUT/pull"
xcrun devicectl device copy from --device "$COREDEVICE" --domain-type appDataContainer \
  --domain-identifier "$BUNDLE" --source Documents --destination "$G290_OUT/pull" > /dev/null 2>&1
cp "$G290_OUT/pull/$(basename "$SINK")" "$G290_OUT/$NAME.jsonl"
echo "sink=$SINK events=$(wc -l < "$G290_OUT/$NAME.jsonl" 2>/dev/null || echo 0)"
grep -E "ETSTEP\||ETNOTE\|" "$LOG" | sort -u -t'|' -k3,3n | cut -c1-200
