#!/bin/zsh
# Chạy các lô còn lại của Run_Plan Linguza (AIP918) theo thứ tự trạng thái user.
# Runner tự huỷ / chờ hết hạn / mua lại Weekly khi case cần (--cho-free-phut).
# Dùng: scripts/run-plan-linguza.sh [TÊN_LÔ_BẮT_ĐẦU]   vd: scripts/run-plan-linguza.sh A1
cd "$(dirname "$0")/.." || exit 1
R=scripts/run-linguza-cases.sh
TP4=after_onboarding,after_inter_old,home_badge_pro,pop_up_chat_screen
W=(--cho-free-phut 20)
TU=${1:-}
lo() {
  # Bỏ qua các lô trước lô bắt đầu: chạy tiếp sau khi dừng giữa chừng.
  if [[ -n $TU && $1 != $TU ]]; then echo "--- bo qua lo $1"; return; fi
  TU=""
  echo "=== LO $1 $(date +%H:%M)"; shift; $R "$@" ${W[@]}
}
lo C-04  SUB_AND_04
lo A1    SUB_AND_40,SUB_AND_42,SUB_AND_43 --diem-cham after_onboarding
lo A2    SUB_AND_41 --diem-cham after_inter_old
lo B1    SUB_AND_40,SUB_AND_42,SUB_AND_43 --diem-cham after_inter_old
lo B1b   SUB_AND_41 --diem-cham after_onboarding
lo B1c   SUB_AND_79
lo C1    SUB_AND_40,SUB_AND_42,SUB_AND_43 --diem-cham home_badge_pro
lo D2    SUB_AND_60,SUB_AND_61,SUB_AND_63,SUB_AND_64,SUB_AND_62,SUB_AND_65
lo D2b   SUB_AND_40,SUB_AND_42,SUB_AND_43 --diem-cham pop_up_chat_screen
lo E1    SUB_AND_59,SUB_AND_25,SUB_AND_22,SUB_AND_23,SUB_AND_30,SUB_AND_31,SUB_AND_36,SUB_AND_38,SUB_AND_51,SUB_AND_50,SUB_AND_52,SUB_AND_53
lo E1b   SUB_AND_45,SUB_AND_46 --diem-cham $TP4
lo E1c   SUB_AND_26
lo E2    SUB_AND_24
lo E2b   SUB_AND_47 --diem-cham $TP4
lo E1d   SUB_AND_54,SUB_AND_57
lo E3    SUB_AND_32,SUB_AND_33,SUB_AND_39
lo E3b   SUB_AND_48 --diem-cham $TP4
lo E4    SUB_AND_34
lo E4b   SUB_AND_49 --diem-cham $TP4
lo E5    SUB_AND_44 --diem-cham pop_up_chat_screen
lo E5b   SUB_AND_58
lo E6    SUB_AND_44 --diem-cham after_inter_old
lo E7    SUB_AND_44 --diem-cham after_onboarding
lo E7b   SUB_AND_56
lo E8    SUB_AND_44 --diem-cham home_badge_pro
lo E9    SUB_AND_16,SUB_AND_21
lo F1    SUB_AND_17,SUB_AND_27,SUB_AND_29
lo F2    SUB_AND_18,SUB_AND_28
lo NA    SUB_AND_35,SUB_AND_66,SUB_AND_67,SUB_AND_68,SUB_AND_69,SUB_AND_70,SUB_AND_71,SUB_AND_72,SUB_AND_73,SUB_AND_74,SUB_AND_75,SUB_AND_76,SUB_AND_77,SUB_AND_80
echo "=== XONG $(date +%H:%M)"
