"""Sinh khung YAML cho 49 case từ sheet mô tả của QA.

Chỉ sinh phần khung (id, tiêu đề, priority, screen, blocked_by, source_row).
Phần steps/asserts viết tay: dịch mô tả tiếng Việt thành ý định là việc cần đọc
hiểu, không tự động được.

Không ghi đè file đã có - case đã viết tay thì giữ nguyên.

Chạy: ./venv/bin/python scripts/sinh-case-stub-tu-xlsx.py [duong-dan-xlsx]
"""
from __future__ import annotations
import os
import re
import sys

import openpyxl

OUT = os.path.join(os.path.dirname(__file__), "..", "cases")
RE_ID = re.compile(r"SUB_AND_\d+")

# Màn hình nơi assertion của case diễn ra, và điều kiện ngoài còn thiếu.
# Bảng này là ƯỚC LƯỢNG từ nội dung sheet, chưa xác minh trên máy - lượt chạy
# thật sẽ đính chính. Case nào ra verdict trọn vẹn ngoài dự đoán thì XOÁ
# blocked_by, đừng giữ cho khớp bảng.
MAN = {
    "01": "paywall", "02": "paywall", "03": "paywall", "04": "paywall",
    "08": "paywall", "09": "paywall", "10": "paywall", "11": "paywall",
    "12": "paywall", "14": "paywall", "15": "paywall", "16": "paywall",
    "17": "paywall", "18": "paywall", "19": "paywall", "20": "paywall",
    "21": "paywall", "22": "paywall", "23": "paywall", "24": "paywall",
    "25": "play_sheet", "27": "play_sheet", "28": "paywall", "29": "paywall",
    "30": "home", "31": "home", "32": "home", "34": "home",
    "33": "manage_sub", "35": "manage_sub", "36": "manage_sub",
    "37": "manage_sub", "38": "manage_sub", "39": "manage_sub",
    "40": "manage_sub", "41": "manage_sub", "42": "manage_sub",
    "43": "manage_sub", "44": "manage_sub", "45": "manage_sub",
    "46": "manage_sub", "47": "manage_sub", "48": "manage_sub",
    "49": "manage_sub", "50": "manage_sub", "57": "manage_sub",
    "58": "manage_sub", "59": "manage_sub", "60": "manage_sub",
}

CHAN = {
    "02": "Play Developer API - so gia UI voi cau hinh store",
    "08": "Play Console - chua cau hinh goi sale",
    "09": "Play Console - chua cau hinh goi sale",
    "16": "Can thiet bi man nho va man lon/tablet",
    "33": "RevenueCat dashboard/API - chua co quyen truy cap",
    "39": "Play Console - khong tao duoc dieu kien renewal fail",
    "40": "Play Console - khong tao duoc dieu kien het grace period",
    "46": "Can device thu hai dang nhap cung Google account",
    "47": "Play Console - chua cau hinh subscription replacement mode",
    "48": "Play Console - chua cau hinh subscription replacement mode",
    "49": "RevenueCat dashboard/API - chua co quyen truy cap",
    "50": "Play Console - chua cau hinh subscription replacement mode",
}


def main(xlsx_path):
    wb = openpyxl.load_workbook(xlsx_path, data_only=True)
    ws = wb["TC_Subscription_Android"]
    os.makedirs(OUT, exist_ok=True)
    nhom = ""
    made = bo_qua = 0
    for row in ws.iter_rows(min_row=2, values_only=True):
        if row[0]:
            nhom = str(row[0]).strip()
        cell = row[1]
        if not cell:
            continue
        m = RE_ID.search(str(cell))
        if not m:
            continue
        tc_id = m.group(0)
        so = tc_id.split("_")[-1]
        # Tiêu đề bắt đầu bằng "[UI]"/"[Logic]"… - không quote thì YAML hiểu
        # dấu ngoặc vuông là một list. Quote kép + escape dấu " bên trong.
        title = str(cell).replace(tc_id, "").strip().replace('"', "'")
        path = os.path.join(OUT, tc_id + ".yaml")
        if os.path.exists(path):
            bo_qua += 1
            continue
        with open(path, "w", encoding="utf-8") as f:
            f.write("tc_id: %s\n" % tc_id)
            f.write('title: "%s"\n' % title)
            f.write("priority: P1\n")
            f.write("screen: %s\n" % MAN.get(so, "paywall"))
            f.write('blocked_by: "%s"\n' % CHAN.get(so, ""))
            f.write('source_row: "%s"\n' % nhom.replace('"', "'"))
            f.write("steps: []\n")
            f.write("asserts: []\n")
        made += 1
    print("sinh %d file, bo qua %d file da co, trong %s" % (made, bo_qua, OUT))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1
         else os.path.expanduser("~/Downloads/TC_Subscription_Android.xlsx"))
