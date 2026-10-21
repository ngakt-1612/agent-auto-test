"""Chạy test sub ADA903 theo sheet Run_Plan của TC_Subscription_Android_ADA903_v2.xlsx.

Chạy theo THỨ TỰ TRẠNG THÁI user (A1 -> F2), mỗi bước gom các case dùng chung
một trạng thái để không mua lặp. Ghi kết quả vào bản sao file TC NGAY sau mỗi
bước (quy tắc 2 của Run_Plan).

    ./venv/bin/python scripts/run_plan_ada903.py <serial> [--serial-b <may B>] [--tu-buoc E1] [--den-buoc E4]

Lệch so với Run_Plan (có lý do, ghi ở cột Ghi chú khi báo cáo):
- E1: SUB_AND_16 dùng chung lần mua của 44@home_badge_pro (cùng thao tác:
  mua Weekly từ paywall home_badge_pro) - không mua lần 2.
- E3: 32 chạy đầu (case tự huỷ sub trên Play), 48/33/39 dùng trạng thái đã huỷ.
- E5: 21 cần một lần mua riêng (tap CTA dồn dập lúc mua) sau chu kỳ select_photo.
- G1 (35, Auto từ v2 10:08): chạy cuối F1 khi account đang có sub Monthly - huỷ
  trên máy B chính là bước dọn của F1. Không có --serial-b -> BLOCKED.
"""
from __future__ import annotations
import argparse
import json
import os
import shutil
import subprocess
import sys

GOC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIEM = ["after_onboarding", "after_inter_old", "home_badge_pro", "select_photo_generate"]
TC_V2 = "tc/TC_Subscription_Android_ADA903_v2.xlsx"
KET_QUA = "tc/TC_Subscription_Android_ADA903_v2_ket_qua.xlsx"


def s(*ns):
    return ["SUB_AND_%02d" % n for n in ns]


def tp(ns, diem):
    return ["SUB_AND_%02d@%s" % (n, d) for d in diem for n in ns]


# (bước, danh sách case theo thứ tự chạy, case gốc - FAIL thì case sau "cùng gốc")
BUOC = [
    ("A1", tp([40, 42, 43], ["after_onboarding"]), None),
    ("A2", tp([41], ["after_inter_old"]), None),
    # 41 ở home_badge_pro/select_photo: sheet Touchpoints để trống điều kiện -> N/A.
    ("B1", tp([40, 42, 43], ["after_inter_old"])
     + tp([41], ["after_onboarding", "home_badge_pro", "select_photo_generate"]), None),
    ("C1", tp([40, 42, 43], ["home_badge_pro"]) + s(*range(1, 14)), None),
    ("C2", s(14, 15, 19, 37, 55), None),
    ("C3", s(20), None),
    ("D1", tp([40, 42, 43], ["select_photo_generate"]), None),
    ("E1", tp([44], ["home_badge_pro"]) + tp([45, 46], DIEM)
     + s(22, 23, 25, 26, 30, 31, 36, 38, 50, 51, 52, 53, 54), "SUB_AND_44@home_badge_pro"),
    ("E2", tp([47], DIEM) + s(24), None),
    ("E3", s(32) + tp([48], DIEM) + s(33, 39), None),
    ("E4", s(34) + tp([49], DIEM), None),
    ("E5", tp([44, 45, 48, 49], ["select_photo_generate"]) + s(21), "SUB_AND_44@select_photo_generate"),
    ("E6", tp([44, 45, 48, 49], ["after_inter_old"]), "SUB_AND_44@after_inter_old"),
    ("E7", tp([44, 45, 48, 49], ["after_onboarding"]), "SUB_AND_44@after_onboarding"),
    # R1: chạy lại các lượt không có kết quả hợp lệ ở E5-E7 (Play "Server error",
    # tap CTA bị nuốt trước khi có mo_dialog_mua). Thứ tự giữ chuỗi trạng thái:
    # chu kỳ after_onboarding (mua -> Pro -> huỷ), rồi mua ở select_photo, 21 mua,
    # 48@after_inter_old dùng trạng thái đã huỷ của lần mua đó.
    ("R1", tp([44, 45, 48], ["after_onboarding"]) + tp([44], ["select_photo_generate"])
     + s(21) + tp([48], ["after_inter_old"]), None),
    # 46@select_photo_generate FAIL lúc 11:25 (Pro, kill app -> Generate vẫn ra paywall):
    # chạy lại ở F1 khi đang Pro để xem có lặp lại không trước khi báo bug.
    # 50 chạy lại ở F1: ảnh lần E1 bị popup "Add Widget" che, không đủ bằng chứng.
    # 33/39 SKIP ở E3 (Play chậm cập nhật sau khi mua lại, huỷ trượt): chạy lại
    # cuối F1 - sau 35 (huỷ trên máy B) hoặc runner tự huỷ.
    # 48@after_onboarding FAIL lúc 15:11 khi Google Play đang lỗi (thí nghiệm A/B 15:55
    # cho thấy app khôi phục gói bình thường) -> chạy lại đầu F1.
    ("F1", tp([48], ["after_onboarding"]) + s(17) + tp([46], ["select_photo_generate"])
     + s(50, 27, 29, 35, 33, 39), "SUB_AND_17"),
    ("F2", s(18, 28), "SUB_AND_18"),
    # 48@after_onboarding chỉ đo đúng khi trạng thái "đã huỷ, còn hạn" còn đủ thời
    # gian (xoá dữ liệu + onboarding ~3 phút, kỳ test ~5 phút; 16:15 sub hết hạn
    # giữa case). Mua mới ngay trước (44) để runner huỷ và chạy 48 liền sau.
    ("R3", tp([44, 48], ["after_onboarding"]), None),
]
# Bước có trạng thái "dùng chung" kết quả: case trái lấy kết quả case phải.
CUNG = ["SUB_AND_16=SUB_AND_44@home_badge_pro"]
KHONG_MAY_B = "SUB_AND_35=BLOCKED:can may thu hai cung Google account (--serial-b), luot nay chi co 1 may"


def ghi_ket_qua(tu_luot, py, ghi_tay=()):
    bj = os.path.join(GOC, "artifacts", "run-plan-buoc.json")
    os.makedirs(os.path.dirname(bj), exist_ok=True)
    json.dump([{"buoc": b, "cases": c, "goc": g} for b, c, g in BUOC], open(bj, "w"))
    cmd = [py, ".claude/skills/subscription-android-autotest/scripts/fill_touchpoint_matrix_results.py",
           "--root", ".", "--xlsx", TC_V2, "--out", KET_QUA,
           "--touchpoints-from-config", "apps/magic-ai.json", "--tu-luot", tu_luot, "--buoc-json", bj]
    for c in CUNG:
        cmd += ["--cung-ket-qua", c]
    for c in ghi_tay:
        cmd += ["--ghi-tay", c]
    subprocess.run(cmd, cwd=GOC, check=False)
    dl = os.path.expanduser("~/Downloads")
    if os.path.isdir(dl):
        shutil.copy(os.path.join(GOC, KET_QUA), dl)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("serial")
    ap.add_argument("--serial-b", default="", help="may thu hai cung Google account (case 35)")
    ap.add_argument("--tu-buoc", default="A1")
    ap.add_argument("--den-buoc", default="F2")
    ap.add_argument("--tu-luot", default="261009-0000",
                    help="chỉ ghi kết quả các lượt từ mốc này (lượt chạy theo luồng v2)")
    a = ap.parse_args()
    py = os.path.join(GOC, "venv", "bin", "python")
    ten = [b for b, _, _ in BUOC]
    # Case 35 chỉ ghi BLOCKED khi lượt này đi qua F1 mà không có máy B -
    # ghi sớm hơn thì Run_Plan báo F1 "BLOCKED" khi F1 còn chưa chạy.
    qua_f1 = ten.index(a.den_buoc) >= ten.index("F1")
    ghi_tay = [KHONG_MAY_B] if (qua_f1 and not a.serial_b) else []
    for buoc, cases, _ in BUOC[ten.index(a.tu_buoc): ten.index(a.den_buoc) + 1]:
        if not a.serial_b:
            cases = [c for c in cases if c != "SUB_AND_35"]
        print("===== BUOC %s: %s" % (buoc, ",".join(cases)), flush=True)
        cho = "90" if buoc in ("F2",) else "60"
        cmd = [py, "-u", "run_yaml.py", "--serial", a.serial, "--diem-cham", "all",
               "--cho-free-phut", cho, "--cases", ",".join(cases)]
        if a.serial_b:
            cmd += ["--serial-b", a.serial_b]
        subprocess.run(cmd, cwd=GOC, check=False)
        ghi_ket_qua(a.tu_luot, py, ghi_tay)
        print("===== XONG BUOC %s" % buoc, flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
