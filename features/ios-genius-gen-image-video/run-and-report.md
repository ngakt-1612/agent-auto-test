# Chạy & báo cáo — Genius I2I / I2V

Biến `$COMMON`, `$UDID`, `$BID` xem `setup-environment.md` §1. Mọi gate thêm tiền tố `TEST_RUNNER_` và đặt **trước** `xcodebuild`.

## 1. Chạy 1 suite (khuyên dùng runner script)

```bash
# copy templates/run-device-suite.sh vào <project>/scripts/, sửa: OUT (thư mục runs của plan),
# DD (derivedData — bản gốc trỏ scratchpad session cũ, PHẢI đổi), UDID, scheme, TEAM
scripts/run-device-suite.sh build
scripts/run-device-suite.sh <GATE> <TestClass>[/test_method] [ten-luot]
# ví dụ
scripts/run-device-suite.sh RUN_VIDEO_RESULT_SUITE VideoGenerateResultUITests video-result
```

Script làm: `env TEST_RUNNER_<GATE>=1 xcodebuild test-without-building … -resultBundlePath`, nếu gặp
"Timed out while enabling automation mode" thì in `DEVICE_LOCKED` và thử lại (30 × 30s), sau đó export
ảnh `xcresulttool export attachments` → `<run>-shots/`, lọc dòng `VERDICT|` → `<run>.verdicts`.

Lệnh tay tương đương:
```bash
TEST_RUNNER_RUN_VIDEO_RESULT_SUITE=1 xcodebuild test-without-building $COMMON \
  -resultBundlePath runs/video-result.xcresult \
  -only-testing:iosAppUITests/VideoGenerateResultUITests > runs/video-result.log 2>&1
grep -E "✅|⚠️|VERDICT\||failed -|Executed .* tests?" runs/video-result.log
```
Chạy nền + ghi file rồi grep; **không pipe qua `tail`** (buffer, không thấy gì tới lúc xong).

## 2. Gate & suite — Gen Image (TC_Image_Generate.xlsx, ~90 phút, ~16 credit)

| Bước | Lệnh (`-only-testing:iosAppUITests/…`) | Gate | TC | Credit |
|---|---|---|---|---|
| B1 | gỡ app → `ImageGeneratePermissionUITests/test_photoAndCameraPermissionChain` | `RUN_PERMISSION_SUITE` | 1,4–10 | 0 |
| B2 | gỡ app → `ImageGenerateCameraUITests` | `RUN_CAMERA_SUITE` | 3,19–22 | 0 |
| B3 | `ImageGenerateToastUITests/test_probeGrantPhotosFromFreshInstall` → `ImageGenerateSelectPhotoUITests` | `RUN_TOAST_SUITE` → `RUN_SELECT_PHOTO_SUITE` | 2,12,13,15,16,18,25 | 0 |
| B4 | `OnboardingToPaywallJourneyUITests` (+`ATTENDED_PLAN=Yearly`) — **cần người** | `RUN_ATTENDED_PURCHASE` | — | — |
| B5 | `ImageGenerateResultUITests` (+`RESULT_SUITE_INCLUDE_REPORT=1`) | `RUN_RESULT_SUITE` | 28,30,36–43,47,48 | ~2 |
| B6 | `ImageGenerateFailureAndLifecycleUITests`; `ImageGenerateToastUITests/test_saveFailsWithoutPhotoPermission`, `/test_shareFailsWhenOffline` | `RUN_FAILURE_SUITE`, `RUN_TOAST_SUITE` | 29,31–34,44,46,49–53 | ~7 |
| B7 | `ImageGenerateE2ESmokeUITests/test_e2eLibraryFlow`, `/test_e2eCameraFlow` → `test_probeGrantPhotosAccess` → `ImageGeneratePermissionUITests/test_revokePhotoPermissionWhileBackgrounded` | `RUN_E2E_SMOKE`, `RUN_PERMISSION_SUITE`+`RUN_REVOKE_CASE` | 55,56,11 | ~2 |

ĐÃ CHỐT (user 21/10): **B7 KHÔNG gỡ app** (runbook gốc có `uninstall` trước E2E — bỏ bước đó). Luật chung: không gỡ app sau khi đã mua sub.
Nếu TC 55 cần app vừa cài lại → xếp TC 55 vào nhóm chạy TRƯỚC khi mua sub, không gỡ ở B7.

## 3. Gate & suite — Gen Video (TC_Video_Generate.xlsx, ~2 giờ, ~15 credit/lượt đầy đủ)

| Nhóm | Suite / method | Gate | TC | Credit |
|---|---|---|---|---|
| Dọn máy | `VideoEntryPointProbeUITests/test_restoreNetwork`, `/test_grantPhotosFullAccess` | `RUN_RESTORE_NETWORK`, `RUN_GRANT_PHOTOS` | — | 0 |
| Probe | `/test_whereIsTheVideoEntryPoint`, `/test_censusOfHomeStyleTypes`, `/test_deepLinkOpensVideoUpload`, `/test_isNetworkLinkConditionerAvailable` | `RUN_VIDEO_PROBE`, `RUN_VIDEO_CENSUS`, `RUN_VIDEO_DEEPLINK_PROBE`, `RUN_NLC_PROBE` | — | 0 |
| Dây quyền (sau gỡ app) | `VideoGeneratePermissionUITests` | `RUN_VIDEO_PERMISSION_SUITE` | 1–12 | 0 |
| Chọn ảnh + Upload | `VideoGenerateSelectPhotoUITests` | `RUN_VIDEO_SELECT_PHOTO_SUITE` | 13–17,24,25,27 | 0 |
| Camera (gỡ app lần 2) | `VideoGenerateCameraUITests` | `RUN_VIDEO_CAMERA_SUITE` | 19–22 | 0 |
| Mua sub | `OnboardingToPaywallJourneyUITests` | `RUN_ATTENDED_PURCHASE` + `ATTENDED_PLAN=Yearly` | — | — |
| Result | `VideoGenerateResultUITests` | `RUN_VIDEO_RESULT_SUITE` | 30,33,41–43,47,49,50,52,53,57,58 | 1 |
| Case FAIL riêng | `VideoGenerateResultUITests/test_tc54Only_saveOfflineHasNoToast` | `RUN_VIDEO_TC54_ONLY` (`RUN_VIDEO_TC56_ONLY`) | 54 (+47 đối chứng) | 1 |
| Mạng | `VideoGenerateFailureAndLifecycleUITests/test_offlineBeforeGenerateIsBlockedWithToast` · `/test_failedScreenViaMidRenderDrop` · `/test_recoverThenLifecycleAtResult` · `/test_interruptWhileRendering` · `/test_slowNetworkDuringRender` | `RUN_VIDEO_OFFLINE_SUITE` · `_MIDDROP_` · `_RECOVER_` · `_INTERRUPT_` · `_SLOWNET_` | 34,36,38… | 0–2 mỗi cái |
| Input limits | `VideoGenerateInputLimitsUITests` | `RUN_VIDEO_INPUT_LIMITS`, `RUN_VIDEO_POLICY_REJECT` (cần người) | 18,29,40 | 1–2 |
| Share | `VideoShareCompletionUITests` (Telegram — cần người) | `RUN_VIDEO_SHARE_SUITE` | 51,55,56 | 1 |
| Report toast | `VideoReportToastUITests` | `RUN_VIDEO_REPORT_TOAST` (máy có Mail) | 71,72 | 1 |
| Double tap | `VideoGenerateDoubleTapUITests` | `RUN_VIDEO_DOUBLE_TAP` | — | 1 |
| E2E | `VideoGenerateE2ESmokeUITests` | `RUN_VIDEO_E2E_LIBRARY` / `_CAMERA` / `_REGRESSION` | 68,69,70 | 1/1/3 |
| Thu hồi quyền (cuối) | `VideoGeneratePermissionUITests` method revoke | `RUN_VIDEO_REVOKE_CASE` | 11 | 0 |

Số TC cột trên lấy từ plan HTML video (bản 62 TC); map AC→suite chi tiết:
`~/Downloads/Gen-Image-to-Video/skills/ios-video-generate-automation/references/case-to-suite-map.md`.

## 4. 2.9.0 — suite có gen (khi spec mới đụng tới gen ảnh/video)

| Suite | Gate | Credit |
|---|---|---|
| `Genius290GenerationUITests` (Generating mới, chạy nền, khay, kill app, edge-swipe) | `RUN_G290_GEN` | ~5 |
| `Genius290VideoBackgroundUITests` (1 lượt video / case) | `RUN_G290_VIDEO_BG` | ~7 |
| `Genius290RerunGenerationUITests` | `RUN_G290_RERUN_GEN` | tuỳ |

Gen 2.9.0: ảnh ~10–15s, video ~2 phút ⇒ case "đang tạo" phải kiểm **ngay** sau khi rời màn, mỗi case 1 lượt.
Hàng đợi mẫu: `~/Downloads/IIP055-Genius-IOS-2.9.0/scripts/run-genius-290-*-queue*.sh`.

## 5. Kết quả nằm ở đâu

| Thứ | Đường dẫn |
|---|---|
| Log + xcresult + ảnh + verdicts mỗi lượt | `<plan>/runs/<ten-luot>.{log,xcresult,verdicts}` + `<ten-luot>-shots/` |
| Ghi chú verdict đã xem ảnh (đè lượt tự động) | `<plan>/verdict-notes.json` |
| xlsx kết quả | `<TC>-ket-qua-<yymmdd>.xlsx` (vd `~/Downloads/TC_Video_Generate-ket-qua-260925.xlsx`) — không ghi đè file gốc |
| Report md cho BA/dev | `from-tester-to-ba-dev-<yymmdd-hhmm>-<slug>-report.md` (mẫu: `Gen-Image-to-*/…/reports/`) |
| Report HTML / artifact | `<plan>/…-report.html` → publish Artifact (cùng file path = cùng URL khi cập nhật) |

Mỗi `.xcresult` 200–900 MB — dọn bản cũ khi Mac thiếu RAM/ổ.

## 6. Ghi verdict vào xlsx

```bash
python3 templates/extract-testcases-from-xlsx.py TC_Video_Generate.xlsx /tmp/cases-now.json   # arg2 = file JSON ra (không phải stdout)
# diff TỪNG TRƯỜNG với bản trước (không chỉ đếm):
python3 - <<'EOF'
import json; a=json.load(open('/tmp/cases-old.json')); b=json.load(open('/tmp/cases-now.json'))
A={c['no']:c for c in a}; B={c['no']:c for c in b}
print('bỏ', sorted(set(A)-set(B)), 'thêm', sorted(set(B)-set(A)))
for n in sorted(set(A)&set(B)):
    d=[k for k in ('pre','act','exp','sub','desc','section') if A[n].get(k)!=B[n].get(k)]
    if d: print('TC',n,'đổi',d)
EOF
md5 -q TC_Video_Generate.xlsx; stat -f "%Sm" TC_Video_Generate.xlsx            # ghi vào đầu report
python3 templates/write-status-to-xlsx.py TC_Video_Generate.xlsx statuses.json --col I --out TC_Video_Generate-ket-qua-$(date +%y%m%d).xlsx
python3 -c "import zipfile;from xml.etree import ElementTree as ET;zf=zipfile.ZipFile('OUT.xlsx');[ET.fromstring(zf.read(n)) for n in zf.namelist() if n.endswith(('.xml','.rels'))];print('OK')"
```
`statuses.json` = `{"1":"PASS","54":"FAIL",…}` (khoá = số ở cột A; script chấp `1`/`1.0`, tự backup `-bak`, báo `⚠️ LỆCH` nếu số dòng đổi ⇒ bỏ file đó).

## 7. Format report (đã được user duyệt)

1. Đầu trang: bản spec (tên file + md5 + mtime), build, thiết bị/iOS, ngày giờ chạy, số lượt gen.
2. KPI: % đã cover (= có verdict / tổng; BLOCKED không tính), PASS/FAIL/MISMATCH/N/A/BLOCKED, % pass trên số đã chấm, thời gian máy chạy (đọc từ dòng `Executed … in …`), credit.
3. Bug dẫn đầu: bước tái hiện, số lượt tái hiện (2/2, 3/3), đối chứng cùng phiên, file:line nghi ngờ (vd `MediaActions.swift:80`), hướng sửa; gom nhóm (TC 54/56/71/72 cùng "thiếu toast").
4. Bảng từng case: **spec nguyên văn (Pre/Action/Expected) cạnh kết quả đo + ảnh bằng chứng bên cạnh + verdict**; lọc theo trạng thái.
5. Việc còn lại theo **ai làm**: dev / PO-BA / QA tay / BE / thiết bị; mục "rút lại" verdict sai + lỗi phía test đã sửa.
6. Câu hỏi mở cuối report, mỗi câu 1 quyết định gắn TC.

Ảnh: `snap("TC 54 — …")` ngay tại dòng khẳng định verdict; thu nhỏ `sips -Z 430 -s format jpeg shots/*.png --out small/`;
nhúng artifact bằng **data URI base64** (artifact chặn ảnh host ngoài/file local). Expected 2.9.0 = frame Figma
(`~/Downloads/IIP055-Genius.pdf`), Actual = ảnh máy; dựng bằng `scripts/build-genius-290-autotest-report.py <runs> <figma-frames> <out.html>`.

## 8. Resume / lưu tiến trình

- Cuối buổi (hoặc khi user bảo dừng): viết handoff `<plan>/handoff-<slug>-trang-thai-va-cach-chay-tiep.md`
  gồm: kết quả chốt + link report, **trạng thái máy** (có/không sub, giờ mua, quyền Photos/Camera, mạng, app đang cài?),
  case còn treo + lệnh chạy lại, luật mới học. Mẫu: `~/Downloads/IIP055-Genius-IOS-2.9.0/plans/261018-1110-…/handoff-…md`.
- Cập nhật memory dự án (`~/.claude/projects/-Users-kieunga/memory/`) với trạng thái + đường dẫn handoff.
- Lần sau: đọc handoff → preflight → probe entitlement 0 credit → chỉ chạy lại **đúng suite đang dở**
  (đa số lỗi không cần làm lại từ B1).
- Đóng gói khi user yêu cầu: zip `~/Downloads/<Feature>-autotest-<yymmdd>.zip` (report + runs đã chọn + xlsx + tests).
