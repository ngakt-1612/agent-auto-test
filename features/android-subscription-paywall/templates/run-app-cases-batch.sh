#!/bin/zsh
# Chạy một lô case subscription cho Linguza (AIP918).
# Dùng: scripts/run-linguza-cases.sh SUB_AND_01,SUB_AND_02 [--diem-cham home_badge_pro] [--cho-free-phut 15]
# Biến môi trường: A = serial máy chính (mặc định R58TB198BNN)
cd "$(dirname "$0")/.." || exit 1
export PATH=$PATH:~/Library/Android/sdk/platform-tools
CASES=$1; shift
./venv/bin/python -u run_yaml.py \
  --app apps/linguza/config.json \
  --xlsx tc/TC_Subscription_Android_AIP918.xlsx \
  --cases-dir apps/linguza/cases \
  --artifacts apps/linguza/artifacts \
  --serial "${A:-R58TB198BNN}" \
  --cases "$CASES" "$@"
