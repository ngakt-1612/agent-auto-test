#!/bin/bash
# Run one Genius 2.9.0 XCUITest suite on the paired iPhone, then export screenshots + VERDICT lines.
#   scripts/run-genius-290-device-suite.sh build
#   scripts/run-genius-290-device-suite.sh <GATE_ENV> <TestClass>[/method] [run-name]
# Env gates must be passed as TEST_RUNNER_<GATE>=1 BEFORE xcodebuild, otherwise the app/test never sees them.
set -u
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${G290_OUT:-$ROOT/plans/261018-1110-genius-290-automation-ui-image-video/runs}"
DD="${G290_DD:-/private/tmp/claude-501/-Users-kieunga/38b17dd6-be17-483a-84a4-4458211e1e73/scratchpad/dd290}"
DEST="platform=iOS,id=${G290_UDID:-00008101-001A4C921E11001E}"
mkdir -p "$OUT"
cd "$ROOT"

if [ "${1:-}" = "build" ]; then
  xcodebuild build-for-testing -project iosApp.xcodeproj -scheme iosAppUITestsOnly -destination "$DEST" \
    DEVELOPMENT_TEAM=KS4Z2R52B4 -allowProvisioningUpdates -derivedDataPath "$DD" > "$OUT/build.log" 2>&1
  rc=$?; grep -E "error:|TEST BUILD" "$OUT/build.log" | sort -u; exit $rc
fi

GATE="$1"; TARGET="$2"; NAME="${3:-$(echo "$TARGET" | tr '/' '-')}-$(date +%H%M%S)"
RESULT="$OUT/$NAME.xcresult"
# Locked screen ⇒ "Timed out while enabling automation mode": wait for the phone to be unlocked and retry
# instead of burning the suite (up to ~15 min).
for attempt in $(seq 1 30); do
  rm -rf "$RESULT"
  env "TEST_RUNNER_${GATE}=1" xcodebuild test-without-building -project iosApp.xcodeproj -scheme iosAppUITestsOnly \
    -destination "$DEST" -derivedDataPath "$DD" -resultBundlePath "$RESULT" \
    -only-testing:"iosAppUITests/$TARGET" > "$OUT/$NAME.log" 2>&1
  rc=$?
  grep -q "Timed out while enabling automation mode" "$OUT/$NAME.log" || break
  echo "DEVICE_LOCKED $NAME lượt $attempt — mở khoá iPhone + Auto-Lock = Never"
  sleep 30
done
mkdir -p "$OUT/$NAME-shots"
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUT/$NAME-shots" > /dev/null 2>&1
grep -E "^VERDICT\|" "$OUT/$NAME.log" | sort -u > "$OUT/$NAME.verdicts"
echo "run=$NAME rc=$rc verdicts=$(wc -l < "$OUT/$NAME.verdicts")"
grep -E "Executed .* tests?,|Timed out|error:" "$OUT/$NAME.log" | sort -u | head -5
cat "$OUT/$NAME.verdicts"
