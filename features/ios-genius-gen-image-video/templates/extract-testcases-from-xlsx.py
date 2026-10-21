"""Trích testcase từ file xlsx ra JSON. Đọc bằng stdlib, không cần openpyxl.

Dùng: python3 extract-testcases-from-xlsx.py <file.xlsx> [out.json]

Giữ nguyên văn Precondition / Test Data / Action / Expected để báo cáo gộp đối chiếu được với
spec gốc, không diễn giải lại.
"""
import json
import re
import sys
import xml.etree.ElementTree as ET
import zipfile

NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
SRC = sys.argv[1] if len(sys.argv) > 1 else "testcases.xlsx"
OUT = sys.argv[2] if len(sys.argv) > 2 else "cases.json"

COLUMNS = {
    "A": "no", "B": "feature", "C": "desc", "D": "sub",
    "E": "pre", "F": "data", "G": "act", "H": "exp",
}

z = zipfile.ZipFile(SRC)
shared = []
if "xl/sharedStrings.xml" in z.namelist():
    shared = ["".join(t.text or "" for t in si.iter(NS + "t"))
              for si in ET.fromstring(z.read("xl/sharedStrings.xml"))]


def cell_text(cell):
    kind = cell.get("t")
    value = cell.find(NS + "v")
    if kind == "s" and value is not None:
        return shared[int(value.text)]
    if value is not None:
        return value.text or ""
    return "".join(t.text or "" for t in cell.iter(NS + "t"))


def lines(text):
    """Cell nhiều dòng → list; bỏ số thứ tự "1." đầu dòng vì bản gộp tự đánh số."""
    out = []
    for raw in text.split("\n"):
        item = raw.strip()
        if not item:
            continue
        out.append(re.sub(r"^\d+[.)]\s*", "", item))
    return out


cases, section, carry = [], None, {}
sheet = next(n for n in z.namelist() if re.match(r"xl/worksheets/sheet1\.xml$", n))
for row in ET.fromstring(z.read(sheet)).iter(NS + "row"):
    cells = {}
    for cell in row.iter(NS + "c"):
        col = re.match(r"[A-Z]+", cell.get("r")).group()
        if col in COLUMNS:
            cells[COLUMNS[col]] = cell_text(cell).strip()

    number = cells.get("no", "")
    if number.startswith("▌"):
        section = number.lstrip("▌ ").strip()
        continue
    # Bản cập nhật của file ghi số thứ tự dưới dạng số thực ("1.0"), bản trước ghi số nguyên ("1").
    # Chấp cả hai, không thì toàn bộ case bị bỏ qua im lặng.
    try:
        number = str(int(float(number)))
    except ValueError:
        continue

    # Cột Feature/Test Description để trống nghĩa là gộp ô với hàng trên — mang giá trị xuống.
    for key in ("feature", "desc"):
        if cells.get(key):
            carry[key] = cells[key]
        else:
            cells[key] = carry.get(key, "")

    cases.append({
        "no": int(number),
        "section": section,
        "feature": cells.get("feature", ""),
        "desc": cells.get("desc", ""),
        "sub": cells.get("sub", ""),
        "pre": lines(cells.get("pre", "")),
        "data": cells.get("data", "").replace("\n", " · "),
        "act": lines(cells.get("act", "")),
        "exp": lines(cells.get("exp", "")),
    })

cases.sort(key=lambda c: c["no"])
json.dump(cases, open(OUT, "w"), ensure_ascii=False, indent=1)
print("case:", len(cases))
print("section:", sorted({c["section"] for c in cases}))
missing = [c["no"] for c in cases if not c["exp"]]
print("case thiếu Expected:", missing)
