# Quy tắc làm việc chung — mọi feature automation test

Rút ra từ các lần user sửa/chốt trong lịch sử (09/2026 → 10/2026). Đọc file này TRƯỚC khi chạy bất kỳ feature nào.

## 1. Phạm vi (scope)
- **Chỉ chạy TC của spec/file TC user đưa lần này.** Plan, report, skill, bộ TC cũ user gửi kèm = công cụ & kinh nghiệm, KHÔNG phải phạm vi chạy lại.
  — Why: 18/10 chạy lại toàn bộ 51 TC gen ảnh + 62 TC gen video cho Genius 2.9.0, mất ~1h máy; user: "là công cụ, kiến thức để bạn áp dụng".
  — How: trước khi chạy, map tài liệu tham khảo → danh sách TC mới; chỉ dùng driver/rule cũ cho bước của TC mới cần (vd TC 2.9.0 có bước gen ảnh).
- Nhóm/case user đã chủ ý bỏ thì không tự thêm lại (vd Android sub: bỏ nhóm 7 Change Plan, nhóm 8 khuyết cố ý).

## 2. TC sinh ra để chạy automation
- Không sinh TC manual. Mọi TC phải script được (Auto | Auto + setup).
- Không có case giả lỗi server, làm chậm server, đổi giá trị Remote Config (user bỏ 18/10).
- Nhu cầu harness (RC REST API, mitmproxy, StoreKit, snapshot…) ghi vào cột ghi chú, không biến thành bước manual.
- Chi tiết: `features/testcase-generation-for-automation/`.

## 3. Chạy liên tục, không chờ nhắc
- Chain các bước trong 1 script nền: chạy suite → sửa lỗi test → chạy lại → build report. KHÔNG kết thúc lượt để chờ "chạy tiếp".
  — Why: 18/10 user phải gõ "chạy tiếp đi" ~8 lần, rồi nói "auto chạy tiếp ko cần tôi nhắc".
- Chỉ dừng khi thật sự cần người: mật khẩu sandbox/Google, mở khoá máy, cắm/nối máy, mạng trên điện thoại → nói rõ 1 lần cần làm gì.
- Khi user nói dừng ("mai chạy tiếp") → ghi handoff (mục 6) rồi mới dừng.
- "Chạy tiếp" áp TRONG phạm vi/round user giao. Hết round/phạm vi → báo rồi dừng, không tự mở round hay feature mới.
- Đang chờ NGƯỜI KHÁC gỡ (mua sub, nhập mật khẩu, dev bật RC, cấp email) → ghi «Chờ» (ai gỡ, đã ping lúc nào), KHÔNG ghi Blocked. Blocked chỉ cho thứ không ai gỡ được. Trong lúc chờ user thao tác trên máy: không đụng máy.

## 4. Git / chia sẻ
- KHÔNG commit/push file sinh ra (TC xlsx, script, report, results) khi user chưa bảo "push". Để local, báo đường dẫn.
  — Why: user chốt 10/10 trên repo 903Magic-ai, muốn review trước.
- Không đưa secret (mật khẩu, token, cookie, auth.json) vào report/artifact/repo.

## 5. Phân loại kết quả (thống nhất mọi feature)
| Kết quả | Khi nào |
|---|---|
| PASS | Đúng expected |
| FAIL | App sai so với spec (bug) — kèm screenshot + bước tái hiện |
| MISMATCH | Spec/TC và app lệch nhưng chưa chắc là bug (spec mơ hồ) → đưa vào sheet Ambiguity |
| CHECK | Cần người nhìn lại (kết quả cảm quan / đo không chắc) |
| BLOCKED | Không chạy được do môi trường (hết credit, server lỗi, thiếu máy, Play page lỗi) — ghi lý do |
| N/A | Không áp dụng cho build/cấu hình này |
| Lỗi đo (measurement error) | Test script sai timing/locator → sửa script, chạy lại, KHÔNG báo bug |
- Trước khi báo FAIL: chạy lại ≥1 lần để loại flaky; phân biệt lỗi app vs lỗi script; có đối chứng + ảnh.
- Feature có thang chấm riêng do user chốt thì dùng thang đó (vd Genius sub Appium: chỉ Pass/Fail/Skip/N/A/Blocked + Chờ).
- Không tự sinh/nở testcase (ngoại lệ: bộ UI toàn app Genius được sinh từ ảnh Figma — user mở 19/09), không tự diễn giải Precondition; file TC của user chỉ ĐỌC — kết quả ghi ra file riêng.

## 6. Lưu tiến trình & bàn giao
- Mỗi phiên dài: ghi handoff `00-trang-thai-va-cach-chay-tiep.md` (hoặc `handoff-…-trang-thai-va-cach-chay-tiep.md`) gồm: đã chạy gì / kết quả, case còn lại, trạng thái máy (sub, quyền, setting), lệnh chạy tiếp chính xác.
- Cập nhật memory dự án sau mỗi mốc.
- User hay yêu cầu: "tạo artifact luôn", "update report", "lưu ảnh screenshot" → report là HTML artifact (private) + file kết quả xlsx (`*_ket_qua.xlsx`) + zip gói bằng chứng.

## 7. Môi trường máy (máy Mac của user)
- iOS: Xcode 26.6 qua `DEVELOPER_DIR` (xcode-select đang trỏ CLT); máy test iPhone 12 (đen) đã pair; Java chưa cài → Maestro không dùng được → dùng XCUITest.
- Android: adb + python venv trong repo `~/magic-ai-sub-e2e`; có thể nối 2 máy cùng lúc.
- Chi tiết theo feature trong `features/*/setup-environment.md`.
