# Cơ chế bắt event trên iPhone thật (sink JSONL)

Đã chạy thành công 21/10/2026 (Library + gen_tray). Ý tưởng: app tự ghi mọi event ra file JSONL trong sandbox của chính nó → test in mốc thời gian từng bước → script kéo file về → evaluator ghép event với bước.

```
XCUITest (máy thật)                    App Genius (máy thật)                 Mac
 launchEnvironment EVENT_SINK_PATH=~/Documents/et-<test>-<epoch>.jsonl
 print ETSINK|Documents/<file>   ──►   AnalyticsTracker.track()
 print ETSTEP|<bước>|<epoch ms>        ├─ Analytics.logEvent (Firebase)
   (NGAY TRƯỚC thao tác)               └─ recordToSink → append JSON line
 print ETNOTE|<key>|<value>                {"name","params"(string hoá),"ts"(ms)}
                                                         devicectl copy from --source Documents
                                                         → runs/<run>.jsonl + runs/<run>.log
                                                         → evaluate_*.py
```

## 1. Sink trong app — `iosApp/Core/Tracking/AnalyticsTracker.swift`
- `track(name, parameters)` → `Logger.d("Apero_Key", …)` + `Analytics.logEvent` + `recordToSink`.
- Sink **chỉ bật khi có env `EVENT_SINK_PATH`** (bình thường inert). Mỗi dòng: `{"name":..., "params":{k: String}, "ts": epoch_ms}`. Bool → `"true"/"false"`, số → chuỗi.
- Bản gốc đọc path nguyên văn (thiết kế cho simulator, ghi host `/tmp`). Trên máy thật app KHÔNG ghi được `/tmp` của Mac → đã patch 1 dòng cho nhận `~/…` (resolve trong sandbox app):

```swift
private static var sinkPath: String? =
    ProcessInfo.processInfo.environment["EVENT_SINK_PATH"].map { ($0 as NSString).expandingTildeInPath }
```
- Patch: `templates/analytics-tracker-sink-tilde-expand.patch`. Bản gốc: `plans/261021-0944-…/app-backup/AnalyticsTracker.swift`.
- Repo mới / bản code mới: kiểm patch còn không (`grep -n expandingTildeInPath iosApp/Core/Tracking/AnalyticsTracker.swift`); mất thì áp lại, backup bản gốc vào `app-backup/` của plan, báo user là đã sửa 1 dòng code app (chỉ có tác dụng khi chạy test).

## 2. Phía test (XCUITest) — xem `templates/Genius290EventTrackingLibraryUITests.swift`
```swift
let sink = "et-\(testMethodShort)-\(Int(Date().timeIntervalSince1970)).jsonl"
app.launchEnvironment["EVENT_SINK_PATH"] = "~/Documents/\(sink)"
print("ETSINK|Documents/\(sink)")
app.launch()
private func step(_ label: String) { print("ETSTEP|\(label)|\(Int64(Date().timeIntervalSince1970 * 1000))") }
private func note(_ key: String, _ value: String) { print("ETNOTE|\(key)|\(value.replacingOccurrences(of: "\n", with: " "))") }
```
- `step()` in **ngay trước** thao tác của bước đó. Event thuộc bước = `ts ∈ [mốc bước, mốc bước kế)`. Bước cuối luôn `step("end")` để đóng cửa sổ.
- `note()` ghi quan sát UI (text đang hiện, số ô, trạng thái khay) → dùng làm căn cứ trong report.
- Gate suite bằng env: `XCTSkipUnless(env["RUN_G290_ET_LIB"] == "1")`; truyền vào bằng `TEST_RUNNER_RUN_G290_ET_LIB=1` trước `xcodebuild` (tiền tố `TEST_RUNNER_` bắt buộc).
- Ngôn ngữ app ép tiếng Anh: `-AppleLanguages (en) -AppleLocale en_US` → label ổn định. Label lấy từ `iosApp/Resources/**.xcstrings` (key `library_filter_*`, `generation_status_*`…).
- Suite này dùng `app.launch()` 1 lần ở `setUp` (sink theo file nên launch không làm mất event). Trong test KHÔNG `launch()` lại — dùng `app.activate()` sau khi sang Settings.

## 3. Kéo file về Mac
```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
COREDEVICE=3869BBF0-7BD4-596F-9389-E70C49E759D8      # id CoreDevice (devicectl), KHÁC UDID xcodebuild
BUNDLE=aiphotogenerator.aifaceeditor.aivideogenerator.aibeauty
SINK="$(grep -o 'ETSINK|[^ ]*' "$LOG" | tail -1 | cut -d'|' -f2 | tr -d '\r')"   # log XCUITest có \r cuối dòng
rm -rf "$OUT/pull" && mkdir -p "$OUT/pull"
xcrun devicectl device copy from --device "$COREDEVICE" --domain-type appDataContainer \
  --domain-identifier "$BUNDLE" --source Documents --destination "$OUT/pull"
cp "$OUT/pull/$(basename "$SINK")" "$OUT/$NAME.jsonl"
```
- `copy from` với `--source Documents/<file>.jsonl` **không chạy** → phải kéo cả thư mục `Documents` rồi lấy file của lượt này.
- Liệt kê file trong container: `xcrun devicectl device info files --device $COREDEVICE --domain-type appDataContainer --domain-identifier $BUNDLE`.
- Đã gói sẵn trong `templates/run-genius-290-event-tracking-library.sh`.

## 4. Xem nhanh event của 1 lượt
```bash
python3 -I -c "
import json,sys
for l in open(sys.argv[1]):
  e=json.loads(l); n=e['name']
  if n.startswith(('library_','gen_tray','quota_check','iap_view')): print(e['ts'], n, e['params'])
" runs/et-test02-*.jsonl
grep -E 'ETSTEP\||ETNOTE\|' runs/<run>.log | awk '!s[$0]++'   # mốc + ghi chú (log có thể in trùng)
```
`quota_check` có `decision` (`allow…`, `block_no_sub`, `block_out_of_quota`) → cách chắc nhất biết Generate có bị chặn sub/credit không.

## 5. Evaluator — `templates/evaluate_event_tracking_library.py`
```
python evaluate_event_tracking_library.py <runs-dir> <spec.xlsx> <out.xlsx> <out-summary.json>
```
- `load_run("et-testNN")`: lấy log **mới nhất** có `.jsonl` cùng tên; parse `ETSTEP` (bỏ trùng), `ETNOTE`.
- `window(step)`: tìm bước ở các lượt, **ưu tiên lượt sau** (test04 > test02 khi trùng tên bước) → list event trong cửa sổ.
- `EXPECT = [(event, bước, {param: giá trị kỳ vọng})]` — viết tay theo kịch bản; `EXPECT_NONE` = bước KHÔNG được bắn (chạm lại filter đang chọn).
- Đọc spec: cột C (event, kế thừa ô gộp), F (param), H (allowed, tách `|`), I (type), G (source).
- Mỗi dòng spec kiểm: có bắn ở mọi bước kỳ vọng · đúng 1 lần/thao tác · có param · = giá trị kỳ vọng · ∈ Allowed · đúng type (int/long/bool) · luật riêng (`feature_name` của `library_*` = `Library`; `error_code` không rỗng; `time_to_action` lệch ≤1500 ms so với dwell đo từ `library_view` gần nhất).
- Không bước nào chạy → `NA` + "Chưa chạy được bước kích hoạt: …".
- Xuất: thêm 3 cột `Actual value (đo trên máy)` · `Status` (tô màu) · `Căn cứ kết luận` sau cột cuối spec + sheet `Event log` (lượt, bước, mốc, event, params, ts — chỉ prefix màn đang test).
- Màn mới: sửa `EXPECT`, `EXPECT_NONE`, hàm `lib()` (prefix event), tuple test trong `RUN = {…}`, luật riêng.

## 6. Cách khác (đã dùng / bị loại)
| Cách | Trạng thái |
|---|---|
| Log `Apero_Key` qua `xcrun devicectl device process launch --console --terminate-existing <bundle> > phien.log` (05/10 AI Chat) | Bắt được 27–28 event; nhưng chạy song song XCUITest dễ xung đột launch, phải parse text. Dự phòng |
| Xcode Report navigator (⌘9) → Console | Luật cũ sổ tay Lensie (06/10) — **đã thay** bằng sink JSONL (user chốt 21/10). Chỉ dùng để soi thêm khi debug |
| `EventSinkClient.swift` đọc `/tmp/app-events-*.jsonl` | Chỉ simulator (`scripts/run-event-tests.sh`, contract test) — chỉ là gate cho dev, không dùng để chấm |
