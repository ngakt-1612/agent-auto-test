# Setup môi trường — Genius iOS 2.9.0 trên iPhone thật

## Máy & công cụ (đã xác minh 18–20/10)
| Thứ | Giá trị |
|---|---|
| Mac | Xcode **26.6** tại `/Applications/Xcode.app`; `xcode-select` trỏ CommandLineTools → luôn `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (không cần sudo) |
| iPhone | iPhone 12 black, iOS 26.5.2, đã pair, Developer Mode bật |
| UDID cho `xcodebuild -destination` | `00008101-001A4C921E11001E` (env `G290_UDID` override) |
| CoreDevice id cho `devicectl` | `3869BBF0-7BD4-596F-9389-E70C49E759D8` |
| Bundle app / runner | `aiphotogenerator.aifaceeditor.aivideogenerator.aibeauty` / `….aibeauty.uitests.xctrunner` |
| Team ký | `KS4Z2R52B4` (`-allowProvisioningUpdates`) |
| Env app | `.prod` (`iosApp/Core/AppConstants.swift` `currentEnv`) — credit thật. Store đang 2.7.0 < 2.9.0 nên không dính force-update |
| Framework | XCUITest. Maestro có cài nhưng **thiếu Java** → không dùng |
| Python | `python3` (CLT) có openpyxl 3.1.5 ở user site; đừng thêm `-I` khi script cần openpyxl |
| Ruby gem | `xcodeproj` cho `add-test-files.rb`: `GEM_HOME="$HOME/.gem"` (hoặc `vendor/gems`) |

Kiểm nhanh:
```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun devicectl list devices                      # iPhone 12 phải "connected"
xcrun devicectl device info apps --device 3869BBF0-7BD4-596F-9389-E70C49E759D8 | grep -i aibeauty
xcrun xctrace list devices 2>/dev/null | grep -i iphone
```

## Project / scheme
- Pure SPM (không pod). Package private `CMSStyleSwift` cần SSH key đọc được `git@github.com:AperoVN/CMSStyleSwift`; `AiServiceKit` binary remote.
- **Scheme `iosAppUITestsOnly`** (user-level scheme tự tạo, nằm trong xcuserdata) = app + target UI test. Target unit test cũ hỏng vì `seedance2` → không dùng scheme `iosApp` để test. Máy khác: tạo lại scheme này (app + `iosAppUITests`) nếu thiếu (chưa xác minh có được share).
- Thêm file test vào target (pbxproj) — backup `project.pbxproj` trước:
```bash
cd /Users/kieunga/Downloads/IIP055-Genius-IOS-2.9.0
cp iosApp.xcodeproj/project.pbxproj plans/<plan>/project.pbxproj.backup-<yymmdd>
GEM_HOME="$HOME/.gem" ruby scripts/add-test-files.rb iosAppUITests iosAppUITests/NewSuite.swift
# nhiều file: dùng xargs (zsh không tách $files)
ls iosAppUITests/Genius290*.swift | xargs env GEM_HOME="$HOME/.gem" ruby scripts/add-test-files.rb iosAppUITests
```
- Target UI test đã thêm `NSPhotoLibraryUsageDescription` (đếm ảnh Photos bằng PHAsset).
- ~26 `accessibilityIdentifier` đã gắn vào app (user đồng ý 18/10; không đổi hành vi). Helper `iosApp/Components/DesignSystem/View+TestIdentifier.swift`; bản gốc 14 file: `plans/261018-1110-…/app-backup/`. Màn **Chat không có id** (chọn theo label/ảnh).

## Build (1 lần / mỗi lần sửa test)
```bash
cd /Users/kieunga/Downloads/IIP055-Genius-IOS-2.9.0
export G290_OUT=$PWD/plans/<plan-dir>/runs          # mặc định: plans/261018-…/runs
export G290_DD=/private/tmp/<session>/scratchpad/dd290  # NÊN đặt: mặc định trỏ scratchpad phiên cũ 38b17dd6
scripts/run-genius-290-device-suite.sh build        # = xcodebuild build-for-testing -scheme iosAppUITestsOnly \
                                                    #   -destination platform=iOS,id=0000810… DEVELOPMENT_TEAM=KS4Z2R52B4 -allowProvisioningUpdates
grep -E "error:|TEST BUILD" $G290_OUT/build.log | sort -u
```
Không build trong lúc đang có `xcodebuild test-without-building` (queue script tự chờ `pgrep`). Không sửa pbxproj khi build đang chạy.

## Trạng thái máy cần có
| Yêu cầu | Cách đặt / kiểm |
|---|---|
| Máy mở khoá, **Auto-Lock = Never**, cắm cáp suốt buổi | Tester. Khoá màn → log "Timed out while enabling automation mode" (runner tự chờ 30 s × 30 lần) |
| Mac không ngủ | `nohup caffeinate -dimsu -w <pid queue> >/dev/null 2>&1 &`; không gập nắp, không Sleep thủ công |
| RC prod bật `enable_ai_chat_feature = true` + `enable_try_on_feature = true`; `home_banner_texts` chưa tạo | User bật trên console (18/10 đã bật). Agent KHÔNG đổi RC |
| Sandbox Apple ID đăng nhập (Settings › App Store › Sandbox) | Tester. Mật khẩu chỉ tester nhập trên máy — không lưu, không hỏi |
| **Gói Yearly** cho nhóm tốn lượt | `TEST_RUNNER_ATTENDED_PLAN=Yearly scripts/run-genius-290-device-suite.sh RUN_ATTENDED_PURCHASE OnboardingToPaywallJourneyUITests purchaseN` → test tự tới paywall chọn Yearly, tester nhập mật khẩu (chờ 5 phút) |
| Kiểm gói | `RUN_G290_SUB_PROBE Genius290SubscriptionLibraryUITests/test00_probeSubscriptionState` → log `SUBSTATE|premium` / `SUBSTATE|expired` (dựa vào nút `home-upgrade-cta` ở Home) |
| Lượt (credit) | Gói: **20 lượt/ngày** (huy hiệu số ở góc phải trên Home; My Balance trong Setting). Topup sandbox: **1 lượt / lần mua** |
| Photos | Quyền Genius = **Full Access**; thư viện có ảnh mặt người + 1 video ≤15 s (+ 1 video 40 s cho Chat — chép sẵn) |
| Reduce Transparency | **Tắt** (case CH08-002 tự bật/tắt; dọn bằng `test30_restoreDeviceSettings`) |
| Mạng | Airplane tắt, Wi-Fi bật. Case offline luôn tự trả mạng |
| Chứng chỉ dev | Nếu "Developer App Certificate is not trusted": iPhone có Internet → Settings › General › VPN & Device Management › Trust/Verify App |

## Trạng thái máy lúc dừng gần nhất (20/10 19:05)
- **Đang có gói Yearly** (mua lại 15:28), topup đã dùng, lượt hôm đó gần hết.
- Photos = Full Access, Reduce Transparency = tắt.
- Queue huỷ gói (`run-genius-290-ai-chat-nosub-queue.sh`) đã dừng — **chưa huỷ gói**.
- 21/10 máy được dùng cho event tracking Library (xem `features/ios-event-tracking/`) → trạng thái gói/lượt hiện tại: **chưa xác minh** — chạy SUB_PROBE trước.

## Sự cố máy & cách gỡ
| Triệu chứng | Xử lý |
|---|---|
| Runner "hung before establishing connection" kéo dài (18/10 từ 16:27) | Gỡ xctrunner không ăn → **khởi động lại iPhone** (cần tester) |
| "Developer App Certificate is not trusted" | Máy mất Internet (thường do case offline). Trả mạng qua Settings (`test_restoreNetwork` nếu runner còn chạy) hoặc tester Trust |
| Mất kết nối giữa chừng | Thử lại 1 lần; vẫn lỗi → báo tester cắm lại cáp/mở khoá |
| Hộp thoại hệ thống bất ngờ ("You're all set" sau mua topup) | Lượt đó hỏng → chạy lại; dặn tester không chạm máy khi test chạy |
| macOS không có `timeout` | Dùng vòng lặp + `sleep` hoặc `waitUntil` trong test |

## Gỡ / cài lại app
```bash
xcrun devicectl device uninstall app --device 3869BBF0-7BD4-596F-9389-E70C49E759D8 aiphotogenerator.aifaceeditor.aivideogenerator.aibeauty
# lần chạy test kế tiếp tự cài lại app. Cài lại = mất lịch sử Chat local, hỏi lại quyền Photos.
```
**Không gỡ app sau khi đã mua gói** trừ case cần (cùng Apple ID thì gói tự khôi phục + server trả lại hàng trăm kết quả Library).
