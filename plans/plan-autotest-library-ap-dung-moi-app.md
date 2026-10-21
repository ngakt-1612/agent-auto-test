# Plan — Automation test tính năng Library / Thư viện kết quả (áp dụng cho mọi app)

> Plan từng bước để **một người bất kỳ + Claude Code** dựng và chạy automation test cho màn **Library** (lưới kết quả ảnh/video/cuộc trò chuyện do app tạo: lọc, chọn, xoá, trạng thái trống, offline, tạo ở nền, lưu theo tài khoản) trên **máy thật**. Rút từ đợt chạy thật Genius iOS 2.9.0 (Update UI + Library 84 TC, 18–19/10/2026 — 74 PASS · 7 FAIL · 3 lệch spec). Ví dụ Genius để trong khung `Ví dụ Genius` — thay bằng giá trị app của bạn.

## 0. Cách dùng plan này
1. Cài agent (1 lần):
   ```bash
   git clone https://github.com/ngakt-1612/agent-auto-test.git ~/automation-test-agent
   ln -sfn ~/automation-test-agent ~/.claude/skills/automation-test-agent
   ```
2. Prompt khởi động trong Claude Code (mở ở thư mục source app):
   ```
   Dùng skill automation-test-agent. Đọc plans/plan-autotest-library-ap-dung-moi-app.md và common/working-rules.md.
   App: <tên, bundle id>. Spec Library: <link>. Source: <đường dẫn>. Máy: <UDID>.
   Chạy Phase 1 → dừng ở cổng duyệt Phase 2.
   ```
3. Mỗi phase có **Đầu ra** + **Cổng**. Code mẫu & luật chi tiết: `features/ios-genius-ui-library-ai-chat/` (`flow-and-locators.md` §Library, §Tạo nền; `rules-and-lessons.md`; `templates/Genius290LibraryReadOnlyUITests.swift`, `Genius290Support.swift`).

## 1. Đầu vào
| # | Thứ | Ghi chú |
|---|---|---|
| 1 | Spec Library (+ spec tính năng tạo nội dung, gói/lưu theo tài khoản) | Nguồn Expected |
| 2 | Source app build được | Thêm target test, đọc code xác nhận bug |
| 3 | Máy thật, Auto-Lock = Never, cắm cáp | |
| 4 | Tài khoản test mua được gói + 1 tài khoản chưa từng mua (nếu có case "chưa mua") | Người giữ mật khẩu |
| 5 | Library có sẵn ≥ 8 kết quả đủ loại (ảnh, video, cuộc trò chuyện) — hoặc lượt để tạo | Kết quả nên **khác nhau rõ** (không toàn chân dung giống nhau) để đo xoá |
| 6 | Figma Library | So UI |

## 2. Nguyên tắc bất biến
- Chỉ chạy TC của spec này; không mock, không đổi RC, không bơm lỗi server.
- Không TC manual. **Không để N/A vì thận trọng**: được phép xoá hết Library để test trống, chờ gói hết hạn thật, tự viết bước thiếu (Genius 18/10: 18 N/A → 6 sau khi user yêu cầu).
- Thứ tự phá trạng thái xếp cuối: xoá Library → huỷ gói/chờ hết hạn → gỡ app.
- **Không gỡ app sau khi mua gói** (trừ case cần, xếp cuối) — restore kéo về hàng trăm kết quả cũ.
- Tự chạy liên tục trong phạm vi; dừng chỉ ở bước cần người. Không commit/push khi chưa được bảo.

## Phase 1 — Đọc spec, lập bản đồ (0 lượt, ~30′)
1. Liệt kê: bố cục lưới (số cột, thứ tự mới nhất), bộ lọc, chế độ chọn, menu ··· / nhấn giữ, xoá (1 / nhiều / xác nhận / toast), trạng thái trống + CTA, offline, ô đang tạo + khay tiến độ, màn xem, lưu theo tài khoản (restore, hết hạn, topup), quan hệ với tính năng khác (kết quả Chat, gen ảnh/video).
2. Bảng Ambiguity (vd Genius: lọc spec `All · Image · Video` nhưng app/Figma `All · Photo · Video · Conversation`; xoá kết quả có xoá file đã lưu trong Photos không).
3. Đọc code: Library tải theo trang hay toàn bộ; ô là button hay image + gesture; có id không.
**Đầu ra:** `spec-map.md` + Ambiguity. **Cổng:** user trả lời Ambiguity.

## Phase 2 — Sinh testcase (0 lượt, ~45′)
Skill `anthropic-skills:qa-testcase-generator` (Mode G), xlsx 13 cột, cột Automation `Auto | Auto + setup` (xem `features/ios-genius-ui-library-ai-chat/testcase-generation-rules.md`).

**Khung nhóm TC chuẩn cho Library:**
| Nhóm | Phủ gì | Ví dụ Genius |
|---|---|---|
| LIB01 Bố cục & trống | tiêu đề, lưới, thứ tự, trạng thái trống + CTA đi đâu | 6 TC |
| LIB02 Lọc | từng bộ lọc, đếm đúng loại, giữ lọc khi quay lại | 6 |
| LIB03 Chọn / menu / xoá / offline | Select/Cancel, chọn nhiều, ··· và nhấn giữ, xoá 1/nhiều, huỷ xoá, toast, file đã lưu không bị xoá, mất mạng | 19 |
| LIB04 Lưu theo tài khoản | restore khi cài lại, gói hết hạn, free + topup, đổi tài khoản | 4 |
| BG01–03 Tạo ở nền | rời màn khi đang tạo, khay tiến độ (Creating/Ready/lỗi + thử lại), ô đang tạo trong Library, chạm ô đang tạo | 16 / 7 / 7 |
| REG | tính năng cũ chạm Library (Create tools, số dư) | 4 |
**Luật:** Precondition ghi rõ số kết quả cần có, loại, trạng thái gói/mạng; Expected đo được bằng máy (xem Phase 4 "Đo thay vì nhìn").
**Đầu ra:** `TC_<App>_Library.xlsx` + `spec-cases.json`. **Cổng:** user duyệt.

## Phase 3 — Probe UI (0 lượt, ~30′)
1. Test probe dump cây accessibility + chụp: Library đầy, từng bộ lọc, chế độ chọn, menu ···, hộp thoại xoá, màn xem, khay tiến độ.
2. Bảng locator + **hình học ô** (vd Genius: 3 cột, x = 26 + 122·col, y = 215 + 160·row, ô 90×70 — dùng khi ô không có id).
3. Ghi đặc điểm khó: nút ··· chồng vùng chạm ô, chip là staticText, nút trong hộp thoại.
**Đầu ra:** `flow-and-locators.md` §Library của app. **Cổng:** mọi Expected có cách đo.

## Phase 4 — Hạ tầng test (~1–2 h lần đầu)
**Helper** (mẫu `templates/Genius290Support.swift`):
| Helper | Việc |
|---|---|
| `reachMain`, `openTab("Library")`, `anyLabeled(label)` | Vào màn; chọn control text/button chung một hàm |
| `libraryCellRect(i)` | Toạ độ ô thứ i |
| `regionSignature(rect)` + `signatureDistance` | **Dấu vân 16×16** của ô để biết ô nào biến mất sau xoá (<~12 = cùng ảnh) |
| `colorFraction` / `purpleFraction` / `redFraction` | Đo trạng thái chọn / nút Delete bật bằng tỉ lệ pixel màu (không dùng màu trung bình) |
| `openCellMenu(i)` | Thử lần lượt: tap element ··· → góc nút → lệch tâm; kiểm menu `Delete` sau mỗi lần; hoặc nhấn giữ 0,5 s |
| `confirmDelete()` | Trên chính nút hộp thoại; cần chạm nhiều lần thì `tap(withNumberOfTaps:)` |
| `countToast("Deleted")` | Đếm theo lần hiện (lên → tắt = 1) |
| `photosCount()` | Đếm ảnh trong Photos (PHAsset, thêm quyền đọc cho target test) cho case "file đã lưu không bị xoá" |
| `purgeLibrary(max: 120)` | Xoá hàng loạt bằng chế độ chọn → dựng trạng thái trống |
| Driver mạng / gói | Airplane+Wi-Fi qua Settings (`SettingsNetworkDriver.swift`); `SUBSTATE` probe; mua gói có người nhập mật khẩu; huỷ gói qua Manage Subscription |
**Suite theo tiền đề, mỗi suite 1 gate:**
| Suite | Tiền đề | Lượt |
|---|---|---|
| ReadOnly | Library đầy, chỉ xem/lọc/chọn rồi Cancel | 0 |
| Delete | có ≥ N kết quả khác nhau | 0 (hoặc tạo trước) |
| Generation / VideoBackground | có gói + lượt; mỗi case "đang tạo" 1 lượt riêng | ~5–7 |
| Purge → Empty | xoá hết | 0 |
| Subscription | restore / hết hạn / topup | 0 / topup |
| Destructive | gỡ app, offline | 0 |
**Runner + queue:** như plan AI Chat Phase 4 (`templates/run-genius-290-device-suite.sh`, `run-genius-290-day2-queue.sh`).
**Cổng:** build xanh, ReadOnly chạy được.

## Phase 5 — Xếp lịch
1. ReadOnly (0 lượt) → Delete (dùng kết quả sẵn có) → Generation/VideoBackground (case "đang tạo" kiểm **ngay khi rời màn**; ảnh xong nhanh ~10–15 s nên ưu tiên video cho case cần thời gian).
2. Subscription: restore (cài lại khi CÒN gói — nhớ restore kéo về rất nhiều kết quả) → chờ hết hạn thật (probe 10 phút/lần; lượt chạy khi gói tự gia hạn = sai tiền đề, loại) → free + topup.
3. Purge → Empty (trạng thái trống, CTA).
4. Offline, gỡ app — cuối.

## Phase 6 — Chạy & chấm
Thang: PASS · FAIL (xem ảnh + `file:line`) · Lệch spec (Figma giống app / code cố ý) · Cần xem · N/A (ghi chặn bởi gì) · Lỗi phía test (sửa, chạy lại).
**Đo thay vì nhìn — luật quan trọng nhất của Library:**
- **Không đếm số ô** (Library tải theo trang ~27 ô) → đo xoá bằng dấu vân 16×16 trên 6–8 ô đầu, so lệch 0/1/2 ô.
- Ô na ná nhau (chân dung) → lưới 6×6 không phân biệt được; dùng 16×16 + chọn độ lệch điểm thấp nhất.
- Ô đang tạo: text kết thúc `%` trong vùng lưới (loại % của khay); ô đang tạo không chọn được.
- Chạm khay tiến độ → phải mở Library (Genius); lượt nền xong mở Result qua khay.
- Lượt sau thắng lượt trước; N/A không đè kết quả thật; lượt sai tiền đề loại bằng note.

## Phase 7 — Report & bàn giao
Giống plan AI Chat Phase 7: report HTML (Figma cạnh ảnh máy), handoff (Kết quả · Trạng thái máy · Việc tiếp có lệnh · Luật rút ra), zip, ghi bài học vào agent.

## 3. Bẫy đã gặp
| Bẫy | Cách xử lý |
|---|---|
| Nút ··· chồng vùng chạm ô → mở nhầm màn xem | Thử element → góc → lệch tâm, kiểm menu sau mỗi lần |
| Chạm Delete 3 lần bằng toạ độ → chạm 2–3 rơi xuống lưới | Chạm trên chính nút hộp thoại |
| Element theo index biến mất khi màn đổi | Đọc nhãn từ 1 snapshot, ghim toạ độ tuyệt đối |
| Restore gói kéo về hàng trăm kết quả cũ → không trống được | Purge trước nhóm trống; không gỡ app sau khi mua |
| Paywall khi tạo ≠ hết gói (có thể hết lượt ngày) | Probe `SUBSTATE` + số lượt |
| Gói sandbox tự gia hạn nhiều lần | Probe tới khi hết hạn thật; loại lượt sai tiền đề |
| Offline thay cả lưới bằng màn lỗi | FAIL nếu spec yêu cầu giữ lưới (Genius LIB03-017) |
| Hàng trong Setting nuốt chạm đầu | Chạm lại ≤3 lần, ghi quan sát |
| Số dư tải chậm | Chờ tới khi có số |

## 4. Definition of done
- 100% TC có verdict hoặc lý do chưa chạy cụ thể; 0 N/A do lỗi test.
- Mọi FAIL có ảnh + nguyên nhân; Lệch spec có câu hỏi PO.
- Report publish, handoff, zip, bài học ghi vào agent.

## 5. Ước lượng (số đo Genius, chung đợt Update UI + Library 84 TC)
Sinh TC ~45′ · hạ tầng + probe ~2 h · chạy ~7 h trên 2 ngày (gồm chờ gói hết hạn) · report ~30′.
