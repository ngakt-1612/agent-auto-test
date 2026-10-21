# AI Chat (Genius 2.9.0) — kiến thức test riêng

Spec: Confluence pageId 323393416 §3–11 (AI Chat, Try the newest vibes, paywall Chat 236/238/237). TC: `~/Downloads/TC_Genius_v2.9.0_AI_Chat.xlsx` — 105 TC, sinh bằng `templates/gen_ai_chat_testcases.py` (dữ liệu: `templates/ai-chat-spec-cases-105-tc.json`), cùng khuôn 13 cột với bộ UpdateUI/Library. Plan/run gốc: `~/Downloads/IIP055-Genius-IOS-2.9.0/plans/261020-1505-genius-290-ai-chat-testcase-automation/`. Handoff lúc dừng: `handoff-ai-chat-20-10-snapshot.md`.

## 1. Skill & công cụ dùng cho AI Chat
| Bước | Skill / công cụ |
|---|---|
| Đọc spec | Confluence MCP (trang 323393416 + trang con BE 323393421) |
| Sinh TC | `anthropic-skills:qa-testcase-generator` (Mode G) → script `gen_ai_chat_testcases.py` xuất xlsx 13 cột (xem `testcase-generation-rules.md`) |
| Hạ tầng test | XCUITest máy thật + `Genius290Support.swift` (helper chung) + `SettingsNetworkDriver.swift` (Airplane/Wi-Fi) — kế thừa `../ios-genius-gen-image-video/` (PHPicker, popup quyền, mua sandbox) |
| Chạy | `run-genius-290-device-suite.sh` (build / chạy method), queue nền `run-genius-290-ai-chat-nosub-queue.sh` |
| Report | `build-genius-290-autotest-report.py` + `genius-290-report-template.html` → Artifact (publish cùng URL) |
| Skill gói kinh nghiệm này | `automation-test-agent` (thư mục này) |

## 2. Nhóm TC (105)
| Nhóm | Số | Nội dung |
|---|---|---|
| CH01 | 11 | Vào Chat, UI trống, chip gợi ý, lịch sử, cuộc trò chuyện mới, cuộn, mạng |
| CH02 | 21 | Ô nhập, nút gửi, độ dài, dấu cộng, gửi tạo/sửa ảnh-video, yêu cầu không tạo, quyền, rời màn |
| CH03 | 12 | Chặn người chưa mua (236→238→237), mua trong chuỗi, trừ lượt, hết lượt (481) |
| CH04 | 5 | Tách việc ("one thing at a time") |
| CH05 | 5 | Mạng, nội dung, quá thời gian, tạo lỗi |
| CH06 | 12 | Kết quả: xem/lưu/chia sẻ/tạo lại, Library, mạng ở 902 |
| CH07 | 10 | Vuốt chọn, sửa tiếp, tệp đã xoá, chưa có kết quả |
| CH08 | 12 | Màn 902 (từ Chat/Library), bàn phím, giữ phần soạn, chặn, ô nhập kính |
| VB01–03 | 15 | Dải "Try the newest vibes": hiển thị, chọn ảnh, xem lại, điền sẵn, chặn |
| REG02 | 2 | E2E + regression i2i |

## 3. Test class ↔ gate ↔ TC
Gate env: `TEST_RUNNER_RUN_G290_CHAT_SUB` (đang có gói) · `TEST_RUNNER_RUN_G290_CHAT_NOSUB` (chưa mua/hết hạn) · `TEST_RUNNER_RUN_G290_CHAT_PROBE` (dump cây, 0 credit).

`Genius290AiChatNoSubUITests` (chạy khi CHƯA có gói):
| Method | TC |
|---|---|
| test01_paywallChain | CH03-001…005 |
| test02_emptyStateAndComposer | CH01-001/002/003/006, CH02-001…011 |
| test03_vibesStrip | CH08-007, VB01-002 |
| test04_paywallFrom902 | CH03-006, CH08-007 |
| test05_topupWalletSendsAfterChain | CH03-006/007 (cần ≥1 lượt topup) |
| test06_buySubOn236 | CH03-007 (tester mua gói trên 236) |

`Genius290AiChatWithSubUITests` (có gói Yearly, tốn lượt):
| Method | TC chính |
|---|---|
| test01_firstSendAndProbe | CH02-016, CH03-011 |
| test02_resultAndViewer | CH01-007, CH06-001…008, CH08-003/004/006/011/012 |
| test03_editFlows | CH02-021/023, CH04-001, CH06-002/009, CH07-001…008, CH08-005 |
| test04_networkAttachLibraryNewConversation | CH01-008…010, CH02-017/020, CH05-001, CH06-010, CH08-004/008 |
| test05_swipeSelect · test06_sendForSelected | CH07-002…008 · CH07-004 |
| test07_editFromViewer · test08_regenerate · test09_helloTextOnly | CH08-005 · CH06-009 · CH02-021, CH06-002 |
| test10_oneThingAtATime · test22_oneThingImageThenVideoAndTyping | CH04-001/002 · CH04-003/004 |
| test11 · test12 · test14 | CH02-017/020 · CH01-008/009, CH06-010, CH08-004 · CH01-008 |
| test13_probeSwipeGesture | dò cử chỉ vuốt (0 TC) |
| test15_e2eLibraryAndDeleted · test21_e2eOnly · test23_i2iRegression | CH06-010/011, CH07-010, REG02-001 · REG02-001 · REG02-002 |
| test16_keepDraftWhenViewing · test17_offlineMidGenerationAndRetry | CH08-009/010 · CH05-002/003 |
| test18_videoContentAndOneThing · test19_scrollAndChatTabAgain | CH02-018, CH03-012, CH04-005, CH05-005 · CH01-004/011 |
| test24_glassComposer · test27_photoPermissionDenied · test28_reduceTransparency | CH08-001 · CH02-015, CH08-002 · CH08-002 |
| test25_outOfCredits · test26_outOfCreditDialogButtons · test29_getMoreOpensTopup | CH03-008…010 (chạy CUỐI ngày) |
| test30_restoreDeviceSettings | trả Photos Full Access + Reduce Transparency off (luôn chạy sau case đổi setting) |

## 4. Thứ tự chạy (lượt là tài nguyên — 20 lượt/ngày với gói)
1. Probe 0 credit (`Genius290AiChatProbeUITests/test01_dumpChatAndVibes`) cho màn mới.
2. Nhóm NoSub test01–04 (0 lượt) khi máy chưa có gói.
3. Mua gói (tester nhập mật khẩu) → `SUB_PROBE` → nhóm WithSub gom nhiều TC/1 lần gửi.
4. Hết lượt: test29 → test25/26.
5. Cần chưa-mua lại: queue `run-genius-290-ai-chat-nosub-queue.sh` (huỷ gói — tester nhập mật khẩu + Cancel → Confirm; chờ hết hạn) → NoSub test04/05/06.
6. Cuối cùng (gỡ app, mất lịch sử Chat): CH02-014 (quyền Photos chưa hỏi), CH06-012 (kết quả chưa tải + mất mạng).

## 5. Hành vi app & cách điều khiển (đo 20/10, iPhone 12 iOS 26.5.2)
- Màn 901 không có accessibility id: nút cộng/gửi = ảnh `plus` / `arrow.up`; `sparkles`; hàng nút kết quả = chữ Save/Share/Regenerate; thanh chọn "Editing this". Tiêu đề thực tế "AI Chat" canh trái (spec: "Chat" ở giữa → lệch spec CH01-001).
- Gõ chữ: chạm ô nhập tới khi có bàn phím (`focus()`); xoá bằng chạm sát mép phải rồi delete theo lô.
- 902 mở ⇔ `app.tabBars.buttons.count == 0`; ô soạn khung chat vẫn còn trong cây — ô của 902 có `frame.minX < 50`. "Editing this" chỉ tính khi thanh tab còn hiện.
- **Vuốt chọn kết quả = `press(forDuration: 0.5, thenDragTo: +150pt, withVelocity: 150)`**; kéo nhanh bị nhận là chạm → mở 902 (từng gây FAIL giả CH07-002).
- Paywall chưa mua: Gửi → 236 (`paywall-screen`) → đóng → 238 "Limited Offer 50% OFF" → đóng → 237 topup ("Still not ready to subscribe? · Includes 1 AI creation · One-time purchase only") → đóng → về Chat, chữ còn nguyên.
- Free user có topup: vẫn qua paywall 2 lần rồi mới chạy. Hết lượt: "Daily limit reached" (Get more / Maybe later); Get more → topup.
- Kết quả Chat trong Library = ô **cuộc trò chuyện** (lọc Conversation), không phải ô ảnh — đừng xoá ô ở lọc Photo khi test case Chat.
- Thư viện dấu cộng chỉ có ảnh, không video (`ChatScreen.swift:112` `.galleryPicker(matching: .images)`) → các case video FAIL/NA theo.
- Dải vibes không hiện khi CMS chưa có category vibes (`HomeVibe.demoMock` không dùng) → VB* NA, VB01-002 FAIL.
- Server AI Chat chậm/lỗi (≥180 s, "Couldn't reply"): mỗi test `waitIdle` 7 phút, chấm theo `lastOutcome`; lỗi server → CHECK ("Cần xem"), không FAIL; server lỗi liên tục thì dừng nhóm tốn lượt, thử 1 lượt rẻ trước khi chạy lại.
- Mất mạng hay làm máy báo "Developer App Certificate is not trusted" → tester mở Settings › VPN & Device Management.

## 6. Kết quả chốt 20/10 19:05 — 97/105
57 PASS · 11 FAIL · 3 lệch spec · 6 cần xem · 20 N/A · 8 chưa chạy. Report https://claude.ai/artifact/9pNbWtWa65uqxjv2K22CFP · zip `~/Downloads/Genius-2.9.0-autotest-AI-Chat-261020.zip`. Thời gian: ~4 h, máy chạy thật ~2,3 h / 55 lượt.
- FAIL: CH03-005 (topup chào 2 lần/ngày) · CH01-006 (chip không mở bàn phím) · CH02-008/013/019 (không kèm video) · CH04-001…004 (không tách yêu cầu gộp, thiếu "I do one thing at a time") · CH03-009 (hết lượt xoá chữ đang gõ) · VB01-002.
- Lệch spec: CH01-001 · CH06-010/011 (Library gộp kết quả Chat thành ô cuộc trò chuyện).
- Cần xem: CH05-004 · CH06-007 (không thấy toast lưu) · CH05-003 · CH07-004 · CH08-010 · CH02-021.

Kết quả từng TC (đối chiếu report artifact 21/10): `ai-chat-ket-qua-105-tc-2026-10-20.tsv` (tc_id · verdict · title · actual).

**8 chưa chạy** (cần dựng tiền đề): CH01-005 (Start creating khi Library trống — đã PASS ở suite Library TC-LIB01-003) · CH02-014, CH02-015 (quyền Photos chưa hỏi/bị từ chối — gỡ app) · CH03-006, CH03-007 (chưa mua gói còn topup / mua trong chuỗi 236 — máy đang có gói) · CH06-012 (kết quả chưa tải + mất mạng) · CH08-002 (Reduce Transparency) · CH08-007 (chưa mua gói gửi từ 902).

**20 N/A** — đọc kỹ, không phải tất cả là "không áp dụng":
- 14 VB* — dải vibes không hiện (chặn bởi VB01-002 FAIL); chạy lại khi CMS có category `vibes`.
- CH02-012 — phụ thuộc CH02-008 (không chọn được video).
- CH07-010 — không dựng được tiền đề (Library không xoá riêng kết quả Chat, xem CH06-011).
- **Lỗi phía test → phải chạy lại, không giữ N/A:** CH07-006 (màn chỉ hiện 1 kết quả, viết lại bước cuộn để có 2 kết quả) · CH07-007 (picker chọn theo toạ độ không chọn được ảnh) · CH03-010 (Get more chưa mở topup — chạy lại khi hết lượt) · CH03-012 (badge/My Balance tải chậm, không đọc được lượt sau video).
- Bài học: lỗi do script/timing là **lỗi đo** (xem `common/working-rules.md` §5) — sửa test và chạy lại trước khi đóng report, đừng để lẫn vào N/A.

## 7. Việc còn lại (8 TC + chạy lại "cần xem")
Theo §4: sửa + chạy lại 4 N/A lỗi phía test (CH07-006 cuộn, CH07-007 picker, CH03-010, CH03-012) → chạy lại test06/16/17/27/28/09/02 khi có lượt → test29 → test26 → queue NoSub (test04/05/06) → gỡ app (CH02-014, CH06-012) → dựng lại report:
```bash
export G290_OUT=$PWD/plans/261020-1505-genius-290-ai-chat-testcase-automation/runs
scripts/run-genius-290-device-suite.sh build
G290_SUITE_TITLE="AI Chat — 105 TC spec 2.9.0" python3 scripts/build-genius-290-autotest-report.py $G290_OUT \
  plans/261018-1110-genius-290-automation-ui-image-video/figma-frames \
  plans/261020-1505-genius-290-ai-chat-testcase-automation/genius-290-ai-chat-autotest-report.html
```
Trước khi chạy tiếp: `SUB_PROBE` kiểm trạng thái máy (21/10 máy đã dùng cho event tracking; 20/10 còn gói Yearly, chưa huỷ). Đặt lại `G290_DD` (thư mục build) về scratchpad phiên mới.
