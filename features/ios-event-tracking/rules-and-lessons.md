# Luật + bài học — event tracking Genius iOS (ĐỌC TRƯỚC)

Format: **Luật** — Why (ngày / nguồn). Nguồn: transcript 05/10 (`c5ba1fd5…`), 21/10 (`72e9bcec…`), sổ tay Lensie 2.1.0 (artifact `HF32AiR3wtrjf2KpwN6DpZ`, user gửi làm "plan" cả 2 lần), handoff 21/10.

## A. Phạm vi & nguồn sự thật
1. **Chỉ chạy event trong file spec user đưa lần này** (vd `genius-eventtracking-library.xlsx`). Sổ tay Lensie, plan AI Chat cũ = công cụ/nguyên tắc, không phải phạm vi. — Why: working-rules chung (18/10); 21/10 user chỉ đưa file Library.
2. **Phạm vi đọc từ `.xlsx` bằng openpyxl** (kiểm `row_dimensions[r].hidden`, `font.strike` ở cột C/D để loại dòng ẩn/gạch). Không đọc qua markdown/export Google Sheets (mất trạng thái ẩn). — Why: sổ tay Lensie mục 6, 2e (bản PO export mất 12 dòng ẩn).
3. Event Name trong spec là ô gộp → dòng trống kế thừa event dòng trên (evaluator làm `ev = cell or cur`).
4. Đối chiếu code trước khi chạy: grep `EventName.swift` + `Track*.swift` để biết event nào có call site. Event 0 call site = "không bắn" (bằng chứng code) — phải ghi rõ loại bằng chứng, không trộn với "đã chạy thật". — Why: sổ tay Lensie 7b.

## B. Chạy thật, không giả
5. **KHÔNG mock / fake / sửa response / nhờ dev stub kết quả gen.** Chạy thật trên máy thật. — Why: sổ tay Lensie mục 6; 05/10 đã bỏ đề xuất stub vì vi phạm.
6. **Contract test simulator (`scripts/run-event-tests.sh`) chỉ là gate cho dev, không dùng để chấm.** Journey chấm trên máy thật. — Why: 05/10.
7. Case chỉ xảy ra khi lỗi thật (gen lỗi, timeout 180 s, trả lời bằng chữ): chưa gặp thì ghi "Chưa test được", không ép. — Why: 05/10. Ngoại lệ hợp lệ: **mất mạng thật** bằng Airplane Mode qua `SettingsNetworkDriver` (21/10 dùng cho `library_load_fail`, `gen_tray_retry_click`) — luôn `defer { net.ensureOn() }`.
8. Sửa code app chỉ tối thiểu để đo được (patch sink 1 dòng), backup bản gốc vào `app-backup/`, **báo user rõ ràng**. — Why: 21/10.

## C. Bắt event
9. **Dùng sink JSONL + mốc ETSTEP** (xem `capture-mechanism.md`). — Why: 21/10 chạy ổn, chấm tự động được theo bước, không phụ thuộc console.
10. **ĐÃ CHỐT (user 21/10): event tracking dùng file sink JSONL làm cách test chính thức** — thay luật cũ "chạy trên Xcode, xem Console, cấm devicectl --console" (sổ tay 06/10). Không cần hỏi lại đầu lượt; Xcode Console chỉ dùng để soi thêm khi cần debug.
11. Log XCUITest có **`\r` cuối dòng** → `tr -d '\r'` khi lấy ETSINK, nếu không `cp` lỗi tên file. — Why: 21/10 lượt test02 đầu.
12. `devicectl copy from` **chỉ nhận thư mục nguồn** (`--source Documents`), không nhận file. — Why: 21/10.
13. `ETSTEP` in **ngay trước** thao tác; luôn có `step("end")`. Log có thể in trùng dòng → dedupe.

## D. Phân loại kết quả (dòng = event × param)
| Status | Khi nào | Ví dụ thật |
|---|---|---|
| **PASS** | Bắn đúng 1 lần/thao tác ở mọi bước kỳ vọng, có param, đúng giá trị kỳ vọng, ∈ Allowed, đúng type | 28 dòng 21/10 |
| **FAIL – không bắn** | Đã vào đúng màn/thao tác mà sink không có event (hoặc code 0 call site) | — (Library 21/10 không có) |
| **FAIL – sai param** | Có bắn nhưng thiếu param / giá trị ngoài Allowed / sai kỳ vọng / sai type / rỗng khi phải có / bắn >1 lần | `feature_name=i2v` vs `I2V`; `destination=library` vs `generating`; `error_code=""` |
| **CHECK (Cần xác nhận)** | App bắn nhất quán nhưng spec mơ hồ về NGHĨA giá trị → hỏi PO, không tự chấm Fail | `item_count`=20 (trang đầu) vs "Số kết quả đã tạo" |
| **NA (Chưa test)** | Không dựng được điều kiện kích hoạt → ghi rõ cần dựng gì | `library_start_creating_click` cần Library trống |
| Chưa có tính năng | PO xác nhận tính năng hoãn | (Lensie: Enhance/RemoveBG) |

14. **Lệch hoa/thường trong giá trị = FAIL** (spec Allowed là danh sách đóng). Ghi kèm nguồn code (`EventValue.swift:24`). — Why: 21/10.
15. **Hành vi app khác spec nhưng code có comment cố ý** → vẫn FAIL theo spec, ghi "dev cố ý, cần PO chốt sửa app hay sửa spec". — Why: 21/10 `gen_tray_click` (`GenerationStatusView.swift:349-354`).
16. Quyết định PO hợp thức hoá **giá trị**, không hợp thức hoá **tên param**. Sai tên param vẫn FAIL. — Why: sổ tay Lensie 2e.
17. **Luôn rà bắn trùng**: 1 thao tác = đúng 1 event; >1 thì đối chiếu timestamp với bước trước khi kết luận "bắn thừa". Kiểm thêm **bước không được bắn** (`EXPECT_NONE`, vd chạm lại filter đang chọn). — Why: sổ tay Lensie mục 6 (`view_t2i_screen` 1 chạm 2 event).
18. `time_to_action`: so với dwell đo được = `ts(_complete) − ts(_view gần nhất)`, ngưỡng 1500 ms. 21/10 lệch ≤1 ms.
19. Trước khi báo FAIL: chạy lại ≥1 lần loại flaky; lỗi script (locator/timing) → sửa script chạy lại, không báo bug. Lượt hỏng do script → chuyển vào `runs/invalid/`, evaluator không đọc. — Why: 21/10 (2 lượt invalid).
20. Report luôn tách: số dòng **chạy thật có event** vs **kết luận từ code**; ghi mẫu số khi nói tỉ lệ cover. — Why: sổ tay Lensie 7b ("đừng nói đã chạy 94%").

## E. Sub / paywall / credit
21. **Kiểm trạng thái sub TRƯỚC case cần Generate** (`test00_probeSubscriptionState` → `SUBSTATE|premium|expired`). — Why: 21/10 lượt test02 đầu mất **15 phút**: sub hết hạn → Generate bung paywall, kịch bản vẫn chờ khay "Ready" tới timeout.
22. **`i2v.startGenerate()` vẫn trả `true` khi Generate bung paywall** → sau Generate luôn `guard !i2v.common.paywall.exists else { note("abort", …); return }`. Xác nhận trong sink: `quota_check decision=block_no_sub`. — Why: 21/10.
23. Sub: ưu tiên **email verify** (user 05/10: "không cần mua sub, login bằng email verify → tự động nhận sub"). Không có email / email hết slot → mua Sandbox **Weekly**, user nhập mật khẩu. — Why: 05/10 + 21/10.
24. **Màn paywall ở case không phải mua: automation chỉ bấm nút thoát.** Chạm toạ độ chỉ khi bước ngay trước đã xác minh màn bằng element cụ thể; nhận diện paywall bằng chữ (`per week/month/year`, `Cancel anytime`, `Restore purchases`). — Why: sổ tay Lensie (bấm trúng CTA mua 3 lần 11/09, 19/09, 21/09).
25. Thứ tự: chạy hết case **không cần sub/credit** trước (test01), gom case cần Generate (test02/03) ngay sau khi có sub. Mỗi lượt full tốn ~2 video + 1 ảnh credit.
26. Xoá thật dữ liệu: chỉ xoá **đúng 1 ô mới nhất vừa tạo trong lượt** (test04: lọc Photo → ô đầu). Case xoá khác → Delete rồi **Cancel** trên dialog. Muốn làm trống Library (cho `start_creating`) → hỏi user trước.

## F. Bẫy XCUITest màn Library / khay
27. Nút `···` (label `More`) **ẩn khi vào chế độ chọn** → chốt `frame` các ô TRƯỚC khi bấm Select, rồi chạm toạ độ `(midX−45, midY+70)`. — Why: 21/10 lượt test01 đầu không chọn được ô.
28. Bấm theo toạ độ tuyệt đối đã chốt frame (`tapText`): neo vào element sẽ throw nếu element biến mất giữa chừng.
29. `moreButtons` lọc theo vùng lưới (`minY > 140`, `maxY < 740`) và sort theo (y, x) để thứ tự ổn định.
30. Khay tạo nền: text chứa `Creating` (đang chạy) / `Ready` (xong — chờ tới 420 s) / `Couldn` (lỗi). Ô đang tạo ở lưới có label kết thúc `%`.
31. `Delete` của multi-select ở thanh dưới → `tapText("Delete", minY: 600)` để không trúng menu khác.
32. Sau khi sang Settings (Airplane) dùng `app.activate()`, không `launch()`.

## G. Thời lượng (để báo user / lên kế hoạch)
| Lượt (21/10) | Nội dung | Thời gian máy |
|---|---|---:|
| test01 | Duyệt, lọc, chọn nhiều, huỷ xoá, mở ô ảnh/chat | 4′40″ |
| test02 | Khay + ô đang tạo (1 video + 1 ảnh, chờ render) | 9′16″ |
| test03 | Offline: Library lỗi + Retry khay | 3′26″ |
| test04 | Xoá thật 1 ảnh | 1′14″ |
- Tổng chấm được ~18,6 phút + 30–60 s/lượt cài & khởi động. Cả phiên 21/10 ~55 phút (viết kịch bản + build 4 lần ~15′, 2 lượt hỏng 19,6′, mua sub ~3′, chấm + report ~5′).
- Chạy lại cả 4 lượt khi máy còn sub, không sửa gì: **~20–22 phút**.
- Lấy thời lượng từ log: `grep -m1 -o 'Executed 1 test.* in [0-9.]* ' runs/*.log`.

## H. Quy trình làm việc
33. Chạy liên tục, không chờ nhắc; chỉ dừng khi cần người (mật khẩu Sandbox, mở khoá máy). Trong lúc lượt dài chạy nền, viết evaluator/report song song. — Why: working-rules + 21/10.
34. Kết thúc: report HTML artifact (private) + xlsx kết quả + handoff + cập nhật memory. Không commit/push.
35. Báo user đầy đủ "Bạn cần biết": cách bắt event khác sổ tay, đã sửa code app gì, tốn bao nhiêu credit/lượt mua, đã xoá dữ liệu gì, trạng thái mạng/máy sau lượt.

## Câu hỏi còn mở
- PO chốt: `I2V` vs `i2v`; `gen_tray_click` running → `library` hay `generating`; nghĩa `item_count`.
- Có cho phép làm trống Library / dùng Apple ID Sandbox mới để test `library_start_creating_click`?
