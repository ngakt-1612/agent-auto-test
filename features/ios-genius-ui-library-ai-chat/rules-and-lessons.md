# Luật & bài học — Genius iOS 2.9.0 autotest (ĐỌC TRƯỚC KHI CHẠY)

Định dạng: **Luật** — Why (ngày / nguồn). Nguồn: transcript 38b17dd6 (18–21/10), handoff 2 đợt, memory, `common/working-rules.md`.

## A. Luật từ user (đã sửa / đã chốt — không tự đảo)
1. **Chỉ chạy TC của spec mới.** Plan/report/skill/bộ TC cũ (gen ảnh 51 TC, gen video 62 TC, 6 artifact, skill `ios-xcuitest-device-automation`, `ios-video-generate-automation`) = công cụ & kinh nghiệm, áp vào bước của TC 2.9.0 cần gen ảnh/video. — Why: 18/10 13:10 chạy lại toàn bộ suite gen cũ, mất ~1 h máy; user: "tôi không yêu cầu bạn chạy lại toàn bộ testcase gen ảnh, gen video… là công cụ, kiến thức để bạn áp dụng" (memory reference-material-is-toolkit-not-scope).
2. **Tự chạy tiếp, không chờ nhắc.** Chain mọi bước trong script nền (chạy → sửa test → chạy lại → report). Chỉ dừng ở bước cần người (mật khẩu sandbox, mở khoá/khởi động lại máy, Trust chứng chỉ), nói rõ 1 lần cần làm gì. — Why: 18/10 user gõ "chạy tiếp đi" ~8 lần rồi "auto chạy tiếp ko cần tôi nhắc", "auto đi, ko cần tôi prompt"; 20/10 vẫn phải nhắc ~6 lần → vẫn còn lỗi này, phải sửa.
3. **Bị chặn case nào thì để sau, chạy hết case chạy được, rồi report + đóng gói + lưu tiến trình.** — Why: 18/10 15:05 "tự auto test tiếp không cần tôi reply, nếu bị block ở case nào để case đó sau…".
4. **Report phải có testcase + status + ảnh bằng chứng, so với Figma.** — Why: 18/10 "viết report thì hãy kèm testcase, status+ ảnh bằng chứng"; "cần phải so sánh UI với design figma nữa nhé".
5. **Không để N/A vì "thận trọng".** Được phép: xoá hết Library để test trống; chờ gói hết hạn thật; Motion Control = chip `Motion` ở Home; tự viết bước còn thiếu. — Why: 18/10 14:11 "sao có tới tận 18 TC N/A" → giảm còn 6.
6. **Agent tự tắt/bật Airplane + Wi-Fi qua app Settings**, không nhờ user. — Why: 18/10 "bạn có thể tự tắt airplane mode và bật wifi ko cần tôi thao tác tay".
7. **Không đổi Remote Config, không mock/proxy/bơm lỗi/làm chậm server.** Case lỗi/timeout server chỉ chấm khi gặp thật. — Why: 18/10 "bỏ các case giả lỗi, làm chậm server, đổi gía trị remote config".
8. **Chạy lại theo đúng hướng dẫn user cho case mơ hồ:** LIB03-018 vào tab Library rồi mới tắt mạng; BG02-007 đứng ở Generating tới khi Result hiện (rồi Edit More); BG01-015 mất mạng khi tạo nền → khay hoàn tất HOẶC lỗi có thử lại đều PASS. — Why: 19/10 14:19 user chỉ định 9 case chạy lại.
9. **Huỷ gói sandbox:** Manage Subscription → chạm gói → Manage subscription → chọn lý do → xác nhận (tester nhập mật khẩu). — Why: 19/10 15:14 user hướng dẫn.
10. **Mua gói/topup: test mở sẵn màn mua, tester bấm + nhập mật khẩu.** Không để user chạm máy khi test đang chạy — hẹn đúng lúc màn mua mở. — Why: 20/10 18:15 user "tôi sẽ mua topup" giữa lúc chạy → hộp thoại "You're all set" làm hỏng 2 nhóm.
11. **"Lưu tiến trình, mai chạy tiếp" = dừng mọi queue (kể cả queue sắp huỷ gói khi không có người), dọn máy (Photos Full Access, Reduce Transparency off), ghi handoff + memory + zip.** — Why: 20/10 19:00.
12. Không commit/push; không đưa mật khẩu/secret vào report/handoff. — Why: memory no-push; common rules.

## B. Thiết bị & runner
13. **Không gỡ app sau khi mua gói** (trừ case cần, xếp cuối). — Why: cùng Apple ID gói tự khôi phục khi cài lại (đo LIB04-001 18/10); và restore kéo về hàng trăm kết quả cũ.
14. **Không sửa file script đang chạy** (bash đọc dần từng dòng). Muốn đổi → viết queue mới chờ queue cũ xong (`until grep -q "<mốc>" out; do sleep 30; done; pkill -f old`). Append sau điểm đang đọc thì an toàn. — Why: 18/10 sửa runner khi lib-delete2 đang chạy → hỏng lượt.
15. **Env gate `TEST_RUNNER_<GATE>=1` phải đặt trước `xcodebuild`** (runner tự prefix `TEST_RUNNER_`; trong test đọc `RUN_G290_*`). — Why: thiếu prefix thì app/test không thấy env.
16. **Mac thức:** `caffeinate -dimsu -w <pid>`; không gập nắp. iPhone Auto-Lock = Never. — Why: 18/10 user hỏi "máy tính tôi sleep thì bạn vẫn chạy chứ" — Mac ngủ là hỏng lượt.
17. **Case offline luôn trả mạng ở `defer`; chặn cú bấm có thể crash trước defer.** Airplane Mode làm iOS không xác minh được chứng chỉ dev → mọi suite sau lỗi "Developer App Certificate is not trusted". — Why: 18/10 một cú bấm hỏng bỏ qua defer; 20/10 17:44 máy không chạy test được nữa.
18. Runner treo "hung before establishing connection" → gỡ xctrunner không ăn, phải **khởi động lại iPhone**. — Why: 18/10 16:27 → dừng vòng chờ hết hạn.
19. Đặt `G290_DD` (derived data) về scratchpad phiên hiện tại — mặc định trong runner trỏ scratchpad phiên 38b17dd6 cũ (chưa xác minh còn tồn tại).

## C. Gói, lượt (credit), server
20. **Paywall khi Generate ≠ hết gói.** Có thể là hết **20 lượt/ngày** → kiểm `SUBSTATE` (nút `home-upgrade-cta`) + huy hiệu lượt trước khi kết luận. — Why: 18–19/10 nhiều lượt tưởng hết gói.
21. **Sandbox Yearly tự gia hạn nhiều lần; sống 1–6 giờ.** Case "gói hết hạn" phải probe 10 phút/lần tới `SUBSTATE|expired`; lượt chạy khi gói tự gia hạn = sai tiền đề → loại bằng note. — Why: 19/10 LIB04-002/003 có 3 lượt không hợp lệ; PASS lúc hết hạn thật 12:05.
22. **Lượt là tài nguyên:** gom nhiều TC vào 1 lần gửi/1 lượt tạo; chạy nhóm 0 credit trước, mua gói, rồi nhóm tốn lượt; nhóm "dùng hết lượt" (481) chạy **cuối** ngày. Topup sandbox = 1 lượt/lần mua. — Why: 18/10 hết lượt ngày → 11 case blocked; 20/10 Chat 20 lượt/ngày.
23. **Server AI Chat chậm/lỗi (≥180 s, "Couldn't reply"):** mỗi test `waitIdle` (7 phút), chấm theo `lastOutcome`; lỗi server → **CHECK**, không FAIL; tạm dừng nhóm tốn lượt khi server lỗi liên tục, thử lại 1 lượt rẻ trước khi chạy tiếp. — Why: 20/10 từ ~15:50.
24. 237 (topup) chỉ chào 1 lần/ngày → test chuỗi paywall phải là lượt gửi đầu tiên trong ngày của máy không gói. — Why: spec §4, TC-CH03-005.
25. Free user có topup: Generate vẫn qua paywall 2 lần rồi mới chạy bằng topup (quan sát, đã báo PO). — Why: LIB04-004 19/10.
26. Thứ tự tiền đề phá trạng thái xếp cuối: xoá Library → huỷ gói/chờ hết hạn → gỡ app (mất lịch sử Chat, hỏi lại quyền Photos). — Why: plan Luật 5; handoff AI Chat bước 5.

## D. Viết test / đo
27. **Không tin cú bấm — đọc lại giá trị** rồi mới in `VERDICT`. — Why: skill ios-xcuitest-device-automation.
28. **Chọn element theo nhãn từ 1 snapshot**; element neo toạ độ sẽ re-resolve lúc tap và throw → ghim toạ độ tuyệt đối từ frame đã đọc. — Why: 18/10 nhiều lỗi stale element (card label, Tap to use, visibleTexts index).
29. Chip/Cancel/Delete là staticText → `G290.anyLabeled`; "not hittable" → chạm toạ độ.
30. **Chờ bằng `G290.pause` / `waitUntil`** (poll `waitForExistence`), không `Thread.sleep`.
31. **Library: không đếm ô** (tải theo trang); đo xoá bằng dấu vân 16×16 trên 6–8 ô. — Why: 19/10 lưới 6×6 không phân biệt chân dung → verdict sai.
32. Đo màu "đang chọn" bằng **tỉ lệ pixel tím**, không trung bình màu. — Why: viên kính xám kéo trung bình về xám.
33. **Chat vuốt chọn = giữ 0,5 s + kéo chậm 150 pt/s.** — Why: 20/10 vuốt 140 pt nhanh/chậm sai kiểu → FAIL giả CH07-002; probe `test13_probeSwipeGesture` chốt kiểu này.
34. Bấm Delete 3 lần trong hộp thoại: `tap(withNumberOfTaps: 3, numberOfTouches: 1)` trên chính nút. — Why: chạm toạ độ 3 lần → chạm 2–3 rơi xuống lưới mở viewer.
35. Ô có tray `%` lẫn ô đang tạo → lọc `maxY < 660`. Ảnh xong 10–15 s → case "đang tạo" dùng video hoặc kiểm ngay khi rời màn, mỗi case 1 lượt riêng.
36. Mỗi `snap("TC-XXX — mô tả")` đặt tên chứa TC ID (report tìm ảnh theo tên). `continueAfterFailure = true`; mỗi suite có `XCTSkipUnless(env gate)`.
37. Trước khi chạy test probe dump cây accessibility (`dump()` in `DUMP|tag|type|label|id|value|frame`) cho màn mới — 0 credit. — Why: 2.9.0 không có id; Chat là ảnh + tap gesture.
38. TC ID trong test/notes phải khớp xlsx — kiểm sau khi sinh. — Why: 20/10 lệch 5 mã CH02 phải sửa cả notes + test.

## E. Chấm & phân loại
39. **Xem ảnh bằng chứng trước khi chốt FAIL/N/A**; FAIL thì đọc code app tìm nguyên nhân + `file:line` (vd `I2IGeneratingView.swift:24`, `LibraryViewModel.onOpen`, `ChatScreen.swift:112`, `HomeTabBanner.swift:74`).
40. Phân loại: **PASS** · **FAIL** (app khác spec, có ảnh + nguyên nhân) · **MISMATCH / Lệch spec** (code cố ý khác spec hoặc Figma giống app → PO chốt) · **CHECK / Cần xem** (server lỗi, không đo được chắc, chủ ý code chờ PO) · **NA** (bị chặn: hết lượt, chờ gói, cần Apple ID khác, tính năng không hiện) · **TESTERR** (lỗi phía test → sửa test, chạy lại, không báo bug).
41. **Lượt sau thắng lượt trước, nhưng NA không đè kết quả thật.** `verdict-notes.json` đè tất cả (có thể ghim `run` để chọn ảnh). Khi case đã có lượt thật → **xoá note NA cũ** (note đè kết quả chạy). — Why: 19/10 notes cũ đè PASS mới.
42. Lượt chạy sai tiền đề (gói tự gia hạn, hết quota, popup hệ thống) → không tính, ghi lý do trong note.
43. Kết quả ghép từ 2 lượt được, nếu ghi rõ (vd REG02-001: bước lưu PASS ở lượt trước). Test tự chấm dựa chữ sai (vd tìm "Top-up") → chấm lại từ ảnh/log, ghi note.
44. Spec tiếng Việt, app tiếng Anh → chấm theo **nghĩa** (Ambiguity C1); ghi chuỗi thực tế vào actual.

## F. Bàn giao
45. Mỗi lần dừng: cập nhật handoff (`Kết quả · Trạng thái máy · Việc tiếp có lệnh · Luật rút ra`), memory `genius-v290-testcase-scope.md`, republish report cùng URL, zip lại. Trả lời "thời gian test" bằng số đo từ log (AI Chat 20/10: ~4 h, máy chạy thật ~2,3 h / 55 lượt).
