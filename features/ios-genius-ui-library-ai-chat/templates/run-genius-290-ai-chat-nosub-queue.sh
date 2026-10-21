#!/bin/bash
# AI Chat: huỷ gói (tester nhập mật khẩu) → chờ hết hạn → chạy các case cần "chưa mua gói".
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; RUN="$ROOT/scripts/run-genius-290-device-suite.sh"
export G290_OUT="$ROOT/plans/261020-1505-genius-290-ai-chat-testcase-automation/runs"
while pgrep -f "xcodebuild test-without-building" >/dev/null; do sleep 15; done
"$RUN" build || exit 1
echo "== $(date +%H:%M) huỷ gói — tester nhập mật khẩu + Cancel Subscription → Confirm"
"$RUN" RUN_G290_CANCEL_SUB Genius290CancelSandboxSubUITests/test01_cancelFromManageSubscription cancel-sub | head -2
for i in $(seq 1 18); do
  "$RUN" RUN_G290_SUB_PROBE Genius290SubscriptionLibraryUITests/test00_probeSubscriptionState expiry-probe > /dev/null
  st=$(grep -h "SUBSTATE|" $(ls -t "$G290_OUT"/expiry-probe-*.log | head -1) | tail -1)
  echo "$(date +%H:%M) $st"
  [ "$st" = "SUBSTATE|expired" ] && break
  sleep 600
done
for t in test04_paywallFrom902 test05_topupWalletSendsAfterChain test06_buySubOn236; do
  "$RUN" RUN_G290_CHAT_NOSUB Genius290AiChatNoSubUITests/$t chat-nosub2-$t | grep -E "^run|^VERDICT"
done
echo "== xong"
