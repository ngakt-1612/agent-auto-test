# Setup môi trường — Genius I2I / I2V trên iPhone thật

Lệnh lấy từ runbook đã chạy thật (`Gen-Image-to-Image/genius-image-generate/README.md`,
plan HTML video, `scripts/run-genius-290-device-suite.sh` của 2.9.0).

## 1. Biến chuẩn (dán một khối, đừng bọc trong hàm bash)

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer   # BẮT BUỘC ở MỌI lệnh xcrun/xcodebuild
PROJECT_DIR=~/Downloads/IIP055-Genius-IOS-2.9.0                   # hoặc bản giải nén 2.6.0
UDID=00008101-001A4C921E11001E                                    # iPhone 12 black; máy khác: xcrun devicectl list devices
TEAM_ID=KS4Z2R52B4
BID=aiphotogenerator.aifaceeditor.aivideogenerator.aibeauty
SCHEME=iosAppUITestsOnly                                          # 2.9.0; với 2.6.0 dùng iosApp
cd "$PROJECT_DIR"
COMMON="-project iosApp.xcodeproj -scheme $SCHEME -destination platform=iOS,id=$UDID \
  DEVELOPMENT_TEAM=$TEAM_ID -allowProvisioningUpdates MARKETING_VERSION=2.8.0"
```

- Thiếu `DEVELOPER_DIR` ⇒ `xcrun devicectl` báo "not a developer tool", Xcode tốn ~35s thu diagnostics mỗi lượt fail.
- **Đừng** truyền `$COMMON` qua hàm bash tự viết (`run $COMMON`): shell tách sai ⇒ `xcodebuild` báo
  "requires that the name of a scheme … is provided". Dán nguyên khối hoặc dùng `templates/run-device-suite.sh`.
- 2.9.0 (source 2.9.0 > store 2.7.0) không cần đè `MARKETING_VERSION`; source 2.6.0 thì **bắt buộc** đè
  (2.7.1 cho gen ảnh, 2.8.0 cho gen video).

## 2. Preflight (5 phút, 0 credit)

```bash
# 1) máy thấy + connected
xcrun devicectl list devices
# 2) version store — app version phải CAO HƠN, nếu không ForceUpdateDialog ("Update Now") chặn mọi màn
curl -s "https://itunes.apple.com/lookup?bundleId=$BID" | python3 -c "import json,sys;r=json.load(sys.stdin)['results'];print(r[0]['version'] if r else 'none')"
xcodebuild -showBuildSettings -project iosApp.xcodeproj -scheme $SCHEME | grep MARKETING_VERSION
```

Checklist tay (cần người, báo user **một lần**):
- [ ] iPhone **mở khoá**, `Settings → Display & Brightness → Auto-Lock = Never`, cắm cáp suốt buổi.
- [ ] Còn ≥ 2GB trống (video Save về máy).
- [ ] Thư viện ảnh có sẵn ảnh **mặt người** (style bị BE từ chối ảnh không mặt) + 1 video ≤15s (cho 2.9.0).
- [ ] Airplane Mode off, Network Link Conditioner off (dọn bằng `RUN_RESTORE_NETWORK`).
- [ ] Mac không ngủ: `caffeinate -dimsu -w <pid hàng đợi>`.
- [ ] Đóng bớt app trên Mac — mỗi `.xcresult` 200–900 MB, hết RAM thì macOS giết lượt chạy.

`MARKETING_VERSION` chỉ đè được **trên dòng lệnh** — sửa `.xcconfig` vô tác dụng vì target đặt version
trong `project.pbxproj`. Comment trong `.xcconfig` phải là `//`, `#` làm hỏng build
(`Could not find test host`).

Ghi chú source (từ `CLAUDE.md` của project):
- Pure SPM; package private `CMSStyleSwift` kéo qua **SSH** (`git@github.com:AperoVN/CMSStyleSwift`) — máy
  thiếu SSH key đọc được repo này thì resolve package fail. `AiServiceKit` là binary SPM remote.
- Env host: `iosApp/Core/AppConstants.swift` → `currentEnv = .prod` ⇒ **gen tốn credit thật**. Không tự đổi.
- `CLAUDE.md` ghi "There are no tests" — đã cũ; target `iosAppUITests` do ta thêm.
- Jira (log bug): `scripts/jira.sh` dùng `JIRA_BASE_URL`/`JIRA_PAT` trong `~/.zshrc` hoặc `.env.jira` — chỉ ghi ticket khi user bảo.

## 3. Build một lần cho cả buổi

```bash
xcodebuild build-for-testing $COMMON          # chờ "** TEST BUILD SUCCEEDED **"
# hoặc: templates/run-device-suite.sh build   (2.9.0, có -derivedDataPath riêng)
```

- **Không bao giờ** build khi một suite đang chạy — cắt ngang lượt đó (đã mất trọn 1 lượt gen TC 38).
- `test-without-building` cho mọi lượt chạy; chỉ build lại khi đổi code test/app hoặc vừa gỡ app.
- `Could not find test host` ⇒ build app fail từ trước: đọc full log, đừng chỉ grep `error:`.

## 4. Đăng ký file test mới vào project

```bash
grep -c FileSystemSynchronized iosApp.xcodeproj/project.pbxproj   # 0 ⇒ phải đăng ký tay
cp iosApp.xcodeproj/project.pbxproj <plan-dir>/project.pbxproj.backup-<yymmdd>   # backup trước
GEM_HOME="$HOME/.gem" gem install xcodeproj --no-document
for f in iosAppUITests/*.swift; do GEM_HOME="$HOME/.gem" ruby scripts/add-test-files.rb iosAppUITests "$f"; done
```

Quên đăng ký ⇒ `cannot find 'X' in scope` (trông như lỗi code). Script ở
`~/Downloads/Gen-Image-to-Image/skills/ios-xcuitest-device-automation/scripts/` (add-test-files.rb,
add-uitest-target.rb, et-config.rb, Gemfile) — 2.9.0 đã có sẵn trong `scripts/`.

Build settings target UI test cần thêm:
- `INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription` — để `PhotoLibrarySeeder` ghi ảnh.
- `NSPhotoLibraryUsageDescription` — để runner đếm ảnh Photos (2.9.0 đã thêm).

## 5. Test identifier trong app

Source 2.9.0 đã gắn sẵn (backup bản gốc ở `plans/261018-…/app-backup/`). Nếu dùng source khác chưa có:
xin dev gắn theo bảng ở `flow-and-locators.md` §1. Quan trọng nhất: `i2v-result-player` +
`accessibilityValue` `playing`/`paused` + `.accessibilityElement(children: .contain)`.

## 6. Quyền — dựng trạng thái

| Muốn | Cách |
|---|---|
| Photos + Camera = `notDetermined` | gỡ app: `xcrun devicectl device uninstall app --device $UDID $BID` rồi build/cài lại |
| Photos = Full Access từ fresh install | qua popup hệ thống (probe `ImageGenerateToastUITests/test_probeGrantPhotosFromFreshInstall`) — Settings chưa có hàng Photos khi app chưa hỏi lần nào |
| Photos = Full Access giữa buổi | `TEST_RUNNER_RUN_GRANT_PHOTOS=1 … VideoEntryPointProbeUITests/test_grantPhotosFullAccess` (qua Settings, **không gỡ app**) |
| Photos = None | `SettingsPhotosDriver.setAccess(.none)` — iOS **kill app** sau đó |
| Mạng sạch | `TEST_RUNNER_RUN_RESTORE_NETWORK=1 … VideoEntryPointProbeUITests/test_restoreNetwork` |

Trang app trong Settings iOS 26: `Settings > Apps > Genius` — tới bằng ô tìm kiếm, `settings.launch()` chỉ mở
trang gốc (và mở lại trang lần trước ⇒ terminate + launch + lùi trang).

## 7. Sub / credit

| Việc | Lệnh / cách |
|---|---|
| Mua sub sandbox (cần người nhập mật khẩu) | `TEST_RUNNER_RUN_ATTENDED_PURCHASE=1 TEST_RUNNER_ATTENDED_PLAN=Yearly xcodebuild test-without-building $COMMON -only-testing:iosAppUITests/OnboardingToPaywallJourneyUITests` |
| Sau mật khẩu | automation tự bấm `OK` hộp "You're all set" (tầng springboard, poll nhịp 2s) |
| Kiểm entitlement | chạy 1 suite cần gen / probe: ra `paywall-screen` ⇒ hết sub hoặc hết lượt ngày |
| Mật khẩu Apple ID sandbox | **không lưu ở đây** — hỏi user/QA lead tại thời điểm mua. Round Seedance dùng account sandbox ghi trong `TC-Report_IIP055.2.5.1_…html` (dòng "IAP Sandbox") |

- Chỉ mua **Yearly**. Weekly sandbox sống 3 phút (< 1 lượt gen). Yearly sống **1–6 giờ, không đoán được**
  (19/09 ~6h, 24/09 ~1h20) ⇒ probe trước mỗi nhóm tốn credit, đừng tính giờ.
- Bản Debug ký dev ⇒ StoreKit luôn Sandbox. Không đăng xuất Sandbox account.
- Huỷ sub trong app (2.9.0): Setting → Manage Subscription → gói → Manage subscription → lý do → user nhập mật khẩu.
- Nút "Pro"/upgrade ở Home ẩn khi đã sub (`isEnablePaywallHome && !isPremiumUser`) ⇒ suite mua báo
  "không thấy onboarding/Home/paywall" thường là **đang có sub** — chạy thẳng nhóm gen để xác nhận.
- 2.9.0: paywall/"Daily limit reached" khi Generate có thể là **hết lượt tạo trong ngày** (app mở Top-up
  "0 topup creations"), không phải hết gói — kiểm nút Pro ở Home trước khi kết luận.
- Cài lại cùng Apple ID: gói tự khôi phục (RevenueCat App User ID trong Keychain sống qua uninstall), và
  kéo về hàng trăm kết quả cũ vào Library.

## 8. Cấu hình máy test khác

Chưa kiểm trên máy khác (chưa xác minh): provisioning cho UDID mới, nhãn hệ thống iOS khác 26,
toạ độ `PhotoPickerAutomator.cellCenters` (đo trên 390×844), CMS có trả style VIDEO cho account đó không.
Probe 0 credit trước: `VideoEntryPointProbeUITests/test_whereIsTheVideoEntryPoint` + camera suite (sau gỡ app).
