---
name: automation-test-agent
description: Kiến thức đóng gói từ toàn bộ các lần train automation test (09–10/2026) — Android subscription/paywall (ADA903, AIP882, AIP918), Genius iOS sub Sandbox IAP + điểm chạm paywall (Appium), Genius iOS test UI toàn app đối chiếu Figma (UI-Baseline), Genius iOS gen ảnh/video, Genius 2.9.0 Update UI/Library/AI Chat, iOS event tracking, Genius web (Playwright), Stripe sub checker, sinh TC cho automation. Dùng khi user yêu cầu chạy/viết/lên plan automation test, autotest trên máy thật, chạy TC xlsx, test sub/paywall, event tracking, hoặc chạy tiếp một đợt autotest.
---

# Automation Test Agent

Bộ nhớ nghề cho automation test của user (QA Apero). Mỗi feature là 1 thư mục độc lập; chỉ đọc thư mục khớp yêu cầu — không nạp hết.

## Bước 0 — luôn làm
1. Đọc `common/working-rules.md` (scope, chạy liên tục, không push, phân loại kết quả, handoff).
2. Xác định feature theo bảng dưới → đọc `features/<feature>/README.md` (README có mục "khi nào đọc file nào").
3. Nếu là chạy tiếp: đọc file handoff mới nhất mà README trỏ tới + memory dự án liên quan, kiểm tra trạng thái máy trước khi chạy.

## Chọn feature
| Yêu cầu của user | Thư mục |
|---|---|
| Sub / paywall / điểm chạm / ads trên app **Android** (Magic AI ADA903, Artspire AIP882, Linguza AIP918, app VSL mới) | `features/android-subscription-paywall/` |
| Genius iOS **sub / mua Sandbox IAP / Restore / Cancel / credit / điểm chạm paywall** (Appium, bàn giao user bấm mua qua Discord) | `features/ios-genius-subscription-sandbox/` |
| Genius iOS **test UI toàn app / UI-Baseline** (đối chiếu Figma, sweep 80 màn, testcase UI theo section, Lane 1 event contract) | `features/ios-genius-ui-baseline-toan-app/` |
| Genius iOS **gen ảnh (I2I) / gen video (I2V)**, SDK Image to Image | `features/ios-genius-gen-image-video/` |
| Genius iOS **2.9.0**: Update UI, Library, **AI Chat**, paywall 236/237/238, Daily limit | `features/ios-genius-ui-library-ai-chat/` |
| **Event tracking** (event/param analytics) trên iOS | `features/ios-event-tracking/` |
| Genius **web** (genius.style) — pytest + Playwright, chạy theo xlsx | `features/web-genius-automation/` |
| Kiểm tra trạng thái sub **Stripe** | `features/web-stripe-sub-checker/` |
| **Sinh TC** từ spec/Confluence/source để chạy auto; tổng quan & thời gian chạy các project | `features/testcase-generation-for-automation/` |

Feature mới chưa có thư mục: chọn feature cùng nền tảng gần nhất làm khuôn (Android → android-subscription-paywall; iOS UI → ios-genius-ui-library-ai-chat), sau đợt chạy tạo thư mục mới cùng cấu trúc.

## Cấu trúc mỗi feature
- `README.md` — phạm vi, app/bundle/package, file TC, kết quả gần nhất, đường dẫn source, bảng "đọc file nào khi nào"
- `setup-environment.md` — công cụ, máy, tài khoản (không lưu mật khẩu), lệnh build/chuẩn bị
- `flow-and-locators.md` / `architecture-and-runner.md` / `capture-mechanism.md` — cách điều khiển app/runner
- `rules-and-lessons.md` — **quan trọng nhất**: "Luật — Why (ngày/nguồn)" từ các lần user sửa và bài học
- `run-and-report.md` — lệnh chạy, nơi ra kết quả, format report/xlsx/zip, khuôn handoff
- `templates/` — bản copy file mẫu (script, test Swift, evaluator). Bản gốc nằm trong repo nguồn (README ghi rõ); khi dùng, chép về đúng đường dẫn gốc và sửa biến trỏ scratchpad cũ (`G290_DD`, `DD`…).

## Repo nguồn (nơi code thật chạy)
- Android sub: `~/magic-ai-sub-e2e` (bản đang làm, chưa push hết) · bản clone cũ `~/903Magic-ai`
- Genius iOS sub + UI toàn app (Appium): `~/qa-e2e/genius/` (RUNBOOK_auto_e2e_test.html, plan/sub, plan/ui-baseline, tools/)
- Genius iOS: `~/Downloads/IIP055-Genius-IOS-2.9.0` (iosAppUITests, plans/, scripts/) · skill gốc `~/Downloads/ios-xcuitest-device-automation`
- Web: `~/Downloads/genius-web-automation` (mới nhất) · `~/selenium-project` (bản cũ trên GitHub test-web-genius)
- Stripe: `~/Downloads/stripe-sub-checker`

## Sau mỗi đợt chạy
Cập nhật `rules-and-lessons.md` + README (kết quả, link report) của feature đó với bài học mới; ghi handoff; cập nhật memory. Không commit/push khi user chưa bảo.
