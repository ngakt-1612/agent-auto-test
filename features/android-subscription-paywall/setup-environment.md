# Setup môi trường — Android Sub/Paywall autotest

## 1. Host (Mac của user)

| Thứ | Ở đâu / lệnh |
|---|---|
| adb | `~/Library/Android/sdk/platform-tools/adb` — runner gọi đường dẫn này; shell: `export PATH=$PATH:~/Library/Android/sdk/platform-tools` |
| build-tools | `~/Library/Android/sdk/build-tools/36.0.0/` (`dexdump`, `aapt2`). `aapt`/`jadx` **không** có trong PATH |
| jadx (khi cần đọc code APK) | 14/10 tải jadx 1.5.1 vào scratchpad (tạm, đã mất) và chạy với `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`. Không có Java hệ thống |
| Python | venv trong repo: `~/magic-ai-sub-e2e/venv` (luôn gọi `./venv/bin/python`). `requirements.txt`: openpyxl 3.1.5, pytest 8.3.4, pillow 11.0.0, pyyaml 6.0.2 |
| Driver UI | **Không** dùng uiautomator2/Appium/Maestro. Runner gọi thẳng `adb shell uiautomator dump` + `input tap` + `screencap` (`tc_runner/core/adb_driver.py`) |

Cài trên máy mới:
```bash
git clone https://github.com/ngakt-1612/903Magic-ai.git && cd 903Magic-ai   # hoặc dùng ~/magic-ai-sub-e2e
python3 -m venv venv && ./venv/bin/pip install -r requirements.txt
./venv/bin/python -m pytest tests/ -q        # phải xanh (451 pass lúc 16/10). Đỏ = KHÔNG chạy máy thật
```
APK **không** nằm trong git: chép vào `~/Downloads/` đúng tên trong `apk_path` của config.

## 2. Thiết bị đã dùng

| Vai | Máy | Serial | Ghi chú |
|---|---|---|---|
| A (chính) | Samsung SM-A135F, Android 14, 1080x2408 | `R58TB198BNN` | Đổi được giờ bằng adb không cần root |
| B | Pixel 6 | `18311FDF60085N` | Case 46 cũ (02/10) |
| B | Pixel 4 | `99261FFAZ0077C` | Case 35 ADA903 PASS 10/10 |
| B | Oppo CPH2375, 720x1612 | `f3466cdb` | Play trên Oppo trả bounds `[0,0][0,0]` mọi node → runner không bấm được, phải tap toạ độ / huỷ tay. Hay rớt USB debugging khi khoá màn |

Account test: `test.pro.apero@gmail.com` (License Tester — dialog mua hiện "Test card, always approves", không trừ tiền).
Mật khẩu **không** lưu ở đây — hỏi user khi cần đăng nhập.

## 3. Chuẩn bị máy (mỗi lần cắm)

```bash
export A=R58TB198BNN B=<serial máy B>
adb devices                                                   # phải thấy "<serial> device"
for S in $A $B; do adb -s $S shell svc power stayon usb; done  # BẮT BUỘC trước nhóm chờ gia hạn
adb -s $A shell pm list packages -d | grep crawl              # crawler nội bộ phải đang disabled
adb -s $A shell pm disable-user --user 0 com.apero.testcrawldata   # nếu chưa
adb -s $A install -r -t ~/Downloads/<apk>                     # cài cả máy A và B
```
- Ngôn ngữ máy **English** (cả A và B) — nhãn trang Play phải tiếng Anh, runner đọc theo chữ.
- Máy B: Play Store → avatar → chọn đúng account test. Thiếu app trên B: `adb -s $A shell pm path <pkg>` → `adb pull` → `adb -s $B install-multiple ...`.
- Có ít nhất 1 ảnh chân dung trong Gallery (ADA903 select_photo_generate cần chọn ảnh).
- `dev.mobile.maestro` trên máy giành UiAutomation → `uiautomator dump` chết exit 137. Gỡ/kill Maestro trước khi chạy (đo 09/09).
- Màn tự tắt giữa lượt → focus rơi vào NotificationShade, dump sai màn → luôn `stayon usb`.

## 4. Đưa account về FREE (reset sub)

Trạng thái gói nằm trên **Google account**, không trong app: gỡ/cài app **không** về Free.
1. Kiểm: trên máy mở `https://play.google.com/store/account/subscriptions` (danh sách sub của MỌI app — tìm đúng dòng `play_row` của app).
   Hoặc đọc bằng runner:
   ```bash
   cd ~/magic-ai-sub-e2e; ./venv/bin/python - <<'EOF'
   import os
   from tc_runner.core import adb_driver, app_config, play_store, sub_state
   cfg = app_config.load("apps/magic-ai.json", "tc/TC_Subscription_Android_ADA903_v2.xlsx")
   d = adb_driver.Driver(cfg, serial=os.environ["A"], artifacts_dir="artifacts/preflight", ad_cfg=cfg.ads)
   print(sub_state.from_play(play_store.PlayStore(d, cfg).read("preflight")))   # FREE | ACTIVE | CANCELLED | KHONG_BIET
   EOF
   ```
   `KHONG_BIET` = Play đang "Server error" → chờ vài phút, đọc lại; **không** coi là FREE.
2. Còn gói → huỷ (case/runner tự huỷ được với `--cho-free-phut`, hoặc tay trên Play) → chờ hết kỳ: Weekly/Monthly ~5', Yearly ~30'.
3. **Cache app**: app vừa từng mua có thể vẫn coi user là Premium (Artspire 07/10: lần cài đầu không hiện paywall). → `adb uninstall <pkg>` rồi cài lại sạch.
4. Ghi lại sub của **app khác** trên account trước lượt (account dùng chung) — không nhận bừa. Báo nhóm trước khi mua/huỷ.

## 5. Lệnh tiện ích đã dùng

```bash
# Thông tin APK / activity chính
~/Library/Android/sdk/build-tools/36.0.0/aapt2 dump badging <apk> | head -5
adb -s $A shell cmd package resolve-activity --brief <pkg>
# Tìm chỗ mở paywall trong code (không cần jadx): giải nén APK rồi
~/Library/Android/sdk/build-tools/36.0.0/dexdump -d classes*.dex | grep -n "VslBillingActivity\|paywall_placement"
# UI dump + ảnh
adb -s $A shell uiautomator dump /sdcard/u.xml && adb -s $A pull /sdcard/u.xml <out>.xml
adb -s $A exec-out screencap -p > <out>.png
# Analytics source của paywall (Firebase debug)
adb -s $A shell setprop log.tag.FA VERBOSE; adb -s $A shell setprop log.tag.FA-SVC VERBOSE
adb -s $A shell setprop debug.firebase.analytics.app <pkg>; adb -s $A logcat -c
adb -s $A logcat -d | grep -o "name=iap_view,.*source=[A-Za-z0-9_]*"
# Log Billing của app (tag PurchaseEG ở app VSL)
adb -s $A logcat -s PurchaseEG
# Mô phỏng Play Store khởi động lại (bug Billing)
adb -s $A shell am force-stop com.android.vending
# Xoá data app (RC quota đọc 1 lần/ngày, Linguza) — sub vẫn còn vì nằm ở Play
adb -s $A shell pm clear <pkg>
# Đổi ngày máy (Samsung A14, không root) — dùng cho case reset lượt theo ngày
adb -s $A shell cmd time_detector set_auto_detection_enabled false
adb -s $A shell cmd alarm set-time <epoch_ms>
adb -s $A shell cmd alarm set-time $(($(date +%s)*1000)); adb -s $A shell cmd time_detector set_auto_detection_enabled true   # trả lại
```

## 6. Input sản phẩm cần xin trước (thiếu → case chỉ ghi nhận/N/A)
1. Spec/checklist Subscription (hoặc TC cũ của app). 2. Bảng giá USD từng gói (ảnh Play Console/checklist được).
3. Ảnh/Figma paywall (1 ảnh đủ để mã hoá quyền lợi). 4. Danh sách placement + vị trí hiển thị (thiếu → tự trích từ APK, PO xác nhận).
5. Link Privacy/ToS **từ PO**, không chép từ app. 6. Chức năng trả phí (sub user được gì, giới hạn lượt).
Ví dụ user đã đưa: `paywall-ada903.jpeg`, `goi-gia-package-ada903.png`, `paywall-aip918.png`, `goi-gia-package-aip918.png` trong `~/Downloads/`.
