# Flow & locator — Gen Image (I2I) / Gen Video (I2V)

Nguồn: `iosAppUITests/*` source 2.9.0, report identifier 2.9.0, skill video. Nhãn đo trên iOS 26.5.2,
app khoá locale `en` (`-AppleLanguages (en) -AppleLocale en_US`). Popup **hệ thống** theo ngôn ngữ thiết bị.

## 1. Accessibility id (đã gắn trong source 2.9.0)

| id | Màn / element | Ghi chú |
|---|---|---|
| `home-style-card` / `home-style-card-video` | card style ở Home (For You, hero, Trending/New/Motion grid) | `accessibilityValue` = styleType (`IMAGE`/`VIDEO`/`NO_TYPE`) để kiểm kê |
| `style-grid-card` / `-video` | card trong See All | |
| `home-upgrade-cta` | nút Pro/Upgrade ở Home | chỉ hiện với user free ⇒ dùng đo SUBSTATE |
| `onboarding-cta` | nút onboarding | |
| `paywall-screen` | root PaywallView (RevenueCat + fallback) | nút đóng RevenueCat không id/label ⇒ bấm toạ độ góc trên phải |
| `i2i-gallery-option` · `i2i-camera-option` | nguồn ảnh ở Upload I2I | style nhiều ảnh dùng `VerticalDialog` chung: nút `Gallery`/`Camera` theo **label**, không id |
| `i2i-generate-cta` | nút Generate I2I | |
| `i2i-result-screen` · `-close` · `-share` · `-report` | Result I2I | root `.contain` |
| `i2v-gallery-option` · `i2v-camera-option` · `i2v-generate-cta` · `i2v-upload-back` | Upload Photo I2V | |
| `i2v-generating-screen` · `i2v-generating-back` · `i2v-generating-failed` | Loading I2V / màn failed | failed `.contain` ⇒ `Try Again`/`Go Back` vẫn bấm được |
| `i2v-result-screen` · `-close` · `-share` · `-report` | Result I2V | |
| `i2v-result-player` | khung video | value `playing`/`paused`; **bắt buộc** `.accessibilityElement(children: .contain)` |

Slot trống ở Upload: `app.buttons` label `BEGINSWITH "Upload Image"` (đếm slot = mốc kiểm chứng chọn ảnh).
2.9.0 chưa có id: Generating mới ("Building your visual"), khay chạy nền, Library ⇒ chọn theo text.

## 2. Flow Gen Image (I2I)

```
launch → reachHome() [ATT/notification popup, onboarding-cta, xác thực email, paywall xmark]
→ tap home-style-card → Upload (slot "Upload Image…")
→ chạm slot → (lần đầu) popup quyền Photos → i2i-gallery-option → PHPicker → chọn ảnh
→ (style 2 ảnh: lặp tới khi i2i-generate-cta enabled) → Generate
→ Loading "Creating Your Image…" + % → i2i-result-screen (Edit More · Save · Share · Report)
```

- Popup Photos 3 nút: `"Limit Access…"`, `"Allow Full Access"`, `"Don’t Allow"` (nháy cong U+2019).
- Dialog của app sau khi từ chối: `Allow Library` / `Allow Camera` / `Not Now` — có thể hiện **chậm 13–17s**.
- Camera (`UIImagePickerController`, in-process): `Take Picture`, `Use Photo`, `Retake`, **`Dismiss`** (không phải Cancel), `Camera Chooser`, `Flash`.
- Thời gian gen ảnh: 2.6.0 12–60s (timeout 240s); 2.9.0 ~10–15s ("Usually takes 10–15 seconds").
- Lỗi: `"Something went wrong while enhancing your photo. Please try again."` → `Try Again` (tối đa 2 lượt).
- Back giữa Loading (2.6.0): hộp `"Cancel generation"` → `Keep Waiting` / `Leave Anyway`. **2.9.0 bỏ hộp
  này** — rời màn ⇒ job chạy nền, hiện khay "Creating…/Ready —/Couldn…" và ô đang tạo trong Library.
- 2.9.0 Generating: tiêu đề `Building your visual`, chữ `NN%`, viên `Usually takes 10–15 seconds`;
  Result có dải `Try another style` trên hàng `Edit More · Save`. Không có nút back ⇒ vuốt mép (đang FAIL BG01-003).
- Toast: `Save successfully` · `Save image failed` · `Shared successfully` · `Share failed` ·
  `No internet connection. Please try again.`
- Report: mở Mail composer; huỷ ⇒ iOS hỏi `Delete Draft` (hoặc "Xoá bản nháp") — phải dọn, nếu không
  case sau "Back không về Home" (sai).

## 3. Flow Gen Video (I2V)

```
launch → reachHome → cuộn Home tìm home-style-card-video (đáy Home!) — dự phòng deep link geniusopenapp:///i2v
→ Upload Photo (i2v-gallery-option / i2v-camera-option) → pickPhotosUntilReady() (có style cần 2 ảnh)
→ i2v-generate-cta → i2v-generating-screen (NN%) → i2v-result-screen (player autoplay, Save, Share, Report, Close)
```

- Entry point: 2.6.0 đo **532 card IMAGE trước 4 card VIDEO**, lộ ở vòng cuộn 10–14 (cạnh style World Cup).
  Driver cuộn ≥20 vòng. 2.9.0: card video tìm ở **chip Trending**; See All mở bằng **tiêu đề mục** (không có chữ "See All");
  thanh tab nổi che nửa dưới card ⇒ chỉ bấm phần nhìn thấy; reel có nhiều nút "Tap to use" — chỉ bấm cái trong màn.
- Deep link: `XCUIDevice.shared.system.open(URL(string:"geniusopenapp:///i2v")!)` → bấm `Open` ở alert →
  chờ `app.wait(for: .runningForeground)` → chờ `i2v-generate-cta`. **Không** gõ vào thanh địa chỉ Safari (không nhận `typeText`).
- Timeout chờ kết quả: **420s** (mạng chậm 600s). Một lượt render 2.6.0 ≈ 4–7 phút (Seedance2 5–6 phút, đo 63 lần);
  2.9.0 ≈ ~2 phút.
- Progress là thanh chạy theo thời gian: lên **99% rồi đứng > 30s** chờ BE (3/3) — không phải treo.
  Đọc % bằng `app.staticTexts` có label kết thúc `%`.
- Outcome = `result` (`i2v-result-screen`) · `failed` (`i2v-generating-failed`, text `Generation Failed`,
  nút `Try Again`/`Go Back`) · `paywall` (`paywall-screen`) · `timeout`.
- Offline trước khi Generate: app chặn ngay ở Upload, toast `No internet connection. Please try again.`
  (ERR_NET_001) — **không** qua màn failed. Màn failed chỉ tới được bằng **cắt mạng giữa lúc render**.
- Player: đọc `playbackState()` = value của `i2v-result-player`. Play/pause: bấm **lệch tâm** (dy ≈ 0.82),
  tâm có badge hút tap.
- Report I2V: toast `Report sent` / `Report failed` (đang FAIL 71/72 — app không bắn toast).

## 4. Chọn ảnh (PHPicker)

- iOS 26: PHPicker vẽ **trong cây element của app** — ô ảnh là `app.images` nhãn `BEGINSWITH "Photo, "`
  (`"Photo, <ngày>, <giờ>"`). Picker có tab (vd `Collection`). iOS cũ: ngoài process ⇒ bấm toạ độ.
- Fallback toạ độ (iPhone 12, 390×844): ô đầu `(0.50, 0.42)` normalized — `PhotoPickerAutomator.cellCenters`.
- `attempt` tăng dần ⇒ slot 2 nhận ảnh **khác** slot 1.
- Sau mỗi cú bấm: chờ **mốc phía app** đổi (số slot "Upload Image" giảm / Generate enabled / placeholder mất).
- **Luôn `dismissPicker()` trước khi sang case khác** — picker còn mở ⇒ query throw `kAXErrorServerNotFound`, chết cả method.
- Ảnh đặc biệt: `PhotoLibrarySeeder` (6000×8000 nén 1.0 = 190MB iOS từ chối; 0.4 = 10.3MB — chưa tới mốc >20MB, ghi rõ).
- Ảnh vi phạm policy (TC 40 video): QA đã lưu sẵn — code ghi tab **Collection**, user nói "ảnh đầu tiên mới lưu ở mục Favourite" (25/09). Làm dạng case bàn giao.

## 5. Share sheet

- Ảnh: mốc `AirDrop`/`Copy`/`Options` (button). **File video**: hàng đầu là app đích dạng **staticText**
  (Mail, Notes, Journal, Drive) ⇒ dùng `I2VJourneyDriver.shareSheetIsOpen()` (dò buttons + staticTexts, app + springboard).
- Notes hiện là **`New Quick Note`** (cell). Chỉ nhận element có tâm trong `app.windows.firstMatch.frame` (có "Notes" ngoài màn sau "View More").
- Share extension ngoài process: `navigationBars` rỗng. Đích an toàn: Copy / Notes / Save to Files. Telegram/app nhắn tin = **người bấm**.
- Mốc "đã rời màn phụ": tiêu đề màn phụ biến mất — không bám bàn phím (đổi emoji mất phím `Q`).

## 6. Mẫu code cốt lõi (giữ nguyên)

```swift
// Bấm theo frame neo vào cửa sổ app — không element.tap(), không isHittable (THROW)
let f = el.frame
app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: f.midX, dy: f.midY)).tap()
// Guard trước MỌI query app khác/app vừa bị kill
guard app.state == .runningForeground || app.wait(for: .runningForeground, timeout: 5) else { ... }
// Paywall = chưa đo được, không phải FAIL
if driver.paywall.exists { throw XCTSkip("Paywall — hết sub/credit, chưa đo được") }
// Kiểm CẢ HAI nhánh toast, assert tách đôi (im lặng ≠ báo sai)
let ok = waitUntil(20) { failed.exists || success.exists }
print("toast lỗi=\(failed.exists) · toast OK=\(success.exists)"); snap("TC xx — sau Save")
```

- Double-tap nhanh: giãn ~200ms giữa 2 cú (SwiftUI gộp 2 tap sát nhau ⇒ bỏ cả hai). Đếm job bằng **badge credit ở Home** (lệch 2 ⇒ 2 job).
- Bấm 3 lần trong alert (2.9.0): `alertButton.tap(withNumberOfTaps: 3, numberOfTouches: 1)`.
- Không thấy nút ⇒ in `app.buttons.allElementsBoundByIndex.map(\.label)` / `screenSummary()`, đừng im lặng.
- Nút back glass có thể chỉ có **label** `Back`, không id ⇒ thử cả 2 trục; 2.9.0 dùng nút góc trên trái theo frame (minX<70).
- Dòng verdict máy đọc (2.9.0): `print("VERDICT|<TC-ID>|PASS|<số đo>")` qua `G290.verdict(...)`.
