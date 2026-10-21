# Genius iOS — Subscription Sandbox (IAP) + điểm chạm Paywall · Appium

Auto-test luồng mua gói IAP Sandbox của Apple trên iPhone thật, kiểm quyền Pro/credit, Restore, Cancel, policy paywall, 17 điểm chạm paywall. Automation lo mọi thao tác trong app; **user chỉ bấm Subscribe / nhập mật khẩu Apple** (UI hệ thống).

Nguồn kiến thức (user cung cấp 21/10/2026): `~/qa-e2e/genius/plan/sub/` + luật chung `~/qa-e2e/genius/RUNBOOK_auto_e2e_test.html` (mục 00-A) + `~/qa-e2e/genius/CLAUDE.md`.

## Thông tin nhanh
| | |
|---|---|
| App | Genius IIP055 — bundle `aiphotogenerator.aifaceeditor.aivideogenerator.aibeauty` (target `iosApp`, PRODUCT_NAME `Genius` → `Genius.app`) |
| Spec | Confluence VL PRD gốc pageId=281411732 + trang con (Paywall/RevenueCat/Quota&Topup…) |
| Engine | Appium 3.6.0 + xcuitest driver 12.7.0 (WDA) trên máy thật; Simulator/Maestro chỉ cho case UI nhanh |
| Máy mua | iPhone Tester 2 (iPhone 14 Pro, iOS 26.4.2, UDID `00008120-001A20320282201E`) — account CHƯA Pro |
| Không dùng để mua | iPhone 14 của user (UDID `00008110…`) — đã Pro qua gói web Stripe hạn 2031 → không có paywall |
| Sandbox account | `qa202@apero.vn` (mật khẩu: hỏi user, không lưu) |
| Gói | Weekly 299.000đ/tuần · Yearly 1.199.000đ/năm · không có Monthly (M-0 = N/A) · không trial, không sale |
| Bộ case SUB | **53 case** = `Subscription_TestCases_Genius` (ID 1–25: Subscription 18 + Policy Audit 7) + `TC_IIP055.1.14_Logout_WebSub` (ID 1–28). Bảng «Điểm chạm Paywall» = tra cứu, KHÔNG phải case (thuộc 1 case: ID 16 / C-0) |
| Tool | `~/qa-e2e/genius/tools/` (copy trong `templates/`) |

## Đọc file nào khi nào
| Khi | Đọc |
|---|---|
| Bắt đầu bất kỳ round nào | `rules-and-lessons.md` (19 luật bất biến + cổng 5 dòng) — **bắt buộc** |
| Dựng máy / build / mở Appium | `setup-and-run.md` §1–2 |
| Mua gói, bàn giao cho user mua, cancel, restore | `setup-and-run.md` §3–5 |
| Case credit = 0 / gen cạn / quota | `setup-and-run.md` §6 |
| Case mạng (mất kết nối/mạng yếu) | `setup-and-run.md` §7 (NLC) |
| Điểm chạm paywall (ID 16 / C-0) | `touchpoints-paywall.md` |
| Ghi kết quả, report | `setup-and-run.md` §8 |

## Trạng thái gần nhất (08–09/09/2026, build 2.6.0(3))
- Round 2 SUB (07–08/09): Pass 13 · Fail 4 · N/A 4 · Blocked thật 1 (D-1) · còn lại «Chờ» (W-4a cancel Weekly, Y-2a/Y-3 cần mua Yearly, 26 case LO cần **email đã mua gói trên web**, C-0 chờ dev bật RC).
- Fail đáng chú ý: Y-2b mua Yearly không cộng lượt (27/08, 28/08) — nhưng Weekly 07/09 cộng đúng 20 ⇒ cần mua lại Yearly để chốt; Y-3 gen treo 20%; Y-2a đã Pro vẫn 3 lớp paywall; LO-102 thiếu toast «Your subcription is verified».
- Điểm chạm: 13/17 verified (100% Pass trên số đã chấm), 4 chờ RC (seedance, worldCupVideo, tryOn, wclooks). Chạy máy 38′35″.
- Store đã lên 2.7.0 → bản QA 2.6.0 bị «Update Required»; đã tắt trong code QA (xem rules). Còn treo: có chuyển sang source 2.7.0 không.
- Bộ case có thể đã thay bằng Google Sheets «Testcase Sub-IOS» (bạn ngakt1612 gửi 07/09) — **hỏi user trước mỗi round** (luật #16).

## Liên quan
- Android sub: `../android-subscription-paywall/` (cùng khái niệm điểm chạm, khác engine).
- Gen ảnh/video Genius (XCUITest): `../ios-genius-gen-image-video/` — dùng khi case cần gen thật sau khi Pro.
