# Setup môi trường — Genius iOS event tracking trên máy thật

## 1. Mac / Xcode
```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer   # xcode-select đang trỏ CLT → BẮT BUỘC mọi lệnh xcodebuild/xcrun
xcrun devicectl list devices                                      # thấy iPhone 12 black, state connected
```
- Xcode 26.x. Java chưa cài → không dùng Maestro; dùng XCUITest.
- Python có `openpyxl`: `/Library/Developer/CommandLineTools/usr/bin/python3` (openpyxl ở user site `~/Library/Python/3.9`) → chạy **không** kèm `-I` (`-I` tắt user site → `ModuleNotFoundError`). Hoặc tạo venv riêng trong scratchpad: `python3 -m venv $S/venv && $S/venv/bin/pip install openpyxl` (21/10 dùng cách này, chạy được với `-I`).

## 2. Repo
- Source: `~/Downloads/IIP055-Genius-IOS-2.9.0` (project `iosApp.xcodeproj`, KHÔNG dùng `Pods.xcworkspace` — stale; Firebase/Adjust/RevenueCat là SPM).
- Target app `iosApp`, PRODUCT_NAME/module `Genius`. Bundle id: `aiphotogenerator.aifaceeditor.aivideogenerator.aibeauty`.
- Scheme chạy máy thật: **`iosAppUITestsOnly`**. Team: `DEVELOPMENT_TEAM=KS4Z2R52B4` (truyền dòng lệnh, test target không có team sẵn).
- Thêm file test mới vào target: `ruby scripts/add-test-files.rb iosAppUITests iosAppUITests/<File>.swift` (cần gem `xcodeproj`). Backup `project.pbxproj` vào plan trước khi chạy.
- Patch sink: xem `capture-mechanism.md` §1.

## 3. Máy test
| | |
|---|---|
| Máy | iPhone 12 black |
| UDID (xcodebuild `-destination id=`) | `00008101-001A4C921E11001E` (env `G290_UDID`) |
| CoreDevice id (devicectl) | `3869BBF0-7BD4-596F-9389-E70C49E759D8` (env `G290_COREDEVICE`) |
| Bắt buộc | Developer Mode ON · Settings → Developer → **Enable UI Automation** ON · mở khoá, Auto-Lock = Never · cắm cáp · không ai chạm máy |
| Lỗi `Timed out while enabling automation mode` | = máy khoá / chưa bật UI Automation. Runner tự chờ 30 s × 30 lượt (~15 phút); báo user mở khoá 1 lần |

## 4. Build (sink bật lúc chạy, không cần flag build)
```bash
cd ~/Downloads/IIP055-Genius-IOS-2.9.0
export G290_UDID=00008101-001A4C921E11001E
export G290_OUT=$PWD/plans/<plan-dir>/runs            # mặc định runner trỏ plan 261018 → luôn set
scripts/run-genius-290-device-suite.sh build          # build-for-testing, log ở $G290_OUT/build.log
```
- `DerivedData` ở `$G290_DD` (mặc định scratchpad phiên cũ `…/38b17dd6-…/scratchpad/dd290` — nếu thư mục mất, set `G290_DD` sang scratchpad mới).
- Sửa Swift test/app → **build lại** trước khi chạy (`test-without-building` dùng bundle cũ).
- Sink chỉ ghi khi test truyền `EVENT_SINK_PATH` → build Debug thường là đủ.
- (05/10, chưa xác minh lại) Debug build bắn event vào Firebase **PROD** → event test lẫn số liệu thật; hỏi team data nếu chạy khối lượng lớn.

## 5. Tài khoản & sub
Nhiều event (gen_tray, ô đang tạo, Retry) cần **Generate thật** → cần sub + credit.

### Cách 1 — Email verify (user chốt 05/10: "không cần mua sub, login bằng email verify → tự động nhận sub")
- Settings → **Web Subscription** → nhập email đã có web sub → Verify → My Balance > 0. Không OTP, không mua.
- Code: `iosApp/Core/Managers/EmailVerificationManager.swift` (activate device → resolve premium từ BE). Cửa vào: onboarding (trước paywall), Settings → Web Subscription, deeplink.
- Email đọc từ env `TEST_SUB_EMAIL` — KHÔNG ghi email vào repo/report.
- Mỗi máy chiếm 1 slot `max_devices_per_email`; bỏ máy thì Log out ở màn Web Subscription để trả slot.
- Có sub vẫn bị trừ lượt (credit dùng chung).

### Cách 2 — Mua Sandbox có người (21/10 dùng vì sub đã hết hạn)
```bash
TEST_RUNNER_ATTENDED_PLAN=Weekly scripts/run-genius-290-device-suite.sh RUN_ATTENDED_PURCHASE OnboardingToPaywallJourneyUITests purchase-weekly
```
- Automation bấm tới Subscribe; **user nhập mật khẩu Sandbox** trên iPhone. Báo user 1 lần, rồi chờ.
- Gói **ngắn nhất: Weekly** (luật sổ tay Lensie: không Yearly). Weekly Sandbox hết hạn sau vài phút → chạy case cần sub NGAY sau khi mua.
- Kiểm log mua thành công, không tin lời xác nhận: `grep -E "💳|✅|❌|Purchase|Sandbox|Weekly" runs/purchase-weekly-*.log`.

### Kiểm trạng thái sub (TRƯỚC mọi case cần Generate)
```bash
scripts/run-genius-290-device-suite.sh RUN_G290_SUB_PROBE Genius290SubscriptionLibraryUITests/test00_probeSubscriptionState sub-probe >/dev/null
grep -ho "SUBSTATE|[a-z]*" $(ls -t $G290_OUT/sub-probe-*.log | head -1) | tail -1     # premium | expired
```
- Logic: `home-upgrade-cta` còn hiện → `expired`.
- Dấu hiệu trong sink: `quota_check decision=block_no_sub` / `iap_view` sau bấm Generate = hết sub; `block_out_of_quota` = hết credit (dialog 481).

## 6. Trạng thái máy sau lượt 21/10 (để biết bắt đầu từ đâu)
- Đã mua Weekly 10:18 21/10 (giờ đã hết hạn — kiểm lại bằng sub-probe).
- Airplane Mode đã tắt lại. Ảnh tạo trong lượt đã bị xoá thật (test04).
- Library account đang có >20 kết quả (nên `library_start_creating_click` không chạm được).
