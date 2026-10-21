# Chạy, chấm, report, bàn giao

Repo: `R=~/Downloads/IIP055-Genius-IOS-2.9.0`. Mọi lệnh chạy từ `$R`.

## 0. Tạo plan dir cho lượt mới
```bash
cd ~/Downloads/IIP055-Genius-IOS-2.9.0
P=plans/$(date +%y%m%d-%H%M)-genius-<ver>-event-tracking-<man>-autotest
mkdir -p $P/app-backup $P/runs $P/evidence
cp iosApp/Core/Tracking/AnalyticsTracker.swift $P/app-backup/
cp iosApp.xcodeproj/project.pbxproj $P/app-backup/project.pbxproj.backup-$(date +%y%m%d)
cp ~/Downloads/<spec>.xlsx $P/
```

## 1. Viết suite cho màn mới (từ template)
1. Copy `templates/Genius290EventTrackingLibraryUITests.swift` → `iosAppUITests/Genius<Ver>EventTracking<Man>UITests.swift`; đổi tên class + env gate (vd `RUN_G290_ET_<MAN>`).
2. Giữ nguyên `setUpWithError` (EVENT_SINK_PATH + ETSINK), `step()`, `note()`, `tapText()`, `at()`.
3. Mỗi test = 1 nhóm thao tác có điều kiện giống nhau: `test01` không tốn credit → `test02+` cần sub/credit → test xoá thật cuối cùng.
4. Mỗi thao tác cần chấm: `step("<ten_buoc>")` NGAY TRƯỚC thao tác; quan sát UI → `note()`; ảnh bằng chứng → `snap("ET — …")`; kết thúc `step("end")`.
5. Sau Generate luôn chặn paywall (`guard !paywall.exists`). Label UI lấy từ `.xcstrings` (en).
6. Đăng ký file: `ruby scripts/add-test-files.rb iosAppUITests iosAppUITests/<File>.swift`.
7. Copy `templates/run-genius-290-event-tracking-library.sh` → `scripts/run-genius-<ver>-event-tracking-<man>.sh`, sửa `G290_OUT` mặc định + gate + tên class.

## 2. Build + chạy
```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export G290_UDID=00008101-001A4C921E11001E
export G290_OUT=$PWD/$P/runs
scripts/run-genius-290-device-suite.sh build                       # build lại sau MỌI lần sửa Swift
# kiểm sub nếu sắp chạy case cần Generate
scripts/run-genius-290-device-suite.sh RUN_G290_SUB_PROBE Genius290SubscriptionLibraryUITests/test00_probeSubscriptionState sub-probe >/dev/null
grep -ho "SUBSTATE|[a-z]*" $(ls -t $G290_OUT/sub-probe-*.log | head -1) | tail -1
# chạy từng test (Library 21/10)
scripts/run-genius-290-event-tracking-library.sh test01_browseFilterSelectDeleteCancel
scripts/run-genius-290-event-tracking-library.sh test02_genTrayPendingAndRealDelete      # cần sub, ~9 phút
scripts/run-genius-290-event-tracking-library.sh test03_offlineLoadFailAndTrayRetry       # cần sub, bật/tắt Airplane
scripts/run-genius-290-event-tracking-library.sh test04_realDeleteNewestItem              # xoá thật 1 ô
```
- Lượt dài (test02) → chạy nền (`run_in_background`), trong lúc đó viết/sửa evaluator; chain luôn các test kế tiếp trong 1 lệnh: `(scripts/…test03…; scripts/…test04…) 2>&1 | grep -E "^run=|sink=|ETSTEP|ETNOTE"`.
- Output mỗi lượt trong `runs/`: `et-testNN-HHMMSS-HHMMSS.log` (ETSTEP/ETNOTE), `.jsonl` (event), `.xcresult`, `-shots/` (ảnh + `manifest.json`), `.verdicts`.
- Tên run: runner suite tự thêm `-HHMMSS` lần 2 → tên dạng `et-test01-101134-101135`.
- Lượt hỏng do script → `mkdir -p runs/invalid && mv runs/<run>* runs/invalid/` (evaluator chỉ lấy lượt mới nhất có `.jsonl` ở `runs/`).

## 3. Chấm
```bash
cd $P
python3 evaluate_event_tracking_library.py runs <spec>.xlsx \
  EventTracking_Genius_<ver>_<Man>_Result_$(date +%F).xlsx report-summary.json
```
- Dùng python có openpyxl (KHÔNG `-I` với python hệ thống; hoặc venv riêng + `-I`).
- Stdout: `rows: 34 {'PASS': 28, 'FAIL': 4, 'CHECK': 1, 'NA': 1}` + 1 dòng/row (row, event, param, status, actual, căn cứ).
- Màn mới: sửa `EXPECT`, `EXPECT_NONE`, `lib()` prefix, tuple test trong `RUN`, luật riêng (feature_name hằng, CHECK đặc thù).
- Tự rà sau khi chấm: dòng FAIL có phải lỗi script không (xem `Event log` sheet + ảnh); dòng NA ghi rõ cần dựng gì.

### Format file kết quả xlsx
- Giữ nguyên sheet spec gốc (11 cột A–K) + 3 cột: `Actual value (đo trên máy)` (vd `open_library=Library · reenter_library=Library`) · `Status` (tô: PASS C6EFCE, FAIL FFC7CE, CHECK FFEB9C, NA E7E6E6) · `Căn cứ kết luận` (vd `đúng ở 3 lần thao tác` / `bước X: \`param\`=v ngoài Allowed Values [...]`).
- Sheet `Event log`: Lượt chạy · Bước · Mốc (ms) · Event · Params · ts.
- Chạy nhiều lượt trên cùng file (kiểu Lensie): mỗi lượt thêm 1 bộ 3 cột, không đè lượt cũ.

### `report-summary.json`
`{"runs": {testNN: {name, notes{ETNOTE}, steps, events}}, "rows": [{row, event, param, allowed, type, source, status, actual, basis}]}`

## 4. Report HTML + artifact
```bash
# ảnh bằng chứng: chọn từ runs/<run>-shots/manifest.json, nén jpg vào evidence/<ten>.jpg
python3 -I -c "
import json,sys
m=json.load(open(sys.argv[1]+'/manifest.json'))
for t in m:
  for a in t.get('attachments',[]): print(a['exportedFileName'], a.get('suggestedHumanReadableName'))
" runs/<run>-shots | grep -v "Screen Recording\|kXCT"
sips -Z 700 runs/<run>-shots/<uuid>.png --out /tmp/x.png && sips -s format jpeg /tmp/x.png --out evidence/<ten>.jpg   # (lệnh nén jpg: chưa xác minh đúng y hệt 21/10)
python3 -I build_event_tracking_library_report.py report-summary.json evidence genius-<ver>-event-tracking-<man>-report.html
```
- `build_event_tracking_library_report.py`: `FINDINGS` (kết luận FAIL/CHECK/NA cho dev/PO, mỗi dòng dẫn chứng `file:line`) và `SHOTS` (tên ảnh evidence + caption) **viết tay** → sửa cho màn mới. Ảnh nhúng base64.
- Publish bằng Artifact tool (private), lần sau **publish đè cùng file** để giữ link. 21/10: https://claude.ai/artifact/XioYNy5T8GHsuAwE5z5UpJ.
- Report nêu: tổng (Pass/Fail/Cần xác nhận/Chưa test, mẫu số), lỗi tìm ra + nguồn code, câu hỏi PO, dòng chưa test + cần dựng gì, kiểm phụ (bắn trùng, EXPECT_NONE, time_to_action), "Bạn cần biết" (cách bắt event, sửa code app, credit/lượt mua đã tốn, dữ liệu đã xoá, trạng thái máy).

## 5. Bàn giao
- `handoff-event-tracking-<man>-trang-thai-va-cach-chay-tiep.md` trong plan dir: Kết quả (số + FAIL/CHECK/NA ngắn) · Cách chạy lại (lệnh build, từng test + điều kiện, chấm, report) · Luật đã học · Trạng thái máy (sub mua lúc nào, Airplane, dữ liệu đã xoá). Mẫu: `plans/261021-0944-…/handoff-event-tracking-library-trang-thai-va-cach-chay-tiep.md`.
- Cập nhật memory `~/.claude/projects/-Users-kieunga/memory/` (file màn + dòng index trong `MEMORY.md`).
- Cập nhật `README.md` của gói này (bảng "Đã chạy tới đâu") + thêm luật mới vào `rules-and-lessons.md`.
- KHÔNG commit/push.

## 6. Checklist nhanh
- [ ] Đọc `rules-and-lessons.md`, spec xlsx (ẩn/gạch), grep call site
- [ ] `DEVELOPER_DIR`, máy unlock + UI Automation, patch sink còn
- [ ] Suite + runner + evaluator đã chỉnh cho màn; build OK
- [ ] test không cần sub → kiểm sub → test cần sub → test xoá thật
- [ ] Chấm → rà FAIL (script vs app) → chạy lại nếu nghi flaky
- [ ] Evidence → report HTML → publish → handoff → memory
