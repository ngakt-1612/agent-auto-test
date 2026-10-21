#!/usr/bin/env python3
"""Ghi trạng thái test (PASS/FAIL/BLOCKED/N/A) vào cột kết quả của file testcase .xlsx.

Dùng khi QA muốn nhận lại chính file của họ đã điền trạng thái, thay vì đọc report riêng.

    python3 write-status-to-xlsx.py TC.xlsx statuses.json [--col I] [--out TC-filled.xlsx]

`statuses.json` dạng {"1": "PASS", "33": "FAIL", ...} — khoá là số case ở cột A.

Chỉ dùng thư viện chuẩn: đọc/ghi OOXML bằng zipfile + regex, giữ nguyên mọi phần khác của workbook
(sharedStrings, styles, drawings). Ô mới ghi dạng `inlineStr` nên không phải đụng sharedStrings.
"""
import argparse, json, re, shutil, sys, zipfile
from xml.sax.saxutils import escape
from xml.etree import ElementTree as ET

NS = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'


def read_cell(cell, shared):
    """Đọc giá trị một ô, xử lý cả shared string, inline string và số."""
    kind = cell.get('t')
    if kind == 'inlineStr':
        return ''.join(t.text or '' for t in cell.iter(f'{{{NS}}}t'))
    v = cell.find(f'{{{NS}}}v')
    if v is None:
        return ''
    return shared[int(v.text)] if kind == 's' else (v.text or '')


def row_of_each_case(zf):
    """Map số case (cột A) -> số dòng. Số case có thể là float ("1.0") nên phải ép qua int(float())."""
    shared = []
    if 'xl/sharedStrings.xml' in zf.namelist():
        shared = [''.join(t.text or '' for t in si.iter(f'{{{NS}}}t'))
                  for si in ET.fromstring(zf.read('xl/sharedStrings.xml'))]
    sheet = ET.fromstring(zf.read('xl/worksheets/sheet1.xml'))
    out = {}
    for row in sheet.findall(f'.//{{{NS}}}row'):
        cells = {c.get('r')[0]: c for c in row.findall(f'{{{NS}}}c')}
        if 'A' not in cells:
            continue
        try:
            out[int(float(read_cell(cells['A'], shared)))] = row.get('r')
        except ValueError:
            continue
    return out


def set_cell(xml, ref, text):
    """Thay ô `ref` bằng inline string, giữ lại style `s="..."` cũ.

    Hai mẫu regex tách riêng, **thứ tự quan trọng**: mẫu thẻ tự đóng phải thử trước. Nếu dùng một mẫu
    `[^>]*(?:/>|>.*?</c>)` thì `[^>]*` nuốt qua dấu `/` của thẻ tự đóng rồi `.*?</c>` ăn sang ô của
    dòng kế tiếp — lỗi này từng xoá mất 50 dòng của file thật.
    """
    m = re.search(r'<c r="%s"([^>]*?)/>' % ref, xml) or \
        re.search(r'<c r="%s"([^>]*?)>.*?</c>' % ref, xml, re.S)
    if not m:
        return xml, False
    attrs = m.group(1).strip().replace(' t="s"', '').replace(' t="inlineStr"', '')
    style = f' {attrs}' if attrs else ''
    cell = f'<c r="{ref}"{style} t="inlineStr"><is><t>{escape(text)}</t></is></c>'
    return xml[:m.start()] + cell + xml[m.end():], True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('xlsx')
    ap.add_argument('statuses')
    ap.add_argument('--col', default='I', help='cột ghi trạng thái (mặc định I)')
    ap.add_argument('--out', help='file ra; mặc định ghi đè sau khi tạo bản .bak')
    args = ap.parse_args()

    statuses = {int(k): v for k, v in json.load(open(args.statuses)).items()}
    with zipfile.ZipFile(args.xlsx) as zf:
        rows = row_of_each_case(zf)
        xml = zf.read('xl/worksheets/sheet1.xml').decode('utf-8')

    written, missing = 0, []
    for no, status in sorted(statuses.items()):
        r = rows.get(no)
        if r is None:
            missing.append(no); continue
        xml, ok = set_cell(xml, f'{args.col}{r}', status)
        written += ok
        if not ok:
            missing.append(no)

    out = args.out
    if not out:
        shutil.copy(args.xlsx, args.xlsx.replace('.xlsx', '-bak.xlsx'))
        out = args.xlsx
    with zipfile.ZipFile(args.xlsx) as zin, \
         zipfile.ZipFile(out + '.tmp', 'w', zipfile.ZIP_DEFLATED) as zo:
        for item in zin.infolist():
            data = xml.encode('utf-8') if item.filename == 'xl/worksheets/sheet1.xml' \
                else zin.read(item.filename)
            zo.writestr(item, data)
    shutil.move(out + '.tmp', out)

    # Kiểm chứng sau khi ghi — nguyên tắc 1: không tin cú ghi, chỉ tin giá trị đọc lại.
    with zipfile.ZipFile(out) as zf:
        before = xml.count('<row ')
        after = zf.read('xl/worksheets/sheet1.xml').decode().count('<row ')
    print(f'ghi {written} ô vào cột {args.col} · {out}')
    print(f'dòng trước/sau: {before}/{after}' + ('  ⚠️ LỆCH — kiểm lại!' if before != after else '  ✓'))
    if missing:
        print('không ghi được các case:', missing, file=sys.stderr)


if __name__ == '__main__':
    main()
