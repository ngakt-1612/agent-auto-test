# Chạy, thu kết quả, report, đóng gói, bàn giao — Genius iOS 2.9.0

`<src>` = `/Users/kieunga/Downloads/IIP055-Genius-IOS-2.9.0`. Mọi lệnh chạy ở `<src>` với `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

## 1. Runner 1 suite
```bash
export G290_OUT=$PWD/plans/<plan-dir>/runs     # UI/Library: plans/261018-1110-…/runs ; AI Chat: plans/261020-1505-…/runs
scripts/run-genius-290-device-suite.sh build
scripts/run-genius-290-device-suite.sh <GATE> <Class>[/method] [run-name]
#   = env TEST_RUNNER_<GATE>=1 xcodebuild test-without-building -scheme iosAppUITestsOnly \
#       -only-testing:iosAppUITests/<Class>[/method] -resultBundlePath runs/<name>-HHMMSS.xcresult
```
Runner tự: chờ máy mở khoá (30 s × 30), `xcresulttool export attachments` → `runs/<name>-shots/` (+ `manifest.json`), lọc `^VERDICT|` → `runs/<name>.verdicts`, in `run=<name> rc=… verdicts=N`.
Dòng log máy đọc được: `VERDICT|<TC>|<PASS|FAIL|NA|CHECK|MISMATCH>|<actual>` · `SUBSTATE|premium|expired` · `PURGE|…empty=true` · `DUMP|…` · `PAYWALLCHAIN|…` · `OUTOFCREDIT|…` · `MYBALANCE|…` · `CANCEL|…` · `TOPUP|…`.

## 2. Bảng suite & gate
| Suite | Gate (`TEST_RUNNER_` +) | Credit | TC chính |
|---|---|---|---|
| Genius290ProbeUITests | RUN_GENIUS290_PROBE | 0 | dump nhãn |
| Genius290UpdateUIUITests (test01 tab/Create, test02 Home/Setting/Motion) | RUN_G290_UI | 0 | UI01–UI03 |
| Genius290ZeroCreditExtraUITests (upload fill, banner, tray, large text, offline, tab tím) | RUN_G290_EXTRA | 0 | UI03-001, UI04-001, LIB03-017… |
| Genius290LibraryReadOnlyUITests | RUN_G290_LIBRARY_RO | 0 | LIB01/02/03 (luôn Cancel) |
| Genius290LibraryPurgeUITests (test01 shift-delete, test02 purge→trống) | RUN_G290_SHIFT_DELETE · RUN_G290_PURGE | 0 | LIB03-019, REG01-002/004, LIB01-001/003 |
| Genius290GenerationUITests | RUN_G290_GEN | ~5 | BG01/BG02/BG03 |
| Genius290VideoBackgroundUITests (1 video/case) | RUN_G290_VIDEO_BG | ~7 | BG01-012, BG02, BG03 |
| Genius290LibraryDeleteUITests | RUN_G290_LIB_DELETE(2) | 2–5 | LIB03 xoá |
| Genius290EmptyLibraryMotionUITests | RUN_G290_EMPTY_MOTION | ~4 | LIB01-005, UI01-007, BG02-004/006/007 |
| Genius290SubscriptionLibraryUITests (test00 probe, test01 restore, test02 expired) | RUN_G290_SUB_PROBE · _SUB_RESTORE · _SUB_EXPIRED | 0 | LIB04-001..003 |
| Genius290RerunGenerationUITests / RerunLibraryUITests | RUN_G290_RERUN_GEN · RUN_G290_RERUN_LIB | ít | 9 case chạy lại 19/10, UI03-005 |
| Genius290TopupLibraryUITests (test02 nhận `TEST_RUNNER_LIB_SIG`) | RUN_G290_TOPUP | topup | LIB04-004 |
| Genius290CancelSandboxSubUITests | RUN_G290_CANCEL_SUB | 0 | dựng tiền đề |
| OnboardingToPaywallJourneyUITests (+ `TEST_RUNNER_ATTENDED_PLAN=Yearly`) | RUN_ATTENDED_PURCHASE | — | mua gói (tester nhập mật khẩu) |
| Genius290AiChatProbeUITests | RUN_G290_CHAT_PROBE | 0 | dump màn Chat |
| Genius290AiChatNoSubUITests (test01 chain, 02 empty/composer, 03 vibes, 04 902, 05 topup, 06 mua trên 236) | RUN_G290_CHAT_NOSUB | 0 / topup | CH01, CH02, CH03, VB, CH08-007 |
| Genius290AiChatWithSubUITests (test01–30) | RUN_G290_CHAT_SUB | 1/lần gửi | CH02–CH08, REG02 |

## 3. Queue chạy nền (mẫu: `templates/run-genius-290-day2-queue.sh`, `…ai-chat-nosub-queue.sh`)
Khung: `set -u` → `while pgrep -f "xcodebuild test-without-building"; do sleep 15; done` → `"$RUN" build || exit 1` → chuỗi `"$RUN" GATE Class/test name` (0 credit → mua gói → tốn lượt → phá trạng thái cuối) → `REPORT()` → (tuỳ chọn) vòng probe hết hạn 600 s × N → case cần hết hạn → `REPORT`.
```bash
nohup scripts/run-genius-290-<tên>-queue.sh > $G290_OUT/<tên>.out 2>&1 &
nohup caffeinate -dimsu -w $! >/dev/null 2>&1 &
# theo dõi: Monitor/tail lọc "run=|VERDICT|PURCHASE|DEVICE_LOCKED|TEST BUILD FAILED|report:|== |SUBPROBE|Traceback"
```
- In mốc `echo "== xong <phần>"` để queue sau `until grep -q` nối vào. In `PURCHASE_WAITING_FOR_PASSWORD` trước bước cần tester → báo user đúng lúc.
- Muốn đổi queue đang chạy: viết queue mới, chờ mốc, `pkill -f` queue cũ (không sửa file đang chạy).
- Dừng hết: `pkill -f run-genius-290-; pkill -f "xcodebuild test-without-building"`.

## 4. Thu & chấm
1. Sau mỗi run: đọc `runs/<name>.verdicts` + log; FAIL/NA/CHECK → mở ảnh `runs/<name>-shots/` (manifest map tên attachment → file).
2. Ghi đè có lý do vào `plans/<plan>/verdict-notes.json`:
```json
{"ui|TC-CH03-005": {"status": "FAIL", "actual": "…đo được…", "note": "lý do / file:line / spec §", "run": "<run-name tuỳ chọn để ghim ảnh>"}}
```
   Key luôn `ui|<TC ID>` (cả AI Chat). Xoá note cũ khi case có lượt thật mới.
3. Gom ảnh có tên TC vào `plans/<plan>/evidence/` (`<tên attachment> [<run>].png`) — script Python đọc `runs/*-shots/manifest.json`, chỉ lấy tên bắt đầu `TC-`/`probe`.

## 5. Report HTML
```bash
# UI + Library (title mặc định "Update UI + Library — 84 TC spec 2.9.0")
python3 scripts/build-genius-290-autotest-report.py plans/261018-1110-genius-290-automation-ui-image-video/runs \
  plans/261018-1110-genius-290-automation-ui-image-video/figma-frames \
  plans/261018-1110-genius-290-automation-ui-image-video/genius-290-autotest-report.html
# AI Chat
P=plans/261020-1505-genius-290-ai-chat-testcase-automation
G290_SUITE_TITLE="AI Chat — 105 TC spec 2.9.0" python3 scripts/build-genius-290-autotest-report.py $P/runs \
  plans/261018-1110-genius-290-automation-ui-image-video/figma-frames $P/genius-290-ai-chat-autotest-report.html
sed -i '' 's#<title>[^<]*</title>#<title>Genius 2.9.0 AI Chat Autotest</title>#' $P/genius-290-ai-chat-autotest-report.html
```
- Đầu vào cạnh `runs/..`: `spec-cases.json` (`{"ui": {TC: {title, expected, feature, pre, data, action, priority}}}`), `verdict-notes.json`, `figma-map.json` (`{"ui|TC": "page-06-f03"}`; AI Chat = `{}`), `report-summary.json` (`{"html": "<header…KPI…FAIL/Lệch spec panels>"}` — **viết tay** mỗi lần chốt).
- Template `scripts/genius-290-report-template.html` (`{{SUMMARY}}`, `{{SECTIONS}}`; IBM Plex, light/dark, lọc, lightbox). Ảnh nhúng base64 (sips → JPEG) → 1 file.
- Cột bảng: TC | Kịch bản | Testcase (Precondition/Data/Action) | Expected (spec) | Kết quả chạy thật (+note) | Figma 2.9.0 | Máy thật | Verdict.
- Figma: `tools/render_pdf_pages.swift` (PDFKit) + `tools/split_figma_frames.swift` trong plan 261018 → 109 frame.
- Publish: Artifact tool với **cùng file path** → cùng URL (UI: `SitqmU4GuuCYQqe1aW7c6F`, Chat: `9pNbWtWa65uqxjv2K22CFP`; private, user tự Share). Trước khi publish phải đọc lại summary (từng sai % 83→86).

## 6. Kết quả vào xlsx
Đợt 2.9.0 **không** điền cột PASS/FAIL vào 2 file TC (kết quả ở report). Nếu user yêu cầu: copy file → `TC_…_ket_qua.xlsx` (backup trước), map `TC ID` (cột J) → status/actual từ kết quả cuối (notes > lượt mới nhất, NA không đè), ghi cột I (+ cột actual/ghi chú) bằng openpyxl `python3` (không `-I`). (chưa xác minh — chưa làm cho đợt này)

## 7. Đóng gói zip
```bash
cd <src>
# UI + Library (bỏ xcresult/mp4/shots thô → ~1 GB chủ yếu evidence)
Z=~/Downloads/Genius-2.9.0-autotest-UpdateUI-Library-<yymmdd>.zip; rm -f $Z
zip -qr $Z plans/261018-1110-genius-290-automation-ui-image-video scripts/*genius-290* iosAppUITests \
  -x "*.xcresult/*" "*/runs/*-shots/*" "*.mp4" "*.DS_Store"
# AI Chat
Z=~/Downloads/Genius-2.9.0-autotest-AI-Chat-<yymmdd>.zip; rm -f $Z
zip -qr $Z plans/261020-1505-genius-290-ai-chat-testcase-automation iosAppUITests/Genius290AiChat*.swift \
  iosAppUITests/Genius290CancelSandboxSubUITests.swift scripts/build-genius-290-autotest-report.py \
  scripts/run-genius-290-device-suite.sh -x "*.xcresult/*" "*/runs/*-shots/*"
(cd ~/Downloads && zip -q $Z TC_Genius_v2.9.0_AI_Chat.xlsx); unzip -l $Z | tail -1
```
Zip đầu từng ~10 GB vì mp4/xcresult → luôn loại. Gói nên có: TC xlsx, report HTML, handoff, plan dir (spec-cases, notes, summary, runs/*.log|*.verdicts, evidence), code test, script, `View+TestIdentifier.swift`, report identifiers. Tên: `Genius-2.9.0-autotest-<Scope>-<yymmdd>.zip`.

## 8. Handoff (file trong thư mục plan)
Tên: `handoff-<scope>-autotest-trang-thai-va-cach-chay-tiep.md`. Mục bắt buộc:
1. `Cập nhật: <ngày giờ> · Máy · Source · build` ; **Kết quả (chốt …)**: x/N có kết quả · PASS · FAIL · lệch spec · cần xem · N/A · chưa chạy; link report; zip; danh sách FAIL (TC — mô tả — `file:line`), lệch spec, cần xem.
2. **Trạng thái máy lúc dừng:** gói (có/không, mua lúc), topup, lượt, quyền Photos, Reduce Transparency, queue nào đang/không chạy.
3. **Việc tiếp:** từng bước có lệnh chính xác (build, gate, class/test, thứ tự, bước cần tester).
4. **Bảng bị chặn:** TC | chặn bởi | cách mở.
5. **Luật rút ra** trong buổi.
Kèm cập nhật memory `~/.claude/projects/-Users-kieunga/memory/genius-v290-testcase-scope.md`.

## 9. Việc tiếp AI Chat (từ handoff 20/10 — 8 chưa chạy + 6 cần xem)
1. `SUB_PROBE` xác định gói/lượt hiện tại (21/10 máy đã dùng cho event tracking — chưa xác minh trạng thái).
2. Có gói + lượt: `RUN_G290_CHAT_SUB Genius290AiChatWithSubUITests/` → `test06_sendForSelected` (CH07-004) · `test16_keepDraftWhenViewing` (CH08-009/010) · `test17_offlineMidGenerationAndRetry` (CH05-002/003) · `test27_photoPermissionDenied` (CH02-015) · `test28_reduceTransparency` (CH08-002) · `test09_helloTextOnly` (CH02-021) · `test02_resultAndViewer` (CH06-007 toast).
3. Hết lượt: `test29_getMoreOpensTopup` (CH03-010) → `test26_outOfCreditDialogButtons` (CH03-009 qua Maybe later; mở sẵn màn topup cho tester mua).
4. Cần "chưa mua gói": `scripts/run-genius-290-ai-chat-nosub-queue.sh` (huỷ gói — tester nhập mật khẩu + Cancel Subscription → Confirm; probe 10 phút × 18; rồi `Genius290AiChatNoSubUITests/test04` CH08-007, `test05` CH03-006 cần ≥1 topup, `test06` CH03-007 tester mua gói trên 236).
5. Cuối cùng (gỡ app, mất lịch sử Chat): CH02-014 (quyền Photos chưa hỏi), CH06-012 (kết quả chưa tải + mất mạng).
6. Dọn máy: `test30_restoreDeviceSettings`; dựng lại report (§5), republish, zip, handoff, memory.
