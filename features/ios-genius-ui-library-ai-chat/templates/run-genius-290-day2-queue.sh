#!/bin/bash
# Day 2: expired-sub case, re-purchase (attended), all credit-dependent reruns, then expiry wait for LIB04-002.
set -u
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; RUN="$ROOT/scripts/run-genius-290-device-suite.sh"
P="$ROOT/plans/261018-1110-genius-290-automation-ui-image-video"; R="$P/runs"
REPORT() { python3 "$ROOT/scripts/build-genius-290-autotest-report.py" "$R" "$P/figma-frames" "$P/genius-290-autotest-report.html"; }
"$RUN" build || exit 1
"$RUN" RUN_G290_SUB_EXPIRED Genius290SubscriptionLibraryUITests/test02_expiredKeepsHistoryAndGateCreate sub-expired2
echo "PURCHASE_WAITING_FOR_PASSWORD"
TEST_RUNNER_ATTENDED_PLAN=Yearly "$RUN" RUN_ATTENDED_PURCHASE OnboardingToPaywallJourneyUITests purchase2
G="Genius290GenerationUITests"; V="Genius290VideoBackgroundUITests"; E="Genius290EmptyLibraryMotionUITests"
"$RUN" RUN_G290_GEN $G/test06_backReturnsToSeeAll gen-bg01002
"$RUN" RUN_G290_GEN $G/test07_swipeEdgeLeavesI2IGenerating gen-bg01003
"$RUN" RUN_G290_GEN $G/test03_sameFlowStyleReopensRunningJob gen-bg02
"$RUN" RUN_G290_VIDEO_BG $V/test02_pendingCellFilters vbg-filters
"$RUN" RUN_G290_VIDEO_BG $V/test03_pendingCellNotSelectable vbg-select
"$RUN" RUN_G290_VIDEO_BG $V/test04_tapPendingOpensGenerating vbg-tap
"$RUN" RUN_G290_VIDEO_BG $V/test06_otherFlowRunsInParallel vbg-parallel
"$RUN" RUN_G290_EMPTY_MOTION $E/test01_emptyLibraryLifecycle empty-day2
"$RUN" RUN_G290_EMPTY_MOTION $E/test02_motionControlFlows motion-day2
"$RUN" RUN_G290_EMPTY_MOTION $E/test03_backgroundExtras bgextra-day2
"$RUN" RUN_G290_SHIFT_DELETE Genius290LibraryPurgeUITests/test01_deleteMeasuredByCellShift shift-delete2
"$RUN" RUN_G290_EXTRA Genius290ZeroCreditExtraUITests/test02_bannerAutoAdvance banner-day2
"$RUN" RUN_G290_UI Genius290UpdateUIUITests/test02_homeSettingsMotion ui-home-day2
REPORT
echo "== xong phần gen ngày 2 → chờ gói hết hạn"
for i in $(seq 1 60); do
  "$RUN" RUN_G290_SUB_PROBE Genius290SubscriptionLibraryUITests/test00_probeSubscriptionState sub-probe > /dev/null 2>&1
  st=$(grep -ho "SUBSTATE|[a-z]*" $(ls -t "$R"/sub-probe-*.log | head -1) | tail -1)
  echo "SUBPROBE lượt $i: $st ($(date +%H:%M))"
  [ "$st" = "SUBSTATE|expired" ] && break
  sleep 600
done
"$RUN" RUN_G290_SUB_EXPIRED Genius290SubscriptionLibraryUITests/test02_expiredKeepsHistoryAndGateCreate sub-expired3
REPORT
echo "== xong hàng đợi ngày 2"
