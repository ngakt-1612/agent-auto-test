# Genius iOS 2.9.0 — Autotest Update UI + Library + AI Chat (XCUITest, iPhone thật)

Gói kiến thức để agent chạy lại / chạy tiếp autotest Genius iOS 2.9.0. Đọc `../../common/working-rules.md` trước, rồi file này.

## Phạm vi
| Mục | Giá trị |
|---|---|
| Spec | Confluence pageId **323393416** — "IIP055.1.20 - Update UI, AI Chat & Library" (trang con BE spec: 323393421 = IIP055.1.20.1) |
| App | Genius (IIP055), bundle `aiphotogenerator.aifaceeditor.aivideogenerator.aibeauty`, team `KS4Z2R52B4`, env `.prod` (credit thật) |
| Source | `/Users/kieunga/Downloads/IIP055-Genius-IOS-2.9.0` (KHÔNG phải git) |
| Máy | iPhone 12 black, iOS 26.5.2 (xem `setup-environment.md`) |
| Figma | `/Users/kieunga/Downloads/IIP055-Genius.pdf` (14 trang → 109 frame PNG trong `plans/261018-1110-…/figma-frames/`) |
| Đợt 1 (18–19/10) | Update UI + Library — 84 TC |
| Đợt 2 (20/10) | AI Chat + dải "Try the newest vibes" — 105 TC (spec §3–11) |
| Ngoài file này | Event tracking Library (21/10) → `features/ios-event-tracking/` ; RC testcase 2.9.0 → `~/Downloads/IIP055_TC_RemoteConfig_v2.9.0.xlsx` (không chạy auto) |

## File TC
| File | Sheet | TC |
|---|---|---|
| `/Users/kieunga/Downloads/TC_Genius_v2.9.0_UpdateUI_Library.xlsx` | `TC_UpdateUI_Library` · Ambiguity (U1–U2, L1–L8) · Automation Setup · Summary | 84 (70 Auto, 14 Auto + setup) |
| `/Users/kieunga/Downloads/TC_Genius_v2.9.0_AI_Chat.xlsx` | `TC_AI_Chat` · Ambiguity (C1–C11) · Automation Setup · Summary | 105 (81 Auto, 24 Auto + setup) |

Cột PASS/FAIL (I) trong 2 file xlsx **để trống** — kết quả nằm ở report HTML + `verdict-notes.json` (không thấy file xlsx kết quả riêng — chưa xác minh có cần điền không; hỏi user nếu yêu cầu).

### Prefix TC ID
| Prefix | Nhóm | Số TC |
|---|---|---|
| TC-UI01 | Thanh tab & Create | 7 |
| TC-UI02 | Home (301) | 1 |
| TC-UI03 | Upload / Generating / Result / Settings | 5 |
| TC-UI04 | Banner Home (tab New…) | 2 |
| TC-LIB01 | Library bố cục / trống | 6 |
| TC-LIB02 | Lọc All/Image/Video | 6 |
| TC-LIB03 | Chọn, menu ···, xoá, offline | 19 |
| TC-LIB04 | Lưu theo tài khoản gói (restore, hết hạn, topup) | 4 |
| TC-BG01/02/03 | Tạo ở nền: rời màn, khay, ô đang tạo | 16 / 7 / 7 |
| TC-REG01 | Regression Create tools, My Balance | 4 |
| TC-CH01 | Chat: lối vào & trạng thái trống (901) | 11 |
| TC-CH02 | Thanh soạn & gửi (kèm ảnh, 1000 ký tự, câu chào) | 21 |
| TC-CH03 | Paywall chain 236→238→237, Daily limit 481, topup | 12 |
| TC-CH04 | "Một lần gửi một việc" (tách yêu cầu gộp) | 5 |
| TC-CH05 | Lỗi / timeout 180 s / mất mạng / vi phạm nội dung | 5 |
| TC-CH06 | Kết quả: Save/Share/Regenerate/Report, 902, Library | 12 |
| TC-CH07 | Vuốt chọn kết quả, "Editing this" | 10 |
| TC-CH08 | Ô nhập kính, màn xem 902, Reduce Transparency | 12 |
| TC-VB01/02/03 | Dải "Try the newest vibes" (Home) | 5 / 6 / 4 |
| TC-REG02 | Regression E2E Chat + i2i | 2 |

## Kết quả chốt
| Đợt | Kết quả | Report |
|---|---|---|
| Update UI + Library (chốt 19/10 18:10) | 84/84 · **74 PASS · 7 FAIL · 3 lệch spec · 0 cần xem · 0 N/A** | https://claude.ai/artifact/SitqmU4GuuCYQqe1aW7c6F (private) |
| AI Chat (dừng 20/10 19:05, user: "mai chạy tiếp") | 97/105 · **57 PASS · 11 FAIL · 3 lệch spec · 6 cần xem · 20 N/A · 8 chưa chạy** | https://claude.ai/artifact/9pNbWtWa65uqxjv2K22CFP (private) |

FAIL UI/Library: UI01-001 (còn tab Reel) · UI01-007 (reel Motion kèm thanh tab) · UI03-001 (ảnh không phủ khung upload) · UI04-001 (tab New không tự đổi banner, nghi `HomeTabBanner.swift:74`) · LIB03-017 (offline mất lưới) · BG01-003 (`.navigationBarHidden(true)` ở `I2IGeneratingView.swift:24` chặn vuốt mép) · BG03-003 (`LibraryViewModel.onOpen` không chặn khi `isSelecting`).
Lệch spec: LIB01-001, LIB01-002, LIB02-002 (lọc `All · Photo · Video · Conversation` vs spec `All · Image · Video`; Figma giống app).

FAIL AI Chat: CH03-005 (topup chào 2 lần/ngày) · CH01-006 (chip không mở bàn phím) · CH02-008/013/019 (không kèm video — `ChatScreen.swift:112 matching: .images`) · CH04-001..004 (không tách yêu cầu gộp) · CH03-009 (Daily limit xoá chữ đang gõ) · VB01-002 (CMS chưa có category `vibes` → dải ẩn; `HomeVibe.demoMock` không dùng).
Lệch spec: CH01-001 (tiêu đề "AI Chat" canh trái), CH06-010/011 (Library gộp kết quả Chat thành ô Conversation).
Còn lại AI Chat: xem `run-and-report.md` §Việc tiếp và handoff.

## Artifact / gói đã có
| Thứ | Đường dẫn |
|---|---|
| Zip UI+Library | `~/Downloads/Genius-2.9.0-autotest-UpdateUI-Library-261019.zip` (bản cuối; bản 261018 cũ hơn) |
| Zip AI Chat | `~/Downloads/Genius-2.9.0-autotest-AI-Chat-261020.zip` |
| Handoff UI+Library | `<source>/plans/261018-1110-genius-290-automation-ui-image-video/handoff-genius-290-autotest-trang-thai-va-cach-chay-tiep.md` |
| Handoff AI Chat | `<source>/plans/261020-1505-genius-290-ai-chat-testcase-automation/handoff-ai-chat-autotest-trang-thai-va-cach-chay-tiep.md` |
| Cách làm (trình bày hội đồng) | `~/Downloads/Autotest Genius 2.9.0 — cách làm.html` ; `<source>/plans/reports/genius-290-automation-skills-and-methods-report.html` |
| Flow chart agent | `~/Downloads/genius-autotest-agent-flow.html` |
| Report HTML local | `<source>/plans/261018-…/genius-290-autotest-report.html` ; `<source>/plans/261020-…/genius-290-ai-chat-autotest-report.html` |
| Danh sách id test gắn vào app | `<source>/plans/reports/fullstack-261018-1120-genius-290-test-identifiers-report.md` |

## Source quan trọng (`<source>` = `/Users/kieunga/Downloads/IIP055-Genius-IOS-2.9.0`)
- Test: `<source>/iosAppUITests/Genius290*.swift` (+ driver port từ 2.6.0: `I2IJourneyDriver`, `I2VJourneyDriver`, `PhotoPickerAutomator`, `PhotoLibrarySeeder`, `SettingsNetworkDriver` (có `SettingsPhotosDriver`), `SystemPermissionAlertHandler`, `EvidenceSnapshot`, `OnboardingToPaywallJourneyUITests`).
- Script: `<source>/scripts/run-genius-290-device-suite.sh`, `run-genius-290-*-queue.sh`, `build-genius-290-autotest-report.py`, `genius-290-report-template.html`, `add-test-files.rb`.
- Plan UI+Library: `<source>/plans/261018-1110-genius-290-automation-ui-image-video/` (plan.md, spec-cases.json, figma-map.json, verdict-notes.json, report-summary.json, runs/, evidence/, figma-frames/, tools/*.swift, app-backup/).
- Plan AI Chat: `<source>/plans/261020-1505-genius-290-ai-chat-testcase-automation/` (gen_ai_chat_testcases.py, spec-cases.json, verdict-notes.json, runs/).
- Bản sao plan: `/Users/kieunga/plans/261018-1110-genius-290-automation-ui-image-video/plan.md`.
- App CLAUDE.md: `<source>/CLAUDE.md` (MVVM, AppRouter, RC keys `RemoteConfigKeys.swift`, env `AppConstants.swift`).

## Khi nào đọc file nào
| Việc | Đọc |
|---|---|
| Sinh TC mới / thêm TC cho spec này | `testcase-generation-rules.md` + `templates/gen_ai_chat_testcases.py` |
| Máy mới / build lỗi / máy không chạy test | `setup-environment.md` |
| Viết / sửa test, tìm element | `flow-and-locators.md` + `templates/Genius290Support.swift` |
| TRƯỚC MỌI LẦN CHẠY | `rules-and-lessons.md` (bắt buộc) |
| Chạy, dựng report, đóng gói, bàn giao | `run-and-report.md` |
| **Bất cứ việc gì về AI Chat** (skill dùng, nhóm TC, test method ↔ TC, thứ tự chạy, hành vi app, kết quả, việc còn lại) | `ai-chat-testing-knowledge.md` |
| Chạy tiếp AI Chat dở dang | `ai-chat-testing-knowledge.md` §7 + `handoff-ai-chat-20-10-snapshot.md` + `run-and-report.md` §Việc tiếp |

## Templates (bản sao, gốc trong `<source>`)
`templates/`: `Genius290Support.swift` (helper G290) · `Genius290AiChatNoSubUITests.swift` (mẫu suite Chat có gate, paywall chain) · `Genius290LibraryReadOnlyUITests.swift` (mẫu suite đơn giản) · `SettingsNetworkDriver.swift` (Airplane/Wi-Fi/quyền Photos qua app Settings) · `run-genius-290-device-suite.sh` (runner) · `run-genius-290-day2-queue.sh` (queue có mua gói + chờ hết hạn) · `run-genius-290-ai-chat-nosub-queue.sh` (queue huỷ gói → chờ → chạy) · `build-genius-290-autotest-report.py` + `genius-290-report-template.html` · `gen_ai_chat_testcases.py` (sinh xlsx 13 cột + spec-cases.json).
