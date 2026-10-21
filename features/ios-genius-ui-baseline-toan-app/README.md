# Genius iOS — Test UI toàn app (UI-Baseline) · Figma + Appium

Test tầng UI toàn app Genius: màn mở được không, phần tử đúng design Figma không, chạm vào đi đúng màn không. **KHÔNG** test business logic (sub, credit, restore, error handling → plan feature riêng, Expected từ Confluence) và **KHÔNG test log event** (chốt 24/09 → lane EVENT-CONTRACT riêng, xem `../ios-event-tracking/`).

Nguồn (user cung cấp 21/10/2026):
- **Plan tổng đang hiệu lực** (duyệt 19/09, cập nhật tới 24/09): artifact https://claude.ai/artifact/JYeUKrRfxuJmdoqatRZYAo — file gốc `MAIN/UI-BASELINE/Plan_UI-Baseline-ToanApp_2026-09-19_Genius.html`. **Lệch nhau thì lấy mục 11 + 🔄 mới nhất của plan này.**
- Bản cũ/lịch sử: `~/qa-e2e/genius/plan/ui-baseline/` (plan 05/09 đã bỏ, nháp 08/09, `checkpoints_2026-09-09.html`, `DaDocToiDau_Figma_2026-09-07.html`).
- Luật chung: `~/qa-e2e/genius/RUNBOOK_auto_e2e_test.html` mục 00-A (plan ghi nay là **25 luật** — đếm lại trong file, đừng tin số cũ). Tóm tắt 19 luật đầu: `../ios-genius-subscription-sandbox/rules-and-lessons.md`.

## Thông tin nhanh
| | |
|---|---|
| App/build | Genius IIP055 · iosApp Debug · 2.6.0 build 3 · commit `d3fead5e` |
| Máy | iPhone Tester 2 · iOS 26.4.2 · UDID `00008120-001A20320282201E` (chỉ 1 máy → sweep tuần tự) |
| Figma | `DVnwame4JHVgijSAdZKEjM` «IIP055 Genius (Copy)», node gốc `19986:836` — 156 node, chỉ 8 design frame, 148 ảnh chụp app dán vào |
| Expected | Node Figma (UI) · `events.json`/ID_trigger cột Timing dòng ✓ (điều hướng) · `sub_policy.md` (màn paywall) |
| Đầu ra | `MAIN/UI-BASELINE/` chỉ 3 thứ: plan tổng · `UI-Figma/` (ảnh theo 16 section + `00_Doc-truoc.html`) · `Testcase+Report/` |

## 4 con số đừng lẫn
| Số | Là gì |
|---|---|
| 156 | node trong file Figma (`_worklist.json`) |
| 133 | màn Figma khác nhau sau dedupe sha1 (17 nhóm trùng, 23 file thừa) — chấm 156 là đếm lố 23 |
| 80 | màn trong app = 6 root/tab + 37 Route + 34 paywall + 3 màn lỗi gen (đếm từ `Route.swift`, KHÔNG từ cột Screen của ID_trigger — cách cũ ra 26) |
| 157 | checkpoint = 80 màn + 77 điểm chạm `user_tap` |

## Tiến độ (24/09)
| Lô | Section | File | Kết quả Round 1 |
|---|---|---|---|
| 1 | I2V | `Testcase+Report_UI-I2V_2026-09-22.html` | 36 TC · Pass 35 · Chờ 1 (97,2%) |
| 2 | I2I | `Testcase+Report_UI-I2I_2026-09-22.html` | 40 TC · Pass 35 · Skip 4 · Blocked 1 (87,5%) |
| — | 11 section còn lại (128 node) | chưa có | chờ user bảo làm lô tiếp |
- Lane 1 (event contract) xanh 07/09: 216 test · 18 skip · 0 fail (143/161 spec event đúng hợp đồng trong code).
- Lane 2 (UI sweep tự động) **chưa chạy**: `ui_sweep.py`/`ui_diff.py` chưa viết; chặn ở WDA (CoreDeviceError 10002 / RemoteDisconnected) — có thể cần user tin cậy chứng chỉ developer trên máy.
- Còn treo: bảng 157 dòng có cột ID — là bộ testcase UI chính thức hay bảng tra cứu đánh số (user chưa chốt); cần rà lại UI-I2V theo luật 12.1–12.4.

## Đọc file nào
| Khi | Đọc |
|---|---|
| Trước mọi lần chạy | `rules-and-lessons.md` (cổng bắt buộc + luật UI) |
| Sinh testcase UI lô mới, build, Lane 1/2, lưu file | `process-and-run.md` |
| Lấy ảnh Figma | `process-and-run.md` §Figma + `templates/figma_fetch_rest.py` |
