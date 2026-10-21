# Plan — Automation test tính năng AI Chat (áp dụng cho mọi app)

> Plan từng bước để **một người bất kỳ + Claude Code** dựng và chạy automation test cho tính năng AI Chat (chat với AI để tạo/sửa ảnh, video, trả lời chữ) trên **máy thật**. Rút từ đợt chạy thật Genius iOS 2.9.0 (105 TC, 20/10/2026 — 97/105 có kết quả, 11 bug thật). Ví dụ cụ thể của Genius đặt trong khung `Ví dụ Genius` — thay bằng giá trị app của bạn.

## 0. Cách dùng plan này
1. Cài agent (1 lần):
   ```bash
   git clone https://github.com/ngakt-1612/agent-auto-test.git ~/automation-test-agent
   ln -sfn ~/automation-test-agent ~/.claude/skills/automation-test-agent
   ```
2. Mở Claude Code ở thư mục source app, gõ prompt khởi động:
   ```
   Dùng skill automation-test-agent. Đọc plans/plan-autotest-ai-chat-ap-dung-moi-app.md và common/working-rules.md.
   App: <tên app, bundle id>. Spec AI Chat: <link Confluence/file>. Source: <đường dẫn>. Máy: <iPhone/Android, UDID>.
   Chạy Phase 1 → dừng ở cổng duyệt của Phase 2 cho tôi xem testcase.
   ```
3. Mỗi phase có **Đầu ra** và **Cổng** — chỉ sang phase sau khi cổng đạt. Prompt mẫu cho từng phase ở cuối mỗi phase.
4. Tài liệu tham chiếu chi tiết (code mẫu, luật đã vấp): `features/ios-genius-ui-library-ai-chat/` — đặc biệt `ai-chat-testing-knowledge.md`, `flow-and-locators.md`, `rules-and-lessons.md`, `templates/`.

## 1. Đầu vào phải có trước khi bắt đầu
| # | Thứ | Ghi chú |
|---|---|---|
| 1 | Spec AI Chat (Confluence/PDF) + spec BE nếu có | Nguồn Expected duy nhất |
| 2 | Source app build được (iOS: Xcode project; Android: Gradle) | Cần để thêm target test + đọc code xác nhận bug |
| 3 | Máy thật đã pair, Developer Mode bật, Auto-Lock = Never, cắm cáp | Chat gọi AI server thật → simulator không đủ |
| 4 | Tài khoản test mua được gói (Sandbox Apple ID / License tester Google) | Người giữ mật khẩu; agent không lưu |
| 5 | Remote Config bật tính năng Chat trên môi trường test | **Agent không tự đổi RC** — nhờ dev/PO |
| 6 | Figma (nếu có) | Để so UI trong report |
| 7 | Thư viện ảnh trên máy: ảnh mặt người, ảnh phong cảnh, 1 video ≤15 s, 1 video dài hơn giới hạn | Dữ liệu cho case kèm tệp |

## 2. Nguyên tắc bất biến (đọc trước mọi phase)
- Chỉ chạy TC của spec này; plan/skill cũ là công cụ, không phải phạm vi.
- **Không mock server, không đổi RC, không bơm lỗi/làm chậm server**; lỗi/timeout server chỉ chấm khi gặp thật.
- Không có TC manual: mọi TC phải `Auto` hoặc `Auto + setup` (setup = người bấm mua/nhập mật khẩu).
- **Lượt (credit) là tài nguyên**: gom nhiều TC vào 1 lần gửi; chạy nhóm 0 lượt trước, nhóm hết lượt cuối ngày.
- Tự chạy liên tục trong phạm vi được giao; chỉ dừng ở bước cần người (mật khẩu, mở khoá máy, trust chứng chỉ) và nói rõ cần làm gì.
- Không commit/push khi chưa được bảo. Không ghi mật khẩu/token vào bất kỳ file nào.

## Phase 1 — Đọc spec, lập bản đồ tính năng (0 lượt, ~30′)
**Làm:**
1. Đọc spec Chat + spec BE; liệt kê màn (vd 901 Chat, 902 xem kết quả), trạng thái, paywall/credit gate, giới hạn (độ dài, loại tệp, thời lượng video), thông báo lỗi.
2. Lập bảng **Ambiguity**: chỗ spec mơ hồ/mâu thuẫn (vd ngôn ngữ chữ trên UI, số lần chào paywall/ngày, Library hiển thị kết quả Chat thế nào). Mỗi dòng: câu hỏi · giả định tạm · ai trả lời.
3. Đọc code màn Chat (nếu có source) để biết: control là button hay ảnh + tap gesture, có accessibility id không, picker nhận loại tệp gì.

**Đầu ra:** `plans/<ngày>-<app>-ai-chat/spec-map.md` (màn · trạng thái · luật) + sheet Ambiguity.
**Cổng:** user xem Ambiguity, trả lời hoặc chấp nhận giả định.
**Prompt mẫu:** `Phase 1: đọc spec <link>, lập spec-map + Ambiguity, đọc code màn Chat ở <thư mục>, dừng cho tôi trả lời Ambiguity.`

## Phase 2 — Sinh testcase cho automation (0 lượt, ~45′)
**Làm:** dùng skill `anthropic-skills:qa-testcase-generator` (Mode G) hoặc script mẫu `features/ios-genius-ui-library-ai-chat/templates/gen_ai_chat_testcases.py` (sửa dữ liệu, giữ khuôn). Xlsx 13 cột (xem `features/ios-genius-ui-library-ai-chat/testcase-generation-rules.md`), sheet TC · Ambiguity · Automation Setup · Summary; cột Automation = `Auto` | `Auto + setup`.

**Khung nhóm TC chuẩn cho AI Chat** (đổi tên prefix theo app):
| Nhóm | Phủ gì | Ví dụ TC Genius |
|---|---|---|
| CH01 Lối vào & trạng thái trống | tab/nút vào Chat, câu chào, chip gợi ý, cuộc trò chuyện mới, lịch sử, cuộn | CH01 · 11 TC |
| CH02 Thanh soạn & gửi | ô nhập, nút gửi bật/tắt, giới hạn ký tự, kèm ảnh/video, loại tệp sai, quyền thư viện, rời màn khi đang gửi, câu chào không tạo nội dung | CH02 · 21 |
| CH03 Gate trả phí/lượt | chuỗi paywall khi chưa mua, mua trong chuỗi, trừ lượt, hết lượt (dialog), nạp thêm | CH03 · 12 |
| CH04 Yêu cầu gộp | "tạo 2 ảnh", "ảnh rồi video" → app xử lý/nhắc thế nào | CH04 · 5 |
| CH05 Lỗi | mất mạng giữa chừng, quá thời gian, nội dung vi phạm, tạo lỗi + Retry | CH05 · 5 |
| CH06 Kết quả | Save/Share/Regenerate/Report, mở màn xem, có trong Library | CH06 · 12 |
| CH07 Chọn để sửa tiếp | vuốt chọn, thanh "Editing this", bỏ chọn, tệp đã xoá | CH07 · 10 |
| CH08 Màn xem kết quả | mở từ Chat/Library, bàn phím, giữ phần đang soạn, chặn khi chưa mua, trợ năng | CH08 · 12 |
| VB Lối tắt ngoài Chat | dải gợi ý ở Home điền sẵn prompt | VB01–03 · 15 |
| REG E2E/Regression | luồng đầy đủ + tính năng cũ bị ảnh hưởng | REG02 · 2 |

**Luật sinh TC:** mỗi TC trỏ về 1 điều trong spec; Precondition ghi rõ trạng thái gói/lượt/RC/quyền (để xếp lịch Phase 5); không TC đo thời gian AI; không TC so giá (giá do store trả); không TC cần đổi RC/mock.
**Đầu ra:** `TC_<App>_AI_Chat.xlsx` + `spec-cases.json` (dùng cho report).
**Cổng:** user duyệt số TC + bỏ/sửa case (lần Genius: bỏ case manual, bỏ case giả lỗi server).
**Prompt mẫu:** `Phase 2: sinh TC AI Chat theo khung nhóm trong plan, xuất xlsx 13 cột + spec-cases.json, không case manual/mock/đổi RC.`

## Phase 3 — Dò UI trên máy (probe, 0 lượt, ~30′)
**Làm:**
1. Viết test probe: mở Chat, `dump()` cây accessibility (`DUMP|tag|type|label|id|value|frame`), chụp ảnh từng trạng thái (trống, đang gõ, menu ···). Mẫu: `templates/Genius290AiChatProbeUITests.swift`.
2. Lập **bảng locator**: mỗi phần tử → cách chọn (id / label / tên ảnh SF Symbol / toạ độ tương đối). Chat thường **không có id** — nút cộng/gửi là ảnh (`plus`, `arrow.up`), hàng nút kết quả là text (`Save`, `Share`, `Regenerate`).
3. Dò cử chỉ khó bằng probe riêng (0 lượt): vuốt chọn kết quả, kéo đóng màn xem, chạm ẩn bàn phím. Ghi thông số chốt (vd Genius: giữ 0,5 s + kéo 150 pt với vận tốc 150 pt/s; kéo nhanh = chạm → mở màn xem).
4. Nếu được phép sửa app: gắn `accessibilityIdentifier` cho control chính (backup file gốc, báo user, không đổi hành vi).

**Đầu ra:** `flow-and-locators.md` của app (mẫu: `features/ios-genius-ui-library-ai-chat/flow-and-locators.md` §AI Chat).
**Cổng:** mọi phần tử trong Expected của TC đều có cách chọn.

## Phase 4 — Dựng hạ tầng test (0 lượt, ~1–2 h)
**Helper bắt buộc** (mẫu `templates/Genius290Support.swift` + `Genius290AiChatWithSubUITests.swift`):
| Helper | Việc |
|---|---|
| `reachMain(app)` | Launch (ép ngôn ngữ en), qua onboarding/paywall/popup tới màn chính |
| `openTab(app, "Chat")` | Vào Chat |
| `focus()` / `type()` / `clearComposer()` | Chạm ô nhập tới khi có bàn phím rồi mới gõ; xoá bằng chạm mép phải + delete theo lô, đọc lại tới khi rỗng |
| `send(prompt)` | Gõ + chạm nút gửi |
| `waitIdle(420)` | Chờ hết trạng thái "đang tạo" (spinner/`Replying`) tối đa 7 phút |
| `lastOutcome()` | Phân biệt kết quả / lỗi / chỉ chữ ở tin cuối |
| `swipeSelect(result)` | Cử chỉ chọn kết quả đã chốt ở Phase 3 |
| `dismissPaywall()` + nhận diện từng lớp | Đóng từng lớp, đọc chữ để biết đang ở lớp nào |
| `verdict(TC, STATUS, actual)` | In `VERDICT|TC|STATUS|actual` — máy đọc được |
| `snap("TC-ID — mô tả")` | Ảnh bằng chứng, tên chứa TC ID |
| Driver hệ thống | Airplane/Wi-Fi, quyền Photos, Reduce Transparency qua app Settings (`templates/SettingsNetworkDriver.swift`); popup quyền qua springboard |

**Chia suite theo tiền đề, mỗi suite 1 env gate** (`XCTSkipUnless`):
| Suite | Tiền đề | Lượt |
|---|---|---|
| Probe | bất kỳ | 0 |
| NoSub | máy CHƯA có gói (chuỗi paywall, UI trống, composer, lối tắt) | 0 / topup |
| WithSub | đang có gói, còn lượt | 1/lần gửi |
| OutOfCredit | hết lượt ngày | 0 |
| Destructive | gỡ app / quyền chưa hỏi / xoá Library | tuỳ |
**Runner:** 1 script `build` + `<GATE> <Class>[/method] <run-name>` → lưu xcresult, xuất ảnh, lọc dòng `VERDICT` (mẫu `templates/run-genius-290-device-suite.sh`). iOS: env gate phải đặt dạng `TEST_RUNNER_<GATE>=1` trước `xcodebuild`.
**Cổng:** build-for-testing xanh; probe chạy được trên máy.

## Phase 5 — Xếp lịch chạy theo tiền đề & lượt
Thứ tự chuẩn (mỗi bước = 1 queue script chạy nền + `caffeinate`):
1. Probe → NoSub (máy chưa mua). **Chuỗi paywall phải là lượt gửi đầu tiên trong ngày** nếu spec giới hạn số lần chào/ngày.
2. Mua gói (test tự mở màn mua, chọn gói, **người nhập mật khẩu**) → probe trạng thái gói (`SUBSTATE`).
3. WithSub — gom nhiều TC/1 lần gửi; theo dõi lượt còn lại.
4. Hết lượt → OutOfCredit (dialog, Get more → nạp).
5. Huỷ gói / chờ hết hạn (queue riêng, người nhập mật khẩu) → NoSub phần cần "đã từng mua".
6. Cuối cùng: Destructive (gỡ app → mất lịch sử Chat, hỏi lại quyền).
- Không sửa file queue đang chạy; muốn đổi thì viết queue mới chờ mốc `== xong <phần>`.
- Ghi trước 1 bảng: TC → suite/method → tiền đề → lượt dự kiến (mẫu `features/ios-genius-ui-library-ai-chat/ai-chat-testing-knowledge.md` §3).

## Phase 6 — Chạy & chấm
| Verdict | Khi nào |
|---|---|
| PASS | Đúng Expected, có ảnh |
| FAIL | App khác spec — **xem ảnh + đọc code** tìm `file:line` trước khi chốt |
| Lệch spec | Code cố ý khác spec / Figma giống app → PO chốt |
| Cần xem | Server lỗi/timeout thật, không đo chắc → chạy lại khi server ổn |
| N/A | Bị chặn bởi thứ ngoài tầm (CMS chưa có dữ liệu, tính năng ẩn) — ghi rõ chặn bởi gì |
| Lỗi phía test | Script sai timing/locator → **sửa test, chạy lại**, không để N/A, không báo bug |
- Server Chat chậm (≥180 s, "Couldn't reply") → chấm theo `lastOutcome`, ghi Cần xem; lỗi liên tục thì dừng nhóm tốn lượt, thử 1 lượt rẻ trước khi chạy tiếp.
- Ghi đè có lý do vào `verdict-notes.json` (`{"ui|TC-ID": {"status","actual","note","run"}}`); lượt sau thắng lượt trước, N/A không đè kết quả thật.
- Trước khi đóng: rà mọi N/A — cái nào thực ra là lỗi phía test thì sửa + chạy lại (Genius 20/10 sót 4 case: chọn ảnh theo toạ độ, thiếu bước cuộn, đọc lượt khi số tải chậm).

## Phase 7 — Report & bàn giao
1. Report HTML 1 file: KPI (đã chạy/PASS/FAIL/Lệch/Cần xem/N/A/Chưa chạy) · panel FAIL kèm nguyên nhân code · bảng TC | Kịch bản | Expected | Thực tế | Figma | Ảnh máy | Verdict. Script mẫu `templates/build-genius-290-autotest-report.py` + `genius-290-report-template.html`. Publish Artifact cùng path → cùng URL.
2. Handoff `handoff-ai-chat-...-trang-thai-va-cach-chay-tiep.md`: Kết quả · Trạng thái máy (gói, lượt, quyền, setting) · Việc tiếp có lệnh · Luật rút ra.
3. Zip: report + xlsx TC + code test + script + ảnh + handoff.
4. Cập nhật `features/<app>-ai-chat/rules-and-lessons.md` của agent với bài học mới.

## 3. Bẫy đã gặp (đọc trước Phase 3–6)
| Bẫy | Cách xử lý |
|---|---|
| Control Chat là ảnh/text + tap gesture, không có id | Chọn theo tên ảnh/label từ 1 snapshot; probe trước |
| Gõ khi chưa focus → XCUITest lỗi | `focus()` tới khi có bàn phím |
| Vuốt nhanh bị hiểu là chạm | Giữ 0,5 s rồi kéo chậm; chốt bằng probe |
| Màn xem mở nhưng ô soạn Chat vẫn trong cây | Phân biệt theo vị trí (minX) / thanh tab còn hiện |
| Paywall nhiều lớp, lớp topup không có chữ "Top-up" | Nhận diện từng lớp bằng chữ thật ("Still not ready…") |
| Paywall khi gửi ≠ hết gói | Kiểm trạng thái gói + số lượt trước khi kết luận |
| Người bấm mua giữa lúc test chạy → hỏng 2 nhóm | Test mở sẵn màn mua, hẹn đúng lúc |
| Mất mạng làm máy báo "Developer App Certificate is not trusted" | Luôn trả mạng ở `defer`; người mở VPN & Device Management |
| Kết quả Chat trong Library là ô cuộc trò chuyện | Không xoá ô ảnh để test case Chat |
| Picker chỉ nhận ảnh (code chủ ý) | FAIL kèm `file:line`, các case video phụ thuộc → N/A ghi "phụ thuộc TC-X" |

## 4. Definition of done
- 100% TC có verdict hoặc lý do "chưa chạy" cụ thể; 0 N/A do lỗi phía test.
- Mọi FAIL có ảnh + nguyên nhân (code/spec §); mọi Lệch spec có câu hỏi PO.
- Report publish, handoff + zip + bài học đã ghi vào agent.

## 5. Ước lượng (số đo Genius)
Sinh TC ~45′ · hạ tầng + probe ~2 h (lần đầu) · chạy ~4 h (máy chạy thật ~2,3 h / 55 lượt gửi) · report ~30′. Server AI chậm có thể kéo dài gấp đôi.
