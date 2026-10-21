# Setup & chạy — Genius iOS Subscription Sandbox (Appium)

`$SRC` = thư mục source Genius trên máy đang chạy (không copy cứng path; trước đây `/Users/mdt_thao/Documents/Genius/IIP055-Genius-IOS-2.6.0-main` hoặc `…/TesterL3/Genius/IIP055-Genius-IOS-2.6.0-main`). Tool: `~/qa-e2e/genius/tools/` (bản copy ở `templates/`).

## 1. Môi trường (1 lần / máy mới)
- Xcode 26.3+, SSH key đọc repo private AperoVN (`AiServiceKit-Binary`, `CMSStyleSwift`) — `ssh -T git@github.com`. Genius là pure SPM (không workspace/Pods).
- Node 22 (Node 23 không hợp Appium 3.6) + Appium 3.6.0 + `xcuitest@12.7.0`, port 4723:
  `PATH="/opt/homebrew/opt/node@22/bin:$PATH" appium` (hoặc node22 trong `~/.local/opt/node22` nếu dựng bằng `Tester/setup e2e/setup_macos_2026-08-24.sh` — không cần sudo).
- Làm tay khi lên máy mới: Xcode ▸ Accounts thêm Apple ID Apero (team `KS4Z2R52B4`) · SSH/PAT repo private · cắm iPhone USB + Trust + Auto-Lock = Never.
- `/usr/bin/python3` + `openpyxl` (đọc xlsx của user — chỉ đọc).

## 2. Build, cài, mở session
```bash
UDID=00008120-001A20320282201E   # iPhone Tester 2
cd "$SRC"
xcodebuild -project iosApp.xcodeproj -scheme iosApp -configuration Debug \
  -destination "id=$UDID" -allowProvisioningUpdates -derivedDataPath ./DerivedData-device build
xcrun devicectl device install app --device "$UDID" ./DerivedData-device/Build/Products/Debug-iphoneos/Genius.app
```
- App ký per-device → đổi máy phải rebuild. Cài lúc máy khoá có thể lỗi launch → mở khoá rồi cài lại.
- Caps Appium: `usePrebuiltWDA=false` + `xcodeOrgId=KS4Z2R52B4` + `xcodeSigningId="Apple Development"` (hoặc `updatedWDABundleId=com.apero.wda`), `newCommandTimeout` ≥ 900. Helper: `templates/appium_drive.py`.
- Trước round: kiểm force-update (store version vs bản QA) — xem rules §D.

## 3. Luồng mua (tự động trừ 1 bước)
1. Launch → ATT + Notifications: `POST /session/{id}/alert/accept`.
2. Onboarding carousel 6 trang → «See the magic».
3. Đóng «verify email» + dialog Rate-us → Home (Free: có nút «Pro», còn credit).
4. **Relaunch (terminate + activate) rồi mới đọc state Free/Pro.**
5. «Pro» → paywall «Meet Your Best Version» (Weekly 299.000đ Popular / Yearly 1.199.000đ) → chọn gói.
6. **Bàn giao (luật #5)**: chọn sẵn gói → chụp ảnh → ping Discord → DỪNG. KHÔNG tap «Continue» (bảng StoreKit chờ mật khẩu sẽ timeout).
7. User: Continue → bảng Sandbox (`qa202@apero.vn`, «For testing purposes only») → Subscribe + mật khẩu/Face ID.
8. Verify: «You're all set — Your purchase was successful. [Environment: Sandbox]» → relaunch → nút «Pro» biến mất, header có badge credit; đo credit TRƯỚC và SAU khi lên Pro.
- Ưu tiên Yearly khi cần nhiều thời gian (~1h); Weekly chỉ ~18′. Mới mở app chưa nhận sub → paywall «Restore».

## 4. Ping Discord (kênh `bot_sub`)
```bash
/usr/bin/python3 templates/discord_notify_2026-08-24.py ping "<gói>" "<máy>" "<đang chờ bước gì>"
/usr/bin/python3 templates/discord_notify_2026-08-24.py file <ảnh> "<chú thích>"
```
- Credential: `TesterL3/discord-spec-watcher/.env` (`DISCORD_BOT_TOKEN`, `DISCORD_CHANNEL_ID`) — không chép ra ngoài. Set `MENTION_USER_ID` để @user; đọc lại tin, `mentions[]` không rỗng mới tính là gửi.
- Xong round → đính report HTML (tên file không dấu/space).

## 5. Cancel / Restore
- **Cancel** (đo 28/08): Setting → «Manage Subscription» → sheet «How can we help?» (Customer Center) → row «Yearly» → «Manage subscription» → «Why are you cancelling?» chọn «Don't use the app» (tránh «Bought by mistake» → luồng refund) → «Apple Account Password» **[user nhập — ping]** → «Edit Subscription» → «Cancel Subscription» → «Confirm Cancellation».
  - Mốc 1: «ends on …» vẫn Pro. Mốc 2: hết chu kỳ → relaunch → hiện lại «Pro», gen bị paywall (Yearly thu hồi ~65′ sau mua).
- **Restore**: paywall → Restore. Chưa mua → «No Purchase Found»; đã mua → «Restore Successful».

## 6. Credit = 0 (gen cạn thật — chỉ cách này)
```bash
/usr/bin/python3 templates/drain_credit_2026-08-26.py 1   # gen tới credit = 1 → chạy S2V-E12
/usr/bin/python3 templates/drain_credit_2026-08-26.py 0   # gen tiếp về 0 → chạy S2V-304→305→306
tail -f /tmp/genius_drain.log
```
- Vòng gen: Home → tab «Motion» → «Tap to use» → «Gallery» → chọn ảnh → «Generate» → X paywall chung → X «Last Chance» → chờ [603] → [605] → «Back»×2 → đọc credit.
- Script tự tạo lại session, mở khoá, đóng 2 paywall; **tự dừng nếu gen OK mà credit không giảm** (báo user, không đoán). Máy: USB, Auto-Lock Never, không ai chạm.
- Thứ tự khi mua có cộng lượt: cạn ở Free → E12 (credit 1) → 304/305/306 (credit 0) → MỚI mua → chùm case cần sub. Test xong gen hết lượt dư về 0 rồi mới đóng round.
- `gen_drive_2026-08-27.py`: drive 1 lượt gen thật.

## 7. Case mạng — Network Link Conditioner (không mitmproxy, không Airplane)
```bash
/usr/bin/python3 templates/net_drive_2026-08-25.py nlc "100% Loss"          # mất kết nối
/usr/bin/python3 templates/net_drive_2026-08-25.py nlc "Very Bad Network"   # mạng yếu
/usr/bin/python3 templates/net_drive_2026-08-25.py nlcstate                 # verify
/usr/bin/python3 templates/net_drive_2026-08-25.py nlc off                  # BẮT BUỘC trả mạng
```
- Settings ▸ Developer ▸ Network Link Conditioner; Switch Enable tap x≈331,y≈157; query `type == 'XCUIElementTypeSwitch' AND name == 'Enable'`.
- NLC không tạo được 5xx → case đòi mã lỗi ghi rõ «ép bằng timeout», không chấm như đã verify mã.

## 8. Ghi kết quả & report
- Đầu ra DUY NHẤT: HTML «testcase + report» (skill `gen-testcase-html`): report trên, bảng 9 cột dưới (ID · Feature · Case · Description · Preconditions · Step · Expected · Actual · Status Test). Ghi verdict NGAY sau mỗi case. Không json, không Excel, không Google Sheets.
- Màu: Pass xanh · Fail đỏ nhạt · N/A xám · Blocked cam · Skip vàng · Chờ = ô trống nền #e6edf5. Case chạy round này đánh ● và `<cũ> → <mới>`.
- Lưu: `Tester/Testcase/<FEATURE>/{Testcase + Report, Plan, Evidence}/`, tên `TC-Report_<SpecID>_<Feature>_<YYYY-MM-DD>.html`.
- Report chỉ khi round xong; 5 chỉ số % (đã cover / chưa cover / đã chấm / Pass trên số đã chấm / Fail trên số đã chấm) + thời gian tách «đụng device / không đụng device» (đo bằng mtime ảnh/file, không ước lượng).
- Trước khi chốt: đếm số case file gốc vs số dòng report — lệch phải giải thích từng dòng.
