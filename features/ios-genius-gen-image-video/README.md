# Genius iOS — Gen Image (I2I) & Gen Video (I2V) autotest trên iPhone thật (XCUITest)

Gói kiến thức cho AI agent **đọc trước khi chạy** automation test luồng gen ảnh / gen video của app
Genius iOS. Rút từ: đợt Image Generate (07→14/09/2026, 51 TC), Video Generate (17→25/09/2026, 62 TC),
port sang 2.9.0 (18–19/10/2026), round Seedance2 I2V bằng Appium (26–28/08/2026).

## App

| Thứ | Giá trị |
|---|---|
| Dự án | IIP055 — Genius (iOS) |
| Bundle id | `aiphotogenerator.aifaceeditor.aivideogenerator.aibeauty` |
| Deep link luồng video | `geniusopenapp:///i2v` |
| Project / scheme | `iosApp.xcodeproj` · scheme `iosApp` (2.6.0) · `iosAppUITestsOnly` (2.9.0, scheme riêng vì target unit test hỏng do `seedance2`) |
| UI test target | `iosAppUITests` |
| Team | `KS4Z2R52B4` |
| Thiết bị đã chạy | iPhone 12 "black", iOS 26.5.2, UDID `00008101-001A4C921E11001E` |
| Xcode | 26.6, luôn qua `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (xcode-select trỏ CLT) |
| Store version | 2.7.0 (tại 10/2026) → build phải có `MARKETING_VERSION` cao hơn (2.7.1 / 2.8.0) với source 2.6.0 |

## Source & tài nguyên

| Loại | Đường dẫn |
|---|---|
| Source app 2.9.0 (mới nhất, đã gắn ~26 test id) | `~/Downloads/IIP055-Genius-IOS-2.9.0` (không phải git) |
| Source app 2.6.0 | `~/Downloads/IIP055-Genius-IOS-2.6.0.zip` |
| Suite I2I + I2V đang có trong project | `~/Downloads/IIP055-Genius-IOS-2.9.0/iosAppUITests/{ImageGenerate*,VideoGenerate*,Video*,I2I*,I2V*}.swift` |
| Skill gốc (lõi, đọc trước) | `~/Downloads/ios-xcuitest-device-automation/` (SKILL.md, HUONG-DAN-SU-DUNG.md, references/, templates/, scripts/) |
| Repo gen ảnh (skill + 15 suite + 12 report + spec snapshot) | `~/Downloads/Gen-Image-to-Image/` (`genius-image-generate/README.md` = runbook 7 bước) |
| Repo gen video (skill riêng video + report + xlsx kết quả) | `~/Downloads/Gen-Image-to-Video/` (`skills/ios-video-generate-automation/`) |
| Plan HTML (luật bất biến, bảng "cái gì phá trạng thái") | `~/Downloads/Auto-test Image Generate Genius.html`, `~/Downloads/Auto-test Video Generate Genius.html` (= `plan-auto-test-video-generate-genius.html`) |
| QA sheet (spec cạnh kết quả) | `~/Downloads/Image Generate QA Sheet.html`, `image-generate-qa.html`, `Video Generate QA Sheet.html` |
| Report Seedance2 I2V (Appium, round 11) | `~/Downloads/TC-Report_IIP055.2.5.1_ImageToVideo_Seedance2_Round11_2026-08-28.html` |
| Plan 2.9.0 | `~/Downloads/IIP055-Genius-IOS-2.9.0/plans/261018-1110-genius-290-automation-ui-image-video/` (plan.md, handoff, runs/, report) — bản sao plan.md ở `~/plans/261018-1110-…/plan.md` |
| Danh sách test id 2.9.0 | `~/Downloads/IIP055-Genius-IOS-2.9.0/plans/reports/fullstack-261018-1120-genius-290-test-identifiers-report.md` |

## File testcase

| File | Số TC | Trạng thái |
|---|---|---|
| `~/Downloads/TC_Image_Generate.xlsx` | 51 (ID 1→56, thiếu 14/23/35/42/54) | Đã chạy full. Snapshot spec: `Gen-Image-to-Image/genius-image-generate/spec/tc-image-generate-spec-260914.json` |
| `~/Downloads/TC_Video_Generate.xlsx` (bản 25/09 12:02, md5 `3af70589…`) | 62 (ID 1→72, có khoảng trống) | Đã chạy full. Kết quả: `~/Downloads/TC_Video_Generate-ket-qua-260925.xlsx` |
| `~/Downloads/TC_IIP055.1.5.4_SDK_Image_to_Image.xlsx` | 162 (sheet TC_SDK_Image_to_Image / Summary / Ambiguity & Audit — 21 điểm mơ hồ, 28 TC "chờ confirm") | Sinh 09/10 bằng skill qa-testcase-generator từ Confluence v7. **Chưa chạy auto** |
| `~/Downloads/TC_Genius_v2.9.0_UpdateUI_Library.xlsx` | 84 | Không thuộc feature này nhưng có case gen nền (BG*) dùng chung driver |

Cột xlsx (cả 3 file gen): `N° · Feature · Test Description · Sub-scenario · Precondition · Test Data · Action · Expected Result · PASS/FAIL` — verdict ghi vào **cột I**.

## Kết quả đã chốt

| Bộ | Kết quả | Bug / ghi chú |
|---|---|---|
| Image 51 TC (14/09, build 2.6.0→2.7.1) | 38 PASS · 4 FAIL · 3 MISMATCH · 4 N/A · 2 BLOCKED · ~90 phút · ~16 credit | FAIL 33 (offline Generate im lặng), 44 (Save thiếu quyền không toast), 46 (offline Share), 56 (share sau camera/background). N/A 17/24/26/27 (iOS không có ảnh Demo/Preview). BLOCKED 40/45 (hoàn tất share ra app khác) |
| Video 62 TC (25/09, build 2.8.0) | 58 PASS · 4 FAIL · ~58 lượt gen | FAIL 54 (offline Save im lặng, nghi `MediaActions.swift:80` URLSession không timeout), 56 (offline Share không toast "Share failed"), 71 (Report online không toast "Report sent"), 72 (Report offline không toast "Report failed") |
| Seedance2 I2V (Appium, 28/08) | 58 TC: 16 PASS · 21 FAIL · 6 N/A · 10 Skip · 5 Blocked | Gate gen là **credit** chứ không phải sub; mua sub/gói lẻ không được cộng lượt |
| 2.9.0 UI+Library (19/10) | 74 PASS · 7 FAIL · 3 lệch | Có case gen nền: BG01-003 (edge-swipe bị `.navigationBarHidden(true)` chặn), BG03-003 |

## Đọc file nào khi nào

| Khi | Đọc |
|---|---|
| Luôn, trước lệnh đầu tiên | `rules-and-lessons.md` (luật bất biến + bài học, quan trọng nhất) |
| Dựng máy / build / mua sub | `setup-environment.md` |
| Viết/sửa test, tìm element, chờ gen | `flow-and-locators.md` + `templates/*.swift` |
| Chạy suite, thứ tự, ghi kết quả, report, resume | `run-and-report.md` + `templates/run-device-suite.sh` |
| Cần chi tiết sâu (Settings, bẫy XCUITest, nguyên tắc verdict) | skill gốc `~/Downloads/ios-xcuitest-device-automation/references/*.md` |
| Copy suite ảnh sang video | `~/Downloads/Gen-Image-to-Video/skills/ios-video-generate-automation/references/video-vs-image-differences.md` |

## Templates (`templates/`, bản copy từ source 2.9.0 — bản mới nhất)

| File | Dùng cho |
|---|---|
| `I2IJourneyDriver.swift` | launch (khoá `en`), `reachHome()` (onboarding/xác thực/paywall/popup), `onScreen`/`tap` theo frame+toạ độ, `dismissPicker()` |
| `I2VJourneyDriver.swift` | vào luồng video (cuộn Home tìm `home-style-card-video`, deep link dự phòng), `pickPhotosUntilReady`, `waitForGenerateOutcome(420s)`, `playbackState`, `shareSheetIsOpen` |
| `PhotoPickerAutomator.swift` | chọn ảnh PHPicker (iOS 26: ô ảnh là `images` nhãn `"Photo, <ngày>, <giờ>"`; fallback toạ độ iPhone 12) |
| `SystemPermissionAlertHandler.swift` | bấm popup quyền hệ thống (có `denyMarkers`, nháy cong U+2019) |
| `SettingsNetworkDriver.swift` | Airplane/Wi-Fi/Network Link Conditioner + `SettingsPhotosDriver.setAccess` |
| `PhotoLibrarySeeder.swift` | runner tự nạp ảnh vào thư viện (`PHAssetCreationRequest`) |
| `EvidenceSnapshot.swift` | `snap("TC xx — …")` ảnh bằng chứng `.keepAlways` |
| `run-device-suite.sh` | chạy 1 suite + tự chờ máy mở khoá + export ảnh + lọc dòng `VERDICT\|` (đổi `OUT/DD/UDID/scheme`) |
| `extract-testcases-from-xlsx.py` | đọc xlsx TC → JSON (stdlib) |
| `write-status-to-xlsx.py` | ghi verdict vào cột I (bản đã escape `<>&`, tự backup + đếm dòng) |

## Nếu được giao chạy `TC_IIP055.1.5.4_SDK_Image_to_Image.xlsx` (chưa từng chạy)

- 162 TC: Upload Photo 29 · Loading & failed 24 · Permission 23 · Generate gate (Paywall/Daily limit) 19 ·
  Save/Share/Report toast 16 · Result 15 · Điều hướng 14 · I2I chạy nền 10 · Remote Config 7 · E2E 5.
- Đọc sheet `Ambiguity & Audit` trước: 28 TC có Expected "chờ confirm" (vd Daily limit khi `enable_topup=false`,
  ảnh >10MB/HEIC, server >8.5s, lượt lỗi có bị trừ) ⇒ hỏi user/PO, đừng tự chấm.
- Tái dùng suite `ImageGenerate*` + `Genius290GenerationUITests` (UI 2.9.0); TC cần 500/503/400/timeout
  hoặc đổi Remote Config ⇒ cần hạ tầng (proxy/RC API) — user 2.9.0 cấm mock/đổi RC ⇒ ghi BLOCKED kèm đường mở (chưa xác minh với spec này).

## Phạm vi — đọc kỹ

- Tài liệu cũ (plan/report/skill gen ảnh-video) là **công cụ**, không phải phạm vi. Chỉ chạy TC của file
  spec user đưa lần này (xem `rules-and-lessons.md` R1).
- Ngoài phạm vi automation (đã thống nhất): nội dung ảnh/video (pixel, thời lượng, codec, tỷ lệ 4:3),
  cuộc gọi đến, bộ nhớ đầy, gửi thật qua app nhắn tin (chỉ làm dạng "case bàn giao").
