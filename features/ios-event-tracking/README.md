# Genius iOS — Event tracking autotest (event/param kiểm trên iPhone thật)

Gói kiến thức để AI agent chạy lại automation event tracking cho app **Genius iOS** (IIP055, bản 2.9.0) — hoặc màn khác của Genius — mà không phải mò lại từ đầu. Đọc kèm `../../common/working-rules.md`.

## Phạm vi
- Kiểm **event analytics + param** app bắn ra khi automation (XCUITest) thao tác thật trên iPhone thật, đối chiếu với spec xlsx.
- Mỗi dòng spec = 1 cặp (event, param) → chấm PASS / FAIL / CHECK / NA (xem `rules-and-lessons.md`).
- KHÔNG mock, KHÔNG fake response, KHÔNG suy từ code rồi ghi như đã chạy.

## File spec / dữ liệu nguồn
| File | Là gì |
|---|---|
| `~/Downloads/genius-eventtracking-library.xlsx` | Spec Library + gen_tray (1 sheet `Trang tính1`, 34 dòng param, 14 event). Cột: A Screen · B Screen Code · C Event Name (ô gộp → trống thì kế thừa dòng trên) · D Trigger · E Timing · F Event Param · G Value Source · H Allowed Values (`a\|b\|c`) · I Value Type · J Description · K Note |
| `~/Downloads/IIP055-Genius-IOS-2.9.0/Genius-event-tracking.xlsx` | Spec tổng, nhiều sheet: splash, check sub, onboarding, paywall, home, enhance, I2I, I2V, Try-on, World Cup Looks/Video, Service Quality, W2A, Event Hub, Rating, Logout, Motion Control, Restore, Remove Object, New Subcripton flow, **AI chat** (66 dòng), **Library** (36 dòng), Create. Cùng format cột A–K (+ cột Status/Note tuỳ sheet) |
| `~/Downloads/IIP055-Genius-IOS-2.9.0/plans/event-spec-v2.9.0.json` | Spec máy đọc được bản 2.9.0: 12 screen, 70 event (chat, chat_viewer, library, gen_tray, tools, home, bottom_bar, vibes_review, *_result_ld…). Có `tracking_object` (TrackLibrary, TrackGenTray…) + `platform_file_hint` |
| `~/Downloads/IIP055-Genius-IOS-2.9.0/events.json` | Spec cũ (campaign "In-App Feature-Flow Analytics", 2026-07-01) — dùng cho `scripts/run-event-tests.sh` (contract test simulator) qua `.event-tracking.json` |
| `~/Downloads/IIP055-Genius-IOS-2.9.0/event-screen-map.json` | Map screen → `screen_id`, `tracking_object`, `feature_name_value`, file view |
| `~/Downloads/IIP055-Genius-IOS-2.9.0/plans/reports/event-audit-v2.9.0.md` | Audit wiring tĩnh 02/10: 69/70 event có call site; `chat_report_dialog_click` không có |

Code tracking: `iosApp/Core/Tracking/` — `AnalyticsTracker.swift` (wrapper, sink), `EventName.swift`, `EventValue.swift`, `Track*.swift` (`final class Track* { static let shared; func logEvent*() }`).

## Đã chạy tới đâu
| Ngày | Màn | Kết quả | Ghi chú |
|---|---|---|---|
| 05/10/2026 | AI Chat (sheet `AI chat`, 26 event, 74 TC) | **Chưa chấm được event nào** | Bắt log `Apero_Key` bằng `devicectl --console` chạy được (27–28 event), nhưng XCUITest báo `Timed out while enabling automation mode` 2/2 lần (máy khoá / chưa bật Enable UI Automation). Source lúc đó `~/Downloads/IIP055-Genius-IOS-main` — thư mục plan `261005-1507-ai-chat-event-tracking-automation` hiện **không còn trên máy** (chưa xác minh đã chuyển đi đâu) |
| 21/10/2026 | Library (910) + khay tạo nền gen_tray | **28 PASS · 4 FAIL · 1 CHECK · 1 NA** (34 dòng, chạy được 33) | iPhone 12 black. Cách bắt event: sink JSONL (xem `capture-mechanism.md`) |

### Chi tiết 21/10 (Library + gen_tray)
- FAIL:
  1. `gen_tray_view.feature_name` + `gen_tray_retry_click.feature_name` = `i2v` (spec Allowed `I2V`) — nguồn `EventValue.swift:24` (`EVENT_VALUE_FEATURE_NAME_I2V = "i2v"`). Luồng ảnh gửi đúng `I2I`.
  2. `gen_tray_click.destination` khi khay đang chạy = `library` (spec: running → `generating`). Dev cố ý (`GenerationStatusView.swift:349-354`) → cần PO chốt.
  3. `gen_tray_retry_click.error_code` rỗng cả lúc offline lẫn online — app không giữ mã lỗi lượt hỏng.
- CHECK: `library_load_success.item_count` = số ô trang đầu (≤20, `CreationLibrary.swift:96/189`), spec ghi "Số kết quả đã tạo" → PO chốt nghĩa.
- NA: `library_start_creating_click` — chỉ hiện khi Library trống; account test có lịch sử. Cần xoá hết kết quả hoặc Apple ID Sandbox mới (hỏi user trước).
- Kiểm thêm đạt: mỗi thao tác bắn đúng 1 lần; chạm lại bộ lọc đang chọn không bắn; `library_complete.time_to_action` lệch ≤1 ms so với dwell đo được.

## Report / artifact
- Report HTML (private): https://claude.ai/artifact/XioYNy5T8GHsuAwE5z5UpJ
- Plan + toàn bộ bằng chứng: `~/Downloads/IIP055-Genius-IOS-2.9.0/plans/261021-0944-genius-290-event-tracking-library-autotest/`
  - `EventTracking_Genius_2.9.0_Library_Result_2026-10-21.xlsx` (spec + 3 cột kết quả + sheet `Event log`)
  - `report-summary.json`, `genius-290-event-tracking-library-report.html`, `evidence/*.jpg`, `runs/` (log, jsonl, xcresult, shots), `runs/invalid/` (lượt hỏng)
  - `handoff-event-tracking-library-trang-thai-va-cach-chay-tiep.md`
  - `app-backup/AnalyticsTracker.swift` (bản gốc trước patch), `app-backup/project.pbxproj.backup-261021`
- Sổ tay nguyên tắc gốc (Lensie 2.1.0, cùng chủ): https://claude.ai/artifact/HF32AiR3wtrjf2KpwN6DpZ — user gửi kèm cả 05/10 và 21/10 làm "plan chạy event tracking".

## Đọc file nào khi nào
| Tình huống | Đọc |
|---|---|
| Bắt đầu bất kỳ lượt event tracking nào | `rules-and-lessons.md` (BẮT BUỘC) → file này |
| Chuẩn bị máy, build, sub | `setup-environment.md` |
| Hiểu/sửa cách lấy event từ máy | `capture-mechanism.md` |
| Viết suite màn mới, chạy, chấm, report, bàn giao | `run-and-report.md` + `templates/` |

## templates/ (bản copy, nguồn vẫn ở repo)
| File | Nguồn | Dùng để |
|---|---|---|
| `Genius290EventTrackingLibraryUITests.swift` | `iosAppUITests/` | Mẫu suite: in `ETSINK`/`ETSTEP`/`ETNOTE`, 4 test (duyệt/lọc/chọn · khay+ô đang tạo · offline+Retry · xoá thật) |
| `Genius290Support.swift` | `iosAppUITests/` | Helper `G290` (reachMain, openTab, pause, waitUntil, visibleTexts, anyLabeled) — suite phụ thuộc |
| `EventSinkClient.swift` | `iosAppUITests/` | Client sink kiểu simulator (đọc thẳng `/tmp`) — KHÔNG dùng được trên máy thật, để tham khảo |
| `evaluate_event_tracking_library.py` | plan dir | Chấm: ghép event ↔ bước theo cửa sổ thời gian, xuất xlsx + summary json |
| `build_event_tracking_library_report.py` | plan dir | Dựng report HTML (ảnh base64) từ summary json + `evidence/` |
| `run-genius-290-event-tracking-library.sh` | `scripts/` | Chạy 1 test method + kéo sink về |
| `run-genius-290-device-suite.sh` | `scripts/` | Runner chung: build-for-testing / test-without-building, retry khi máy khoá, export ảnh |
| `analytics-tracker-sink-tilde-expand.patch` | diff | Patch 1 dòng `AnalyticsTracker.swift` cho sink nhận `~/…` |

Suite còn phụ thuộc file có sẵn trong repo (không copy): `I2IJourneyDriver.swift`, `I2VJourneyDriver.swift`, `PhotoPickerAutomator`, `SettingsNetworkDriver.swift` (bật/tắt Airplane qua Settings), `EvidenceSnapshot.swift` (`snap()`), `Genius290SubscriptionLibraryUITests.swift` (`test00_probeSubscriptionState`), `OnboardingToPaywallJourneyUITests.swift` (mua có người nhập mật khẩu).
