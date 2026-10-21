# Android Subscription / Paywall autotest — gói kiến thức

Autotest gói Sub (Google Play Billing, License Testing) + từng **điểm chạm paywall (placement)** trên máy Android thật.
Runner Python + adb + uiautomator dump, case YAML mô tả **ý định** (selector-free). Chốt kiến thức tới 21/10/2026.

Đọc chung trước: `/Users/kieunga/automation-test-agent/common/working-rules.md`.

## Đọc file nào khi nào

| Khi | Đọc |
|---|---|
| Luôn luôn, trước khi chạm máy | `rules-and-lessons.md` (quan trọng nhất) |
| Máy mới / máy vừa cắm / account lạ | `setup-environment.md` |
| Thêm app mới, sửa runner, viết case YAML, sinh case từ xlsx | `architecture-and-runner.md` + `templates/` |
| Chạy lô / Run_Plan / 1 case, ghi kết quả xlsx, làm report, handoff | `run-and-report.md` |

Nguồn gốc chi tiết (đọc khi cần sâu hơn):
- Skill trong repo: `~/magic-ai-sub-e2e/.claude/skills/subscription-android-autotest/SKILL.md` (17 nguyên tắc + DSL + report).
- Plan 6 phase áp cho app mới: `~/magic-ai-sub-e2e/plans/261010-1203-ap-dung-automation-sub-android-cho-app-khac/` (plan.md + phase-01…06).
- Bài học gốc: `~/magic-ai-sub-e2e/docs/handoff-260914/01-nguyen-tac.md`, `docs/handoff-260915/01-nguyen-tac.md`.
- Handoff mới nhất: `docs/handoff-261009/` (ADA903), `docs/handoff-261010-linguza/` (AIP918).

## Repo

| | |
|---|---|
| Repo làm việc | `/Users/kieunga/magic-ai-sub-e2e` — branch `feat/subscription-dsl-runner`, remote `https://github.com/ngakt-1612/903Magic-ai.git` (push lên `main`) |
| Bản clone | `/Users/kieunga/903Magic-ai` — **cũ** (HEAD `60d594a`), không có phần Linguza/điểm chạm. Làm việc ở repo trên. |
| Trạng thái git 21/10 | ahead 1 (`504144b`, push lỗi token hết hạn 16/10); phần Linguza **chưa commit** (user chưa cho push) |
| Repo team | `https://github.com/Apero-Vibecode/qa-e2e` → `iaa/sub/` (plan + report ADA903, commit `cb9e0f6`, 07/10) |

## App đã làm

| App | Package | APK | TC gốc / kết quả |
|---|---|---|---|
| **ADA903 Magic AI** 3.0.0 (vc 24) | `com.aiprofile.aiheadshot.aiimagegenerator.aiphotogenerator` | `~/Downloads/903magic-ai-v3.0.0.apk` | `tc/TC_Subscription_Android_ADA903_v2.xlsx` → `tc/TC_Subscription_Android_ADA903_v2_ket_qua.xlsx` |
| **AIP882 Artspire** 3.2.0 (29) | `com.aivideogenerator.aiphotoeditor.beautyeditor.imagetoimage` | `~/Downloads/aip882-artspire.apk` | checklist `~/Downloads/TC_Subscription_Android_aip882.xlsx` (39 case dạng cũ, chưa có Run_Plan) |
| **AIP918 Linguza** 2.0.0 | `com.nxl.aienglishtutor.ailearnlanguage.aichatbot` | `~/Downloads/aip918-linguza-v2.0.0.apk` | `tc/TC_Subscription_Android_AIP918.xlsx` → `tc/TC_Subscription_Android_AIP918_ket_qua.xlsx` (+ bản `~/Downloads/`) |

Config: ADA903 `apps/magic-ai.json` + `cases/`; Artspire `apps/artspire/config.json` + `apps/artspire/cases/` (39);
Linguza `apps/linguza/config.json` + `apps/linguza/cases/` (80) + `apps/linguza/diem-cham-paywall.json`.

Paywall lib: ADA903 & Linguza = `com.visionlab.billing.ui.VslBillingActivity` (placement qua remote config `paywall_placement`);
Artspire = `.revcat.RevenueCatPaywallActivity` (RevenueCat, 3 biến thể remote config, gói chọn chỉ phân biệt bằng màu → pixel).

## Trạng thái mới nhất

**ADA903 Magic AI** — xong Run_Plan v2 (09–10/10): 55 case · **51 PASS · 2 FAIL (25, 55) · 2 N/A (06, 07 không sale)**.
- 25 FAIL: Pro bị giới hạn 10 lượt gen/ngày (PO thiết kế) nhưng paywall ghi "Unlimited" → text paywall sai.
- 55 FAIL (bug thêm): Play Store restart khi đang ở paywall → Continue im lặng, `onPurchasesUpdated code: -1`.
- Điểm chạm 4/6 đã automation: `after_onboarding`, `after_inter_old`, `home_badge_pro` ⭐, `select_photo_generate`.
  `home` N/A (code: nút Pro header = `home_badge_pro`), `generate_song` chưa test (phải dùng hết lượt nhạc), `edit_video` có trong code nhưng checklist không có.
- Tracking: `home_badge_pro` và `select_photo_generate` cùng `iap_view source=icon_top_bar`.
- Report: https://claude.ai/artifact/17nATzXK6Kh3s7m4vV6vJp ("Subscription QA Sheet"). Plan chốt: https://claude.ai/artifact/JDqUyTfxeT9P7cRf92iDF6.

**AIP882 Artspire** — 07/10 chạy bộ 39 case cũ: 38 chạy được · **33 PASS · 5 FAIL** (02/08/09 giá lệch checklist: Weekly bán giá gốc không sale, Yearly ≈$79.99 ≠ $99.99; 01/03 paywall 3 biến thể) · 46 chưa chạy (thiếu máy B).
- 16/10 user yêu cầu thêm 6 điểm chạm (home, after_onboarding, after_inter_old, home_badge_pro, select_photo_generate, generate_song) → **đã dừng ("stop"), chưa làm**: chưa có TC v2/Run_Plan/Touchpoints cho Artspire.
- Report: https://claude.ai/artifact/FDsJXsJfFRpvqAY94zfhyq.

**AIP918 Linguza** — Run_Plan xong 10–14/10: 80 case · **57 PASS · 4 FAIL (11, 36, 55, 57) · 2 chờ PO (54, 60) · 3 lỗi đo (33, 34, 64) · 14 N/A** (06 07 không sale; 67–77 80 RevenueCat chưa có trên 2.0.0). 35 PASS (13/10, huỷ tay trên Oppo), 66 PASS (chỉnh ngày máy).
- Điểm chạm: `after_onboarding`, `after_inter_old`, `home_badge_pro`, `pop_up_chat_screen` (10 PASS mỗi điểm; 41@home_badge_pro N/A); `setting` không có trên 2.0.0.
- Việc còn: tái hiện bug 36 (mất Pro quanh mốc renew) & 55 → bug report; chạy lại 33/34/64 sau khi sửa canh giờ; chờ build 2.1.0 (RevenueCat) cho nhóm 14; 7 câu hỏi PO (xem `run-and-report.md`).
- Report: https://claude.ai/artifact/2C2n14ZqehV4KCzX7VwUAj (bản 6, có mục "Điểm chạm Paywall"). Bản md: `~/Downloads/AIP918 Linguza Sub Android.md`.

## Liên quan (không phải Android sub nhưng cùng mẫu)
- Ads crawler đóng ads bằng X/Close: `/Users/kieunga/plans/260909-1042-android-auto-test-ads/` (report + `android-ui-crawler-with-ad-closer.py`).
- Report điểm chạm paywall iOS Genius (IIP055, Appium) — mẫu trình bày "report theo điểm chạm": `~/Downloads/Subscription-QA-Report/`, `~/Downloads/Report-DiemCham-Paywall.html`.

## templates/ (bản copy, tên đã đổi cho dễ hiểu)
| File | Gốc trong repo |
|---|---|
| `app-config-ada903-magic-ai.json` | `apps/magic-ai.json` |
| `app-config-aip918-linguza.json` | `apps/linguza/config.json` (có `diem_cham` pop-up, `paywall_entry`) |
| `case-paywall-ui-SUB_AND_01.yaml` | `cases/SUB_AND_01.yaml` |
| `case-touchpoint-purchase-SUB_AND_44.yaml` | `cases/SUB_AND_44.yaml` (lặp theo điểm chạm) |
| `case-bug-billing-reconnect-SUB_AND_55.yaml` | `cases/SUB_AND_55.yaml` (mẫu case bug phát hiện thêm) |
| `run-app-cases-batch.sh` | `scripts/run-linguza-cases.sh` |
| `run-plan-by-user-state-batches.sh` | `scripts/run-plan-linguza.sh` (gọi `scripts/run-linguza-cases.sh`) |
| `run_plan_ada903.py` | `scripts/run_plan_ada903.py` (Run_Plan + ghi xlsx sau mỗi bước) |
| `sinh-case-stub-tu-xlsx.py` | `scripts/sinh-case-stub-tu-xlsx.py` |
| `fill-results-with-manual-verdicts.sh` | `scripts/fill-results-linguza.sh` (mẫu `--ghi-tay`) |

Templates chạy được chỉ khi đặt lại vào repo ở đúng đường dẫn gốc (script `cd "$(dirname "$0")/.."`).
