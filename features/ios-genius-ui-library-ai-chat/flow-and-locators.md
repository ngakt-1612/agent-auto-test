# Luồng & locator — Genius iOS 2.9.0 (đo trên iPhone 12, iOS 26.5.2)

App launch: `I2IJourneyDriver.launchApp()` (ép `-AppleLanguages (en) -AppleLocale en_US` → mọi label tiếng Anh). Vào luồng chính: `G290.reachMain(app)` (lo onboarding/paywall/popup; thấy `tabBars.buttons["Library"]` là đủ).
Nguyên tắc: nhiều control là **Text + tap gesture** (staticText, không phải button) → dùng `G290.anyLabeled(app, "X")`. Đọc label từ **1 snapshot** (`G290.visibleTexts`, `app.snapshot()`), không duyệt element theo index (màn đổi → "element index N" biến mất → lỗi cả test).

## Accessibility id đã gắn vào app (chỉ Home/I2I/I2V/Paywall/Onboarding)
`home-style-card` / `home-style-card-video` · `style-grid-card(-video)` · `home-upgrade-cta` (chỉ hiện với user free → dùng làm SUBSTATE) · `onboarding-cta` · `paywall-screen` (root PaywallView) · `i2i-gallery-option` / `i2i-camera-option` / `i2i-generate-cta` / `i2i-result-screen` / `i2i-result-close` / `i2i-result-share` / `i2i-result-report` · `i2v-gallery-option` / `i2v-camera-option` / `i2v-generate-cta` / `i2v-upload-back` / `i2v-generating-screen` / `i2v-generating-back` / `i2v-generating-failed` / `i2v-result-screen` / `i2v-result-close|share|report` / `i2v-result-player` (value playing/paused).
Paywall đóng: nút X của RevenueCatUI không id/label → `i2i.dismissPaywall()` = chạm toạ độ chuẩn hoá (0.9, 0.1).

## Update UI (UI01–UI04, REG01)
| Màn | Locator / nhãn | Ghi chú |
|---|---|---|
| Thanh tab | `G290.tabLabels(app)` (sắp theo minX). Thực tế: `Home · Chat · Create · Reel · Library` (spec bỏ Reel → FAIL UI01-001) | Mục đang chọn: `G290.purpleFraction(of:)` (đo tỉ lệ pixel tím, không dùng trung bình màu — viên kính xám kéo về xám) |
| Thanh tab nổi | Che nửa dưới card Home → driver chỉ chạm phần nhìn thấy (`coveredTop()`) | |
| Home | chip `For You` (chỉ hiện sau khi user đã chạm 1 style), `New`, `Trending`, `Motion`; mục "You May Have Missed", "Try Now" | **See All = chạm tiêu đề mục** (staticText minX<60 ngay trên hàng `home-style-card`), không có chữ "See All". Card video: chạm chip `Trending` trước |
| Motion | chip `Motion` → reel; nhiều nút `Tap to use` → chỉ bấm nút đang trong màn (predicate `label == 'Tap to use'`, frame trên màn) | Motion Control = chip Motion ở Home (user 18/10) |
| Banner tab New | Đo tự đổi banner trong 16 s (code nhịp 4 s) | FAIL UI04-001 |
| Setting | Home vuốt xuống → `app.buttons["Setting"]`; mở xong thấy staticText `Rate us`, `Language` | Hàng `My Balance`, `Manage Subscription`, `Web Subscription`: chạm lần đầu sau khi mở Setting hay không ăn → chạm lại ≤3 lần; số My Balance tải chậm (spinner) — chờ có số |
| Create | staticText `Create`, công cụ `Remove Object` · `Restore` · `Enhance` · Try-on | Remove Object phải tô vùng; Restore Generating không có nút back |
| Upload i2i | `Tap to upload`, `i2i-gallery-option` → PHPicker (`PhotoPickerAutomator`), `i2i-generate-cta` | |
| Generating | `Building your visual`, `Creating your masterpiece`, `Usually takes 10–15 seconds` (cả video — thực tế ~2 phút) | 2.9.0 bỏ popup `Keep waiting / Leave Anyway`; rời màn = chạy nền |
| Vuốt mép | `press(forDuration:0.1, thenDragTo:…, withVelocity:.slow, thenHoldForDuration:0.1)` | i2i Generating không rời được (BG01-003) |

## Tạo nền / khay / ô đang tạo (BG01–BG03)
- Khay trên thanh tab: text chứa `Creating` / `Ready — tap to view` / `Couldn't finish that one` (+ nút thử lại). Chạm khay luôn mở **Library**.
- Ô đang tạo trong Library: staticText `label.hasSuffix("%")`, `minY > 140 && maxY < 660` (loại % của khay). Chạm ô đang tạo → mở lại Generating.
- Ảnh i2i xong ~10–15 s, video ~2 phút → case "đang tạo" kiểm **ngay sau khi rời màn**, mỗi case 1 lượt tạo riêng (dùng video cho case cần thời gian).
- Lượt nền xong: mở Result qua khay `Ready —…`; Library viewer **không có Edit More**.

## Library (LIB01–LIB04)
| Phần | Locator | Ghi chú |
|---|---|---|
| Tiêu đề | `staticTexts["Library"]` | |
| Lọc | chip `All` · `Photo` · `Video` · `Conversation` (staticText/button → `anyLabeled`) | spec All·Image·Video → MISMATCH |
| Chọn | `Select` → đếm `selected`; `Cancel` | Ô đang tạo không chọn được |
| Ô | nút `More` (···) mỗi ô: `buttons` label == "More", `minY > 140 && maxY < 760` | Nút ··· chồng vùng chạm ô → thử element tap / góc nút; kiểm menu `Delete` sau mỗi lần. Menu không còn `Duplicate` |
| Nhấn giữ ô | `press(forDuration: 0.5)` cách tâm ··· (−45, +70) → menu `Delete` | `.contextMenu` (`LibraryScreen.swift:364`) — 0,5 s ăn |
| Xoá | hộp thoại chứa `Delete?` → `Delete` / `Cancel`; toast `Deleted` | Bấm 3 lần: `alertButton.tap(withNumberOfTaps: 3, numberOfTouches: 1)` (chạm toạ độ 3 lần → chạm 2–3 rơi xuống lưới) |
| Trống | `Nothing here yet.` + `Start creating` (→ tab Chat khi Chat bật) | |
| Offline | `You're offline · Retry` thay cả lưới | FAIL LIB03-017 |
| Hình học ô | `G290.libraryCellRect(i)`: 3 cột, x=26+122·col, y=215+160·row, 90×70 | |
| Đo xoá | dấu vân **16×16** trên 6–8 ô, so lệch 0/1/2 ô (6×6 không tách được chân dung na ná) | Không đếm số ô — Library tải theo trang (~27 ô) |
| Kết quả Chat | Ô **cuộc trò chuyện** (lọc `Conversation`, 💬 số kết quả + tên) | Không xoá ô ảnh ở lọc Photo để test case Chat |

## AI Chat (901) — KHÔNG có accessibility id
| Phần | Locator |
|---|---|
| Vào | `G290.openTab(app, "Chat")`; tiêu đề thực tế "AI Chat" (canh trái) |
| Trạng thái trống | staticText `What's on your mind?` + chip `Make a birthday card from my photo` · `Turn my photo into a film` · `Try a black-and-white look` |
| Ô nhập | `app.textFields` (placeholder value "What's on your mind?"). Khi 902 mở, ô soạn khung chat **vẫn trong cây**: ô của 902 có `frame.minX < 50`, ô khung chat `minX >= 50`; 902 mở ⇔ `app.tabBars.buttons.count == 0` |
| Nút | dấu cộng = `app.images["plus"]`; gửi = `app.images["arrow.up"]` (ảnh + tap gesture, không có trạng thái enabled → đo bằng hành vi) |
| Đang tạo | `app.images["sparkles"]` hoặc text bắt đầu `Replying` |
| Kết quả | hàng staticText `Save` · `Share` · `Regenerate` cùng hàng (|ΔmidY|<6); vùng ảnh = ngay trên `Save` (x=24, y=Save.minY−230, 220×200); `Report` |
| Lỗi | text chứa `Couldn` ("Couldn't reply"), `longer than expected` ("This is taking longer than expected." + Retry), `No internet`; giới hạn: "Up to 1000 characters" |
| Menu | `buttons["More"]` → `New conversation` → hộp thoại "Start a new conversation? Your images and videos stay in Library." |
| Chọn để sửa | thanh staticText `Editing this` (chỉ tính khi `tabBars.buttons.count > 0`); bỏ chọn = `images["xmark"]` ở dưới (minY>600 / minX>300) |
| Hết lượt (481) | text `Daily limit reached` · "Your creations renew tomorrow. Need more today?" · nút `Get more` / `Maybe later` (`anyLabeled`) |
| Màn topup | text `Top-up creations` / `Choose a Package`, nút `Purchase` (tester nhập mật khẩu) |

### Thao tác Chat (đã dò trên máy)
- **Vuốt chọn kết quả:** `a = coord(x: f.minX + 50, y: f.midY)`; `a.press(forDuration: 0.5, thenDragTo: a.withOffset(dx: 150, dy: 0), withVelocity: XCUIGestureVelocity(150), thenHoldForDuration: 0.1)`. Ngưỡng = 1/5 chiều rộng (~78 pt): kéo 35 pt → không chọn; 140–150 pt → `Editing this` + bàn phím mở. **Kéo nhanh = chạm → mở 902.**
- **Gõ chữ:** chạm ô nhập tới khi có bàn phím + `hasKeyboardFocus` (`focus()`), chạm ở `normalizedOffset (0.97, 0.5)` để con trỏ về cuối; gõ khi chưa focus → XCUITest lỗi.
- **Xoá chữ:** chạm sát mép phải rồi `typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: n+5))`, đọc lại tới khi rỗng / bằng placeholder.
- **Ẩn bàn phím:** chạm (0.5, 0.12).
- **Đóng 902:** kéo xuống > 1/4 màn rồi thả (`press 0.1 → drag dy +0.4, .fast`); kéo ~1/8 → vẫn mở.
- **Chờ:** `waitIdle(420)` = chờ hết `sparkles`/`Replying` (tối đa 7 phút); `lastOutcome()` = so maxY của `Regenerate` cuối vs text lỗi cuối → "result" | "error" | "text". Server lỗi → verdict CHECK, không FAIL.
- **Huy hiệu lượt:** Home vuốt xuống, nút ở `minY < 120 && minX > 200` có số.

## Paywall chain Chat (user chưa mua gói)
Gửi → **236** (`paywall-screen`) → đóng → **238** last chance ("Limited Offer 50% OFF") → đóng → **237** topup ("Still not ready to subscribe? · Includes 1 AI creation · One-time purchase only") → đóng → về Chat, chữ còn nguyên.
- 237 chỉ chào **1 lần/ngày** theo spec → `test01_paywallChain` phải là lượt gửi đầu tiên trong ngày của máy không gói.
- Phân biệt bước: sau mỗi `dismissPaywall()` xem `paywall.exists` + text (`Still not ready` = topup). Màn topup thật **không có chữ "Top-up"** (từng chấm sai CH03-005).
- Ví topup ≥1: đóng 236→238 thì yêu cầu tự gửi, không chào 237. Free user có topup bấm Generate (i2i) cũng gặp paywall 2 lần rồi chạy bằng topup.

## Dải "Try the newest vibes" (VB01–VB03)
Chỉ hiện khi CMS có category `vibes` (không có → ẩn, demoMock không dùng) → 14 TC N/A ở đợt 20/10.

## Hệ thống / Settings app (`com.apple.Preferences`)
- Mạng: `SettingsNetworkDriver().setAirplaneMode(true/false)`, `setWiFi`, `ensureOn()`; luôn trả mạng ở `defer`.
- Quyền Photos: `SettingsPhotosDriver(appName: "Genius") { app }.setAccess("None" | "Full Access")`.
- Reduce Transparency: Settings › Accessibility › Display & Text Size › switch `Reduce Transparency` (value "1"/"0").
- Popup quyền: `SystemPermissionAlertHandler.tapButton("Allow Full Access" | "Allow" | "OK", timeout:)` (qua springboard).
- Sheet Apple (mua, huỷ gói, mật khẩu) **ngoài cây accessibility** của app → test đứng chờ (≤300 s), chụp định kỳ; tester thao tác.
- Huỷ gói sandbox: Home › `Setting` › `Manage Subscription` › gói Yearly › `Manage subscription` › lý do (`Too expensive`) › tester nhập mật khẩu + `Cancel Subscription` → `Confirm` (`Genius290CancelSandboxSubUITests`).

## Đo thay vì nhìn
`G290.purpleFraction` / `redFraction` (Delete bật) / `colorFraction` · `regionSignature` + `signatureDistance` (<~12 = cùng ảnh; ô nhập kính: lệch >6 khi cuộn = trong suốt, <6 khi Reduce Transparency) · `PHAsset.fetchAssets(with: nil).count` (Save về Photos) · đếm toast theo lần hiện (lên → tắt = 1).
