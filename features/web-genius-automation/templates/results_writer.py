"""Do ket qua pytest nguoc vao cot PASS/FAIL cua file testcase Excel.

Ghep theo so N° (marker @pytest.mark.tc(n)) nen khong phu thuoc thu tu dong.
File goc duoc giu nguyen; ban co ket qua duoc ghi ra file _Result.xlsx.
"""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path

from openpyxl import load_workbook
from openpyxl.styles import Font, PatternFill

import config

SHEET_NAME = "TC_Genius_Web"
STATUS_COLUMN_HEADER = "PASS/FAIL"

FILLS = {
    "PASS": PatternFill("solid", fgColor="C6EFCE"),
    "FAIL": PatternFill("solid", fgColor="FFC7CE"),
    "BLOCKED": PatternFill("solid", fgColor="FFEB9C"),
}
FONTS = {
    "PASS": Font(name="Arial", size=10, color="006100", bold=True),
    "FAIL": Font(name="Arial", size=10, color="9C0006", bold=True),
    "BLOCKED": Font(name="Arial", size=10, color="9C6500", bold=True),
}


def _load_results(path: Path = None) -> dict:
    path = path or config.RESULTS_JSON
    if not path.exists():
        raise FileNotFoundError(
            f"Khong tim thay {path}. Chay pytest truoc khi do ket qua."
        )
    return json.loads(path.read_text(encoding="utf-8"))


def write_results(excel_path: str | Path = None, results_path: Path = None) -> Path:
    excel_path = Path(excel_path or config.EXCEL_FILE)
    results = _load_results(results_path)

    workbook = load_workbook(excel_path)
    sheet = (
        workbook[SHEET_NAME]
        if SHEET_NAME in workbook.sheetnames
        else workbook.active
    )

    # Tim dong header va cot PASS/FAIL
    header_row = None
    status_col = None
    for row in sheet.iter_rows(min_row=1, max_row=10):
        for cell in row:
            if cell.value == "N°":
                header_row = cell.row
            if cell.value == STATUS_COLUMN_HEADER:
                status_col = cell.column
        if header_row and status_col:
            break

    if not header_row or not status_col:
        raise ValueError("Khong tim thay header 'N°' hoac cot 'PASS/FAIL'")

    note_col = sheet.max_column + 1
    sheet.cell(row=header_row, column=note_col, value="Auto Note").font = Font(
        name="Arial", size=10, bold=True
    )

    written = 0
    for row in sheet.iter_rows(min_row=header_row + 1):
        first = row[0].value
        if first is None:
            continue
        text = str(first).strip().replace(",", ".")
        if not text.replace(".", "", 1).isdigit():
            continue

        tc_number = str(int(float(text)))
        result = results.get(tc_number)
        if not result:
            continue

        status = result["status"]
        cell = sheet.cell(row=row[0].row, column=status_col, value=status)
        cell.fill = FILLS.get(status, FILLS["BLOCKED"])
        cell.font = FONTS.get(status, FONTS["BLOCKED"])

        note = f"{result['duration']}s"
        if result.get("message"):
            note += " | " + result["message"].splitlines()[-1][:150]
        sheet.cell(row=row[0].row, column=note_col, value=note).font = Font(
            name="Arial", size=9
        )
        written += 1

    stamp = datetime.now().strftime("%Y%m%d_%H%M")
    out_path = excel_path.with_name(f"{excel_path.stem}_Result_{stamp}.xlsx")
    workbook.save(out_path)

    summary = {}
    for item in results.values():
        summary[item["status"]] = summary.get(item["status"], 0) + 1
    print(f"[WRITE] Da do {written} ket qua vao {out_path.name}")
    print(f"[WRITE] Tong ket: {summary}")
    return out_path


if __name__ == "__main__":
    write_results()
