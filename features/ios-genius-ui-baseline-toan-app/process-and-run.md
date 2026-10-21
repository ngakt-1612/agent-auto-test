# Quy trình & lệnh chạy — Genius UI toàn app

## Ba lane
| Lane | Ai/đâu | Phủ gì | Thời gian | Khi |
|---|---|---|---|---|
| 1 Event contract | Simulator, unit test | 143 event ✓: đúng tên + bộ param key trong code (KHÔNG hành vi) | build đầu ~7′, sau <1′ | mỗi build |
| 2 UI sweep | iPhone thật + Appium | 80 màn: ảnh + cây accessibility → diff | ~20–30′ (dự kiến) | mỗi build |
| 3 Business logic | user / plan feature | IAP, credit, sub, edge — Expected Confluence | tuỳ | chỉ vùng có diff |
Full regression Lane 3 chỉ 1 lần trước khi submit store.

## Quy trình theo lô (mục 11.1 — testcase trước, test sau)
1. Ảnh Figma đủ 156 node trong `UI-Figma/<Section>/` (✅ 19/09).
2. Mở từng ảnh, đặt tên màn, chép Expected → file testcase HTML `Testcase+Report/Testcase+Report_UI-<Section>_<YYYY-MM-DD>.html` (lô I2V, I2I xong).
3. Dò đường đi tới từng màn trên máy thật → điền cột đường đi (thành kịch bản).
4. `ui_sweep.py` chạy theo kịch bản, chụp ảnh + cây accessibility → `Testcase+Report/Evidence/baseline_<ver>_<ngày>/` (chưa viết).
5. `ui_diff.py` so build này với build trước, báo chỗ đổi (chưa viết).
Chỉ làm lô tiếp khi user bảo.

### Sinh testcase UI (mục 11.6)
- Khung `skill_gentestcase` (UTM): dựng SR ledger trước; mỗi TC truy ≥1 SR; gộp C3; tách fault C4; SR-INT cho gián đoạn/vòng đời C4b; prune E1; cổng E2. (Skill tương đương máy này: `anthropic-skills:qa-testcase-generator`.)
- HTML, **9 cột**: `ID · Feature · Case · Description case · Preconditions · Step · Expected Result · Actual Result · Status Test` + bảng Traceability cuối file. ID số tịnh tiến từ 1.
- Lô có paywall: BẮT BUỘC đọc `sub_policy.md` (Genius `has_payment = true`). Không đọc `ads_policy.md` (Genius không có SDK ads — đo bằng grep).
- Caption ảnh ghi node Figma; mỗi Expected đọc được trên node đó (luật 12.1–12.4, 12.6).
- Sau khi áp luật mới: rà lại các lô đã sinh trước (UI-I2V sinh trước 22/09).

## Build & cài (máy thật)
```bash
SRC="<source Genius 2.6.0>"            # đường dẫn theo máy, không copy cứng
UDID=00008120-001A20320282201E         # iPhone Tester 2
cd "$SRC"
xcodebuild -project iosApp.xcodeproj -scheme iosApp -configuration Debug \
  -destination "id=$UDID" -allowProvisioningUpdates \
  -derivedDataPath ~/GeniusBuild/DerivedData-device \
  -disableAutomaticPackageResolution build
xcrun devicectl device install app --device "$UDID" \
  ~/GeniusBuild/DerivedData-device/Build/Products/Debug-iphoneos/Genius.app
```
Ghi `CFBundleShortVersionString` + `CFBundleVersion` vào tên thư mục baseline.

## Lane 1 — event contract
```bash
xcrun simctl boot E5ED3EDC-5C92-423D-8AE9-F9AE455F7B33     # iPhone 17 Pro — PHẢI boot trước
cd "$SRC"
./scripts/run-event-tests.sh --contracts "iPhone 17 Pro"   # chỉ contract
./scripts/run-event-tests.sh --all "iPhone 17 Pro"         # + UI journey
# report /tmp/event-coverage.html → MAIN/UI-BASELINE/Testcase+Report/EventCoverage_Lane1_<ngày>.html
xcrun simctl shutdown E5ED3EDC-5C92-423D-8AE9-F9AE455F7B33
```
Script tự sinh lại contract test từ `events.json`. 18 event `showcase_*` tên nội suy động — không contract-test được.

## Lane 2 — UI sweep (khi WDA gỡ xong)
```bash
PATH="/opt/homebrew/opt/node@22/bin:$PATH" appium &       # Appium 3.6.0 + xcuitest 12.7.0
python3 tools/appium_drive.py create                      # session → /tmp/genius_appium_session.txt
python3 tools/ui_sweep.py --out MAIN/UI-BASELINE/Testcase+Report/Evidence/baseline_<ver>_<ngày>/
python3 tools/ui_diff.py --old <baseline cũ> --new <baseline mới> --figma figma-map.json
```
`ui_sweep.py`/`ui_diff.py` là lớp mỏng bọc `appium_drive.py` (đã lấy được page source + screenshot) — template ở `../ios-genius-subscription-sandbox/templates/appium_drive.py`.

## Figma
- File `DVnwame4JHVgijSAdZKEjM`, node `19986:836`. Danh sách 156 node ↔ section ↔ tên file: `templates/figma_worklist_156_nodes.json`; map: `templates/figma-map.json`.
- Tải ảnh qua REST (không tốn quota MCP): `echo '<token>' > ~/.figma-token` (user tạo) rồi `python3 templates/figma_fetch_rest.py` — chỉ kéo phần còn thiếu, PNG full-res vào `UI-Figma/UI-<Section>/`.
- 16 section: I2I 14 · I2V 14 · Enhance 13 · Motion-Control 16 · Restore-Remove-Object 24 · World-Cup-Looks 15 · Rating-us 12 · Ngoai-section 13 · Home-moi 7 · Gen-fitting 6 · New-subcription 6 · Gen-anh 5 · Gen-video 5 · World-Cup-Edition 3 · Log-out 2 · Thumb 1.
- 8 design frame thật (New subcription 3 · Log out 2 · Rating us 1 · 2 ngoài section) — baseline Figma pixel/layout chỉ áp cho 8 màn này.

## Lưu file (user chốt 19/09 — folder chỉ 3 thứ)
```
MAIN/UI-BASELINE/
├─ Plan_UI-Baseline-ToanApp_2026-09-19_Genius.html
├─ UI-Figma/ (00_Doc-truoc.html · _worklist.json · _dedupe.json · _fetch_rest.py · UI-<Section>/)
└─ Testcase+Report/ (Testcase+Report_UI-<Section>_<ngày>.html · EventCoverage_Lane1_<ngày>.html · Evidence/)
```
Mọi file gắn `_YYYY-MM-DD`, không ghi đè; nháp/diff rời không để trong folder. Verdict ghi thẳng vào HTML ngay sau mỗi case (không json).

## Checklist đóng một lượt sweep
- Build đúng lệnh, BUILD SUCCEEDED, cài + launch được; version ghi vào tên baseline.
- Lane 1 xong, lưu EventCoverage; event fail có lý do.
- Đủ 80/80 màn, 77 điểm chạm (thiếu phải ghi vì sao).
- Thang chấm đúng; không Expected tự suy.
- Màn có diff đã mở testcase feature (Lane 3) hoặc ghi lý do hoãn.
- Tổng case các feature không đổi (SUB 53 · I2V 58).
- Cần mua/dev/BA → đã ping Discord (đủ 5 bước bàn giao nếu là mua).
