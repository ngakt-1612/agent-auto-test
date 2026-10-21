# Bàn giao — Autotest Genius iOS 2.9.0 · AI Chat (105 TC)

Cập nhật: 2026-10-20 19:05 · Máy: iPhone 12 black (iOS 26.5.2) · Source `~/Downloads/IIP055-Genius-IOS-2.9.0` (.prod)

## Kết quả (chốt 20/10 19:05)
97/105 có kết quả · **57 PASS · 11 FAIL · 3 lệch spec · 6 cần xem · 20 N/A · 8 chưa chạy**
- Report: https://claude.ai/artifact/9pNbWtWa65uqxjv2K22CFP (private)
- TC: `~/Downloads/TC_Genius_v2.9.0_AI_Chat.xlsx` (sinh bằng `gen_ai_chat_testcases.py`, cùng khuôn 13 cột bản UpdateUI/Library)
- Gói: `~/Downloads/Genius-2.9.0-autotest-AI-Chat-261020.zip`
- FAIL: CH03-005 (topup chào 2 lần/ngày) · CH01-006 (chip không mở bàn phím) · CH02-008/013/019 (không kèm video — `ChatScreen.swift:112`) · CH04-001/002/003/004 (không tách yêu cầu gộp, không có "I do one thing at a time") · CH03-009 (hết lượt: chữ đang gõ bị xoá) · VB01-002 (dải vibes không hiện khi CMS chưa có category, `HomeVibe.demoMock` không dùng)
- Lệch spec: CH01-001 (tiêu đề "AI Chat" canh trái) · CH06-010/011 (Library gộp kết quả Chat thành ô cuộc trò chuyện → không xoá riêng được)
- Cần xem: CH05-004 (bắt được timeout thật) · CH06-007 (lưu được, không thấy toast) · CH05-003 · CH07-004 · CH08-010 · CH02-021 (server lỗi / chưa đo lượt)

## Trạng thái máy lúc dừng
- **Đang có gói Yearly** (mua lại 15:28). Đã mua topup ~18:30. Lượt hôm nay gần hết.
- Quyền Photos của Genius = Full Access, Reduce Transparency = tắt (đã dọn bằng `test30_restoreDeviceSettings`).
- Hàng chờ huỷ gói (`scripts/run-genius-290-ai-chat-nosub-queue.sh`) **đã dừng, chưa huỷ gói**.

## Việc tiếp (ngày mai)
1. Build: `export G290_OUT=$PWD/plans/261020-1505-genius-290-ai-chat-testcase-automation/runs; scripts/run-genius-290-device-suite.sh build`
2. Có lượt mới → chạy lại các case "cần xem"/hỏng do máy (gate `RUN_G290_CHAT_SUB`, class `Genius290AiChatWithSubUITests`):
   `test06_sendForSelected` (CH07-004) · `test16_keepDraftWhenViewing` (CH08-009/010) · `test17_offlineMidGenerationAndRetry` (CH05-002/003) · `test27_photoPermissionDenied` (CH02-015) · `test28_reduceTransparency` (CH08-002) · `test09_helloTextOnly` (CH02-021) · `test02_resultAndViewer` (CH06-007 toast)
3. Hết lượt → `test29_getMoreOpensTopup` (CH03-010) rồi `test26_outOfCreditDialogButtons` (CH03-009 bằng nút Maybe later).
4. Cần "chưa mua gói": `scripts/run-genius-290-ai-chat-nosub-queue.sh` (huỷ gói — tester nhập mật khẩu + Cancel Subscription → Confirm trên sheet Apple; chờ hết hạn; chạy `Genius290AiChatNoSubUITests/test04` CH08-007, `test05` CH03-006 cần ≥1 lượt topup, `test06` CH03-007 tester mua gói trên 236).
5. Cuối cùng (gỡ app, mất lịch sử Chat): CH02-014 (quyền Photos chưa hỏi), CH06-012 (kết quả chưa tải + mất mạng).
6. Dựng lại report: `G290_SUITE_TITLE="AI Chat — 105 TC spec 2.9.0" python3 scripts/build-genius-290-autotest-report.py $G290_OUT plans/261018-1110-genius-290-automation-ui-image-video/figma-frames plans/261020-1505-genius-290-ai-chat-testcase-automation/genius-290-ai-chat-autotest-report.html`, sửa `<title>` thành "Genius 2.9.0 AI Chat Autotest", publish lại cùng file.

## Luật rút ra
- Màn Chat không có accessibility id: nút dấu cộng/gửi là ảnh `plus` / `arrow.up`; hàng nút là chữ Save/Share/Regenerate; thanh chọn "Editing this".
- Vuốt chọn kết quả: **giữ 0,5 s rồi kéo chậm** (`press(forDuration:0.5, thenDragTo:+150, withVelocity:150)`); kéo nhanh bị nhận là chạm → mở 902.
- Khi 902 mở, ô soạn khung chat vẫn nằm trong cây: ô của 902 bắt đầu ở x<50; "Editing this" chỉ tính khi thanh tab còn hiện.
- Gõ chữ: phải chạm ô nhập tới khi có bàn phím (`focus()`), xoá bằng chạm sát mép phải rồi delete theo lô.
- Server AI Chat chiều 20/10 hay quá 180 s / "Couldn't reply" → mỗi test chờ app rảnh (`waitIdle`, 7 phút) và chấm theo câu trả lời cuối (`lastOutcome`); lỗi server ghi "Cần xem".
- Free user có topup: Generate vẫn qua paywall 2 lần rồi mới chạy. Hết lượt: hộp thoại "Daily limit reached" (Get more / Maybe later).
- Kết quả Chat ở Library = ô cuộc trò chuyện (lọc Conversation), không phải ô ảnh — đừng xoá ô ở lọc Photo để thử case Chat.
- Máy hay báo "Developer App Certificate is not trusted" khi mất mạng → tester mở Settings › VPN & Device Management.
