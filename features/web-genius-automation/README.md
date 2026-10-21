# Genius Web automation (Playwright + pytest, Excel-driven)

Đọc file này trước khi chạy / sửa automation web Genius. Kèm: `setup-environment.md`, `architecture-and-runner.md`, `rules-and-lessons.md`, `run-and-report.md`, `templates/`.

## Scope
- App: web Genius tại `https://genius.style` (bản cũ trong repo GitHub dùng `https://genius.art`). API: `https://api-ai-genius-iip055.aperogroup.ai` (project IIP055).
- Tool trên web: Home, Image, Video, Voice (Speech), Music, AI Chat, Projects/Gallery, Daily Credit Quota, Navigation/Coming Soon, Settings (dark mode), Regression/E2E.
- Lưu ý tên: thư mục `selenium-project` thực tế dùng **Playwright (sync API) + pytest**, không phải Selenium.

## File testcase (Excel = nguồn sự thật)
| File | Nội dung |
|---|---|
| `/Users/kieunga/Downloads/TC_Genius_Web_Automation.xlsx` | Bản cũ (19/09), sheet `TC_Genius_Web` 32 TC, 9 cột (N°, Feature, Test Description, Sub-scenario, Precondition, Test Data, Action, Expected Result, PASS/FAIL) |
| `/Users/kieunga/Downloads/TC_Genius_Web_Automation_v1.3.xlsx` | Bản mới (22/09), 36 TC + cột `Automation`; thêm sheet `Summary`, `Spec Deviations` |
| `genius-web-automation/TC_Genius_Web_Automation.xlsx` | = v1.3, file runner đang đọc |
| `genius-web-automation/TC_Genius_Web_Automation_Result_<ts>.xlsx` | Output, không sửa file gốc |

Format: dòng header bắt đầu ô `N°`; dòng phân nhóm bắt đầu `▌` (vd `▌ IMAGE GENERATOR (/agent/image)`); cột Feature merge → chỉ dòng đầu nhóm có giá trị.

## Repo / thư mục
| Nơi | Vai trò |
|---|---|
| `/Users/kieunga/Downloads/genius-web-automation` | **Bản mới nhất** (21–22/09). Không có `.git`; cập nhật bằng `update.sh` từ zip `genius-web-automation-v*.zip` |
| `/Users/kieunga/selenium-project` | Bản cũ (15–19/09), có git, remote `https://github.com/ngakt-1612/test-web-genius.git`, branch `main`, HEAD `dc1dc69` |
| `/Users/kieunga/qa-e2e` | Repo team `Apero-Vibecode/qa-e2e`: plan/report **mobile** (Genius iOS IIP055, Appium/XCUITest), KHÔNG phải web automation. Chỉ tham khảo quy ước report (HTML, index.html mục lục, RUNBOOK 19 luật) |
| `/Users/kieunga/Downloads/inspect_dom.py` | Bản cũ của tool quét DOM (khác nhẹ bản trong project) |
| `/Users/kieunga/Downloads/HUONG-DAN-SU-DUNG (1).html` | Hướng dẫn Auto-Test **IAP iOS** (sandbox, Discord ping) — KHÔNG liên quan web; xem feature sub mobile |

## Status (đến 22/09/2026)
- Lượt chạy gần nhất `pytest -m "not credit"` 22/09 17:16–17:19 (~3 phút): 29 TC ghi kết quả → **22 PASS / 7 BLOCKED / 0 FAIL**.
  - BLOCKED (gồm xfail): TC4, 9, 14, 15, 24, 27, 33[gallery_child].
- Nhóm `credit` (tốn credit thật) chưa chạy đủ: budget 10 credit/ngày, cần staging/tài khoản QA quota cao.
- Bug đã xác nhận: URL không tồn tại không ra 404, catch-all redirect `/agent/image` (TC29/33, `xfail(strict=True)`) → cần log Jira (chưa xác minh đã log).
- Chờ PO/BA: bảng giá credit (AMBIGUOUS #12), giờ reset credit, định dạng file reference, copy 4 mã lỗi ERR_*, /plans thiếu Terms/Privacy.
- `genius-web-automation` chưa push lên GitHub (chưa xác minh) — repo GitHub vẫn là bản `selenium-project`.

## Đọc tiếp
1. `setup-environment.md` — venv, browser, login Google 1 lần.
2. `architecture-and-runner.md` — cấu trúc code, runner Excel, fixture.
3. `rules-and-lessons.md` — luật bắt buộc + bài học sai.
4. `run-and-report.md` — lệnh chạy, đọc kết quả.
