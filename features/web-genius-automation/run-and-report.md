# Chạy & báo cáo — Genius Web automation

Luôn: `cd /Users/kieunga/Downloads/genius-web-automation && source .venv/bin/activate` (agent bị hook chặn `.venv` → xem setup-environment.md §1).

## Lệnh
| Mục đích | Lệnh | Credit |
|---|---|---|
| Smoke nhanh | `pytest -m smoke` | 0 |
| UI regression | `pytest -m "ui or mock"` | 0 |
| Toàn bộ trừ credit (mặc định nightly) | `pytest -m "not credit"` | 0 |
| Nhóm tốn credit (1 lần/ngày sau reset) | `pytest -m credit` | ~8 |
| 1 feature theo Excel | `python excel_test_runner.py --feature "Home"` | tùy |
| 1 TC theo N° | `python excel_test_runner.py --tc 12` | tùy |
| Lọc marker qua runner | `python excel_test_runner.py -m "not credit"` | |
| Kiểm tra mapping Excel ↔ test | `python excel_test_runner.py --check` | 0 |
| Liệt kê TC | `python excel_test_runner.py --list` | 0 |
| Dry run | `python excel_test_runner.py --feature "Home" --dry-run` | 0 |
| Chạy + đổ kết quả | `python excel_test_runner.py -m "not credit" --write-results` | |
| Đổ kết quả về Excel | `python results_writer.py` | 0 |
| Xem browser | `HEADLESS=0 SLOW_MO=300 pytest -m smoke` | |
| Login + chạy not credit | `python setup_login.py` | 0 |

Exit code: 0 ok · 1 thiếu mapping (`--check`) · 2 không thấy TC · 3 feature không mapping · 4 session hỏng (chạy `setup_login.py`).

## Thứ tự khuyến nghị cho một round
1. `python auth_status.py` → hỏng thì nhờ user `python setup_login.py --login-only` (user nhập Google).
2. `python excel_test_runner.py --check` (Excel có đổi?).
3. `pytest -m "not credit"` (~3 phút, 22/09: 29 TC).
4. Nếu còn credit & user cho phép: `pytest -m credit`.
5. `python results_writer.py`.
6. FAIL → chạy lại TC đó 1 lần (`--tc N`) để loại flaky; phân loại lỗi app vs lỗi script trước khi báo bug.

## Output
- `reports/results.json` — key = số TC; `{tc, nodeid, status, duration, message, timestamp}`.
- `reports/screenshots/TC<NN>.png` — evidence mỗi TC (viewport, không full page).
- `TC_Genius_Web_Automation_Result_<YYYYMMDD_HHMM>.xlsx` — cột `PASS/FAIL` tô màu (PASS xanh C6EFCE, FAIL đỏ FFC7CE, BLOCKED vàng FFEB9C) + cột `Auto Note` (duration | dòng cuối lỗi ≤150 ký tự). File gốc giữ nguyên.
- `dom_report.txt`, `network_report.txt` — từ tool chẩn đoán.
- `reports/`, `*_Result_*.xlsx` đều gitignore.

## Trạng thái kết quả
| Status | Nghĩa |
|---|---|
| PASS | test pass |
| FAIL | assertion fail — bug hoặc selector sai (phải phân biệt trước khi báo) |
| BLOCKED | skip/xfail: hết credit, thiếu data, chờ PO/BA, bug đã biết |
Map sang chuẩn chung (`common/working-rules.md` §5): spec mơ hồ → MISMATCH; lỗi script → "lỗi đo", sửa & chạy lại.

## Báo cáo cho user
- Bảng tóm tắt PASS/FAIL/BLOCKED + lý do từng BLOCKED + đường dẫn file `_Result_*.xlsx` + thư mục screenshots.
- Spec lệch → cập nhật `SPEC_DEVIATIONS.md` (sheet `Spec Deviations` trong v1.3) theo mẫu: hiện tượng, HTML/text thực tế làm bằng chứng, TC ảnh hưởng, trạng thái, đề xuất FE.
- Bug thật → đề xuất log Jira (skill `rongbug`/`jira-log-bug` khi user gõ `bug_ad`/`bug_file`).
- Push GitHub chỉ khi user yêu cầu; repo `https://github.com/ngakt-1612/test-web-genius.git`.
