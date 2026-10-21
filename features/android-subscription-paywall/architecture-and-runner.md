# Kiến trúc runner `~/magic-ai-sub-e2e` & cách thêm app

## 1. Bản đồ repo

| Đường dẫn | Vai trò |
|---|---|
| `run_yaml.py` | **Runner chính** (YAML). Chọn case, nhân bản theo điểm chạm, đảm bảo trạng thái sub (`dam_bao_trang_thai`), chạy, ghi `results.json` + `report.md` |
| `run.py` | Runner đời đầu (DSL sheet `Automation` của xlsx 11.17.50) — **không dùng nữa** |
| `tc_runner/core/` | Hạ tầng: `adb_driver` (dump/tap/screencap), `ad_interceptor` (đóng ads toàn màn), `screen_state` (gate màn), `intent_resolver` (intent → node), `app_navigator` (onboarding/home/paywall/settings), `play_store` (đọc/huỷ trang Play Subscriptions), `sub_state` (FREE/ACTIVE/CANCELLED/KHONG_BIET), `billing_safety` (gate thẻ thật), `plan_row_pixel_marker` (gói chọn bằng màu), `evidence`, `reporter`, `case_loader`, `app_config` |
| `tc_runner/dsl/yaml_runner.py` | Bảng `STEPS`/`ASSERTS` (đăng ký verb mới ở đây) |
| `tc_runner/dsl/paywall_touchpoint_steps.py` | `DIEM_CHAM`, `di_toi_diem_cham` (đi tới từng placement — **code riêng từng app**), `diem_cham_ra`, `dong_paywall`, `mo_dialog_mua`, `dung_play_store`, `log_billing` |
| `tc_runner/dsl/chat_flow_steps.py`, `chat_daily_reset_steps.py` | Linguza: `mo_chat`, `gui_chat`, `xem_reward`, `bam_go_pro`, `qua_ngay_moi` (đổi ngày máy), `luot_ve_day` (chưa commit) |
| `tc_runner/dsl/generation_flow_steps.py`, `sale_price_assertions.py`, `price_checklist_comparison.py` | Magic AI gen ảnh; Artspire sale/% giảm; so giá checklist |
| `cases/SUB_AND_*.yaml` | Case ADA903. App khác: `apps/<app>/cases/` |
| `apps/magic-ai.json`, `apps/<app>/config.json` | Config app (mọi selector/text/giá/URL/điểm chạm nằm ở đây) |
| `flows/`, `subflows/` | YAML kiểu Maestro thời đầu — **bỏ** (grep `\.maestro|flows/`, đừng grep "maestro": `billing_safety.py` có hãng thẻ Maestro) |
| `scripts/` | Lô chạy, Run_Plan, ghi kết quả, sinh stub (bảng §5) |
| `.claude/skills/subscription-android-autotest/` | `SKILL.md` + scripts ghi xlsx/report + assets mẫu notes |
| `tc/` | File testcase gốc + `_ket_qua.xlsx` + `quyet_dinh_qa.json` |
| `artifacts/<yymmdd-hhmm>-yaml/` | Kết quả lượt (app khác: `apps/<app>/artifacts/`). Chỉ `results.json` được commit |
| `tests/` | ~450 unit test (driver giả + fixture XML). Phải xanh trước khi tin máy |

## 2. Đường đi của 1 case
```
case YAML ─▶ run_yaml ─▶ dam_bao_trang_thai(requires_state) ─▶ Navigator tới `screen`
   └─ mỗi step/assert: dump ─▶ [ad_interceptor] ─▶ [screen gate] ─▶ [intent_resolver] ─▶ tap/assert ─▶ [evidence]
       bước tap Subscribe ─▶ _gate_mua ─▶ billing_safety (thẻ thật ⇒ dừng CẢ lượt)
```
- Gate màn chạy lại **trước nhóm assert** (step có thể tự đổi màn). Sai màn ⇒ ERROR, không chạy tiếp.
- Mỗi case bọc try/except → lỗi thành ERROR của riêng case, không giết cả lượt. Runner luôn bật lại mạng, reset kích thước màn ở mọi đường thoát.
- Mỗi case tự dọn app lạ (browser, dialog Play) + đưa app về foreground trước khi điều hướng.
- Case có bước mua: runner `am force-stop <pkg>` trước (vì đọc trang Play làm Play khởi động lại → app mất Billing).

## 3. Config app (`apps/<app>/config.json`) — các khối
`pkg`, `main_activity`, `apk_path`, `play_row` (tên app trên trang Play Subscriptions), `skus`,
`screens` (vân tay màn: `any_text`, `none_of_text`, `activity_pkg`), `onboarding` (marker paywall/home, id nút Next ngôn ngữ/carousel/question, `paywall_entry`),
`ads` (`ad_activity_namespaces` đo từ manifest, `close_rids` `dismiss-button`, `close_descs`, `max_rounds` 3, `poll_timeout_s` 12),
`intents` (`paywall.close/cta/continue_with_ads/cancel_anytime/privacy/tos`, `plan_option`, `plan_price`, `plan_duration`, `paywall.benefit_*` nguyên văn, `home.trigger_paywall`, `settings.*`, `play.*`; mỗi intent `text`/`desc`/`structural`/`geometry`),
`structural_selectors`, `plan_rows` (`mode: pixel` khi gói chọn chỉ có màu — Artspire, threshold 15), `urls` (privacy/tos từ PO),
`bang_gia_checklist` + `_nguon` (USD), `diem_cham` (mỗi placement: `source`, `man_khi_dong`, `man_sau_mua`, `khong_trigger`, `giu_input`, `dau_hieu_free`, `dau_hieu_pro`).
Mẫu: `templates/app-config-ada903-magic-ai.json`, `templates/app-config-aip918-linguza.json`.

## 4. Case YAML — khai báo
```yaml
tc_id: SUB_AND_44            # khớp cột D "[SUB_AND_xx] ..." của xlsx
screen: paywall|home|settings|diem_cham    # Navigator chỉ tới được paywall/home/settings (+ diem_cham qua step)
requires_state: FREE|ACTIVE|CANCELLED
screen_after: any            # màn app đứng sau step cuối (assert phải đặt đúng màn này)
blocked_by: ''               # điều kiện ngoài còn thiếu
na_reason: '...'             # có ⇒ runner bỏ qua, ra N/A, không chạm máy
lap_theo_diem_cham: true     # nhân bản theo điểm chạm; placeholder ${DIEM_CHAM} ${MAN_KHI_DONG} ${MAN_SAU_MUA}, {theo_diem_cham: dau_hieu_pro}
```
Verb (đầy đủ ở `yaml_runner.STEPS/ASSERTS`):
- step: `tap double_tap back wait screenshot scroll kill_app background play_cancel network reinstall man_hinh mo_style dong_modal diem_cham dong_paywall chon_anh mo_dialog_mua dung_play_store tao_anh luu_anh mo_chat gui_chat xem_reward bam_go_pro qua_ngay_moi`
- assert: `visible not_visible selected_count text_matches no_crash foreground_matches window_count play_state auto_renewed khong_co_key_tho khong_co_text ghi_nhan_text gia_khop_play gia_khop_checklist trang_web_song diem_cham_ra log_billing co_text gia_trong_dong phan_tram_giam khong_ads chat_ra reward_ra luot_ve_day external vision`
- Mua: `tap: {intent: plan_option, index: N}` → `mo_dialog_mua: {}` → `tap: {intent: play.subscribe}` (đi qua gate an toàn).
- `play_state: {status, detail_contains, state, so_dong, device: B}`; `play_cancel: {device: B}` cần `--serial-b` (thiếu ⇒ ERROR, không lặng lẽ chạy máy A).
- `network: {state: off|on}` tắt **cả** wifi + data. `man_hinh` đổi size làm app khởi động lại ⇒ `screen_after: any`.
- `external` luôn NOT_EVALUATED; `ghi_nhan_text` ghi số đo rồi NOT_EVALUATED (spec chưa chốt).
Mẫu: `templates/case-*.yaml`.

## 5. Scripts
| Script | Dùng |
|---|---|
| `scripts/run_plan_ada903.py <A> [--serial-b B] [--tu-buoc A1] [--den-buoc R3]` | Run_Plan ADA903; bảng `BUOC` (`s(...)` case 1 lần, `tp([...],[placement])` case điểm chạm), `CUNG` (2 case chung 1 lần mua); ghi xlsx sau mỗi bước (`ghi_ket_qua`) |
| `scripts/run-plan-linguza.sh [LÔ_BẮT_ĐẦU]` | Run_Plan Linguza dạng hàm `lo <tên> <cases> [--diem-cham ...]`, `--cho-free-phut 20` |
| `scripts/run-linguza-cases.sh`, `run-artspire-cases.sh` | Wrapper `run_yaml.py --app/--xlsx/--cases-dir/--artifacts`, `A` = serial (mặc định `R58TB198BNN`) |
| `scripts/run-ada903-touchpoint-batches.sh <serial> lo1|lo2|lo3` | Lô theo điểm chạm (bản 08/10, trước v2) |
| `scripts/wait_play_then_resume_run_plan.py <A> [--serial-b B] --tu-buoc X --den-buoc Y | --cases ...` | Chờ Play hết "Server error" rồi chạy tiếp (đang trỏ `run_plan_ada903.py`) |
| `scripts/fill-results-linguza.sh` | Ghi kết quả + `--ghi-tay` override + sheet điểm chạm, copy `~/Downloads/` |
| `scripts/them-sheet-diem-cham-paywall.py <ket_qua.xlsx>` | Thêm sheet `Diem_cham_Paywall` từ `apps/<app>/diem-cham-paywall.json` |
| `scripts/sinh-case-stub-tu-xlsx.py [xlsx]` | Sinh khung YAML (id, title, priority, screen, blocked_by, source_row) — **không ghi đè**; `OUT` mặc định `cases/` (sửa sang `apps/<app>/cases`); bảng `MAN` là ước lượng, đính chính khi chạy thật |
| `scripts/repro_billing_disconnect_after_paywall_close.py`, `r2_billing_restore_experiment.sh` | Tái hiện bug Billing |

## 6. Thêm app mới (plan 6 phase, giao **từng phase một**, QA duyệt P3 và P6)
1. **P1 Chuẩn bị**: 2 máy English cùng account License Testing, APK `~/Downloads/`, pytest xanh, account FREE, 6 input PO (`setup-environment.md` §6).
2. **P2 Dò app** (chưa mua): `dexdump` tìm `VslBillingActivity.Companion.start(ctx, placement)` / `setDefaultPlacementBilling` / key `paywall_placement`; đi từng placement trên máy (ảnh + dump), đọc `iap_view{source}`; chép **nguyên văn** UI paywall; giá 3 nguồn (paywall = dialog Play = checklist; mở dialog rồi **Back, không Subscribe**); vân tay màn + dấu hiệu Free/Pro; chức năng trả phí/giới hạn ngầm. Đầu ra `plans/reports/app-survey-<yymmdd>-<hhmm>-<app>-report.md` + câu hỏi PO.
3. **P3 Sinh TC**: copy `tc/TC_Subscription_Android_ADA903_v2.xlsx` (giữ style/công thức) → `tc/TC_Subscription_Android_<APP>.xlsx`. Hợp đồng file:
   - Sheet `TC_Subscription_Android`: header dòng 2, data từ dòng 3; nhóm `▌ <số>. <tên>` merge A:I; A số · B Feature · C Description · **D `[SUB_AND_xx] tiêu đề`** · E Precondition · F Test Data · G Action · H Expected · I PASS/FAIL (trống) · **J `1 lần`/`Mỗi điểm chạm`** · K bước Run_Plan · L Auto/Manual · M bằng chứng · N–Q ảnh/placement.
   - `Touchpoints` (header dòng 3, ≤8 placement, ⭐ placement chính), `Run_Plan` (quy tắc dòng 1–9, bảng từ dòng 11), `Summary` (`COUNT`), `Matrix_Touchpoint` (giữ công thức).
   - Nhóm chuẩn: 1 UI Paywall · 2 Chọn gói · 3 Purchase · 4 Sau mua · 5 Renewal · 6 Cancel · 9 Manage · 10 Touchpoint (Mỗi điểm chạm) · 11 Chức năng sau mua (viết lại theo app) · 12 Bug phát hiện khi chạy automation (trống). **Không có nhóm 7, 8** (cố ý).
   - Sheet TC gốc của team là **chung**; mỗi app khác chức năng/tên điểm chạm → sửa cho fit app, chỉ test placement user đưa.
4. **P4 Config + YAML**: config §3; thêm placement vào `DIEM_CHAM` + hàm đi tới (gọi `_bat_dau_nghe_iap_view(runner)` **trước** thao tác mở paywall; onboarding/user cũ dùng `nav.fresh_start(clear=True|False)`) + unit test driver giả (`tests/test_paywall_touchpoint_steps.py`); sinh stub → viết steps/asserts (case cùng nghĩa copy từ `cases/`); copy `run_plan_ada903.py` → `run_plan_<app>.py`; copy `tests/test_pham_vi_case_ada903.py` khoá số case/lượt. Chạy thử **không mua** ≥1 case mỗi màn: còn ERROR thì sửa config, chưa chạy suite.
5. **P5 Chạy** theo Run_Plan (`run-and-report.md`). 6. **P6 Ghi kết quả + bug thêm + report**.

## 7. Run_Plan — xếp theo trạng thái user (không theo ID)
A Free user mới (cài mới/clear) → placement onboarding · B Free user cũ (kill → mở lại) → placement user cũ ·
C Free placement chính: toàn bộ UI, chọn gói, mở dialog Play không mua, mất mạng · D Free các placement khác ·
E mua Weekly ở placement chính → case Pro, chức năng sau mua → cài lại → huỷ → hết hạn; rồi chu kỳ mua ở từng placement ·
F Monthly/Yearly (Yearly chờ ~30') · G 2 máy (huỷ trên B). Số lượt = case 1 lần + case điểm chạm × số placement (ADA903: 55 case/85 lượt, ~8 lần mua, ~1 ngày máy).
Ràng buộc cứng: case "app vừa cài" chạy đầu ngay sau `adb install`; case "chưa từng mua" trước mọi lần mua; case gỡ/cài lại xoá state → cuối; case Privacy/ToS để lại browser → tách riêng.

## 8. Còn thiếu (đã biết)
- Đường tới placement chưa thuần config (code riêng mỗi app). Script Run_Plan/chờ Play cứng đường dẫn ADA903 → copy/sửa.
- `scripts/trich-selector-tu-apk.py` chưa viết — P2 làm tay bằng UI dump.
- "Cú tap đầu bị nuốt" đã vá riêng 4 chỗ bằng retry; chưa có cơ chế chung `tap_cho_den_khi`.
