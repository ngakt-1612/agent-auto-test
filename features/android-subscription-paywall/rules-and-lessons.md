# Rules & lessons — Android Sub/Paywall autotest

Định dạng: **Rule** — Why (ngày/nguồn). "user" = câu user chốt trong chat. Đọc hết trước khi chạy.

## A. Phạm vi & quyết định user (không tự đảo)
- **Chỉ chạy theo file testcase user đưa; không tự mở rộng case.** — spec selector-free 15/09 ("chỉ theo bộ testcase TC_Subscription_Android.xlsx").
- **Sheet TC của team là testcase chung; mỗi app phải sửa cho fit chức năng + điểm chạm của app. Chỉ test các điểm chạm user gửi**, điểm chạm khác trong file bỏ qua. — user 08/10.
- **Nhóm 7 Change Plan bỏ hẳn; nhóm 8 (Restore/Sync Purchase) khuyết là cố ý; 6 case bị bỏ thì xoá hẳn (không treo N/A).** — user 15/09 + 28/09.
- **Không quan tâm RevenueCat cho app VSL billing** (ADA903/Linguza 2.0.0 không có SDK `com.revenuecat`). Case RevenueCat của Linguza = N/A "chờ build 2.1.0", không phải FAIL. — user 28/09; Linguza 14/10.
- **Bỏ 15/16/17 (UI cần mắt người/tablet/vision); 40 (grace period) xoá vì License Testing luôn duyệt thẻ.** — user 06/10, 29/09.
- **App không chạy sale ⇒ case sale (08/09 cũ, 06/07 v2) = N/A.** — user 29/09.
- **Case 27/29 (không phát sinh giao dịch / không mua trùng) kiểm bằng trạng thái trong app + trang Google Play Subscriptions, không cần Play Developer API.** — user 06/10.
- **Giá gói: so giá trên app với checklist/ảnh giá PO đưa (USD); account vùng khác thì mọi gói cùng một tỉ giá, lệch ≤3%.** — user 06/10 (`goi-gia-package-ada903.png`).
- **Link Privacy/ToS chuẩn lấy từ user/PO, không chép từ app; kiểm cả URL app mở có khớp + trang sống 200.** — user 30/09.
- **Tự bấm Subscribe được — account test, không trừ tiền.** Đừng dừng chờ người bấm. — user 28/09 ("bạn tự nhấn subscribe đi").
- **Không đẩy việc cho dev khi tự làm được** (vd tự viết step mới, tự đổi ngày máy). — user 15/09 ("sao phải báo cho dev? ko tự chạy được à"), 14/10 ("chạy case 66 bằng cách chỉnh ngày").
- **Onboarding tự đi được**: splash → chọn ngôn ngữ → nút tick góc trên phải → Next qua Onboarding 1–4 → Home. Không cần hỏi. — user 28/09.
- **Free user không có mục Manage subscription (Settings).** Đừng assert nó cho Free. — user 15/09. Linguza: sub user **có** "Cancel Subscription" trong Settings (12/10).
- **Unlimited = không giới hạn gen ảnh/video.** Pro bị 10 lượt/ngày là **thiết kế PO** (giảm tải server) ⇒ case 54 PASS theo thiết kế, nhưng case 25 FAIL vì text paywall "Unlimited" sai. — user 30/09, 09/10.
- **Spec chưa chốt ⇒ case chỉ ghi nhận, không chốt hướng sửa (PO quyết).** Dùng `ghi_nhan_text`. — user 30/09 ("case 34 ghi lại kết quả chứ không chốt giải pháp").
- **Bug QA đã xác nhận ghi FAIL dù hướng sửa chưa chốt.** — user 06/10 (case 34 = FAIL).
- **Bug app phát hiện thêm (ngoài TC) thì thêm vào bảng testcase (nhóm 12) và tính vào FAIL.** — user 10/10 (đổi qua lại N/A rồi chốt: "bug phát hiện thêm ghi vào fail").
- **Khi tới case cần máy 2 thì báo user; theo thứ tự user chỉ định khi user can thiệp** ("case 54 để lại, chạy case 35 trước"). — user 09/10.
- **Không commit/push file sinh ra khi user chưa bảo "push".** — user 10/10 (memory `no-push-without-explicit-request`).
- **Chạy liên tục, không chờ "chạy tiếp đi"**; chỉ dừng khi cần người (cắm máy, đăng nhập, đổi ngôn ngữ máy B). User nói dừng ⇒ viết handoff rồi dừng. — user nhắc ~20 lần "chạy tiếp đi" (06–12/10).

## B. Ads
- **Chỉ đóng ads toàn màn hình (interstitial/app-open/rewarded); banner & native inline để yên.** — user 15/09.
- **Đóng bằng nút X / Close / Đóng trên chính ad; không bấm vào creative.** Bấm nhầm creative = click quảng cáo, nhảy browser/Play. — user 15/09, 28/09; crawler 09/09.
- **Nhận diện ad bằng foreground activity thuộc allowlist namespace SDK ads (đo từ manifest bằng aapt2)**, không bằng "package khác app" (AdMob `AdActivity` khai trong manifest app) hay "class ngoài namespace app" (paywall `com.visionlab.billing`, dialog `ProxyBillingActivity` cũng ngoài namespace → sẽ tự đóng paywall). — đo 15/09.
- **Không match "Ad" / "Test Ad" / "Sponsored"** — native ad inline nằm trên Language/Onboarding/Upload/Loading hợp lệ. — 28/09.
- **Ad có countdown (`Close | N`, 8.8–14s): poll nút đóng rid/desc tới 12s rồi mới rơi xuống tầng hình học; không sleep cố định.** Tap mù sớm = click ad. — 09/09, 15/09.
- **Nút đóng ads (và nút Play) `clickable=false` — tap theo toạ độ tâm node, đừng lọc clickable.** — 15/09.
- **Sau mỗi lần tap, dump lại xác nhận ad đã biến mất; quá `max_rounds` 3 ⇒ ERROR (lỗi đo), không FAIL.** Ads SDK lạ ngoài allowlist ⇒ screen gate ra ERROR kèm dump → bổ sung allowlist, đừng đoán. — ad_interceptor.
- **Rewarded: xem hết mới đóng** (đóng sớm không nhận thưởng). Thoát giữa ads reward không được tính (Linguza 12/10). Sau đóng reward, nút Watch Ad quay spinner vài giây — chờ, đọc không được ⇒ ERROR. — 28/09, 12/10.
- **App-open ad bắn khi resume ⇒ chạy ad gate sau mọi launch/kill/background/back.** — 28/09.
- **Modal "Add Widget" của app không phải ads** (không có activity riêng) — navigator tự đóng. — 15/09.

## C. Paywall & điều hướng
- **Đóng paywall = tap nút X/Close trên paywall (Magic AI desc "Close Billing Screen"), không phải phím Back.** Back chỉ dùng khi case kiểm riêng hành vi Back. — user 28/09.
- **Crawler/khám phá: ở paywall luôn chọn "Continue with ads", không bấm nút mua.** — crawler 09/09.
- **Paywall các placement trông giống hệt nhau → phân biệt bằng `iap_view{source}` (Firebase) hoặc màn quay về.** Hai placement cùng source = bug tracking. — 08/10 (ADA903 `home_badge_pro` & `select_photo_generate` = `icon_top_bar`; Linguza `home_badge_pro` & `pop_up_chat_screen` = `icon_top_bar`).
- **Danh sách placement trong code ≠ checklist PO → đưa PO xác nhận, không tự chọn.** Lib VSL map source: `after_onboarding`, `after_inter_old→after_inter_splash_old`, `setting`, `inter_lfo`, `splash_inter`; lạ ⇒ `icon_top_bar`. Gate placement: remote config `paywall_placement`. — 07–14/10.
- **Paywall có nhiều biến thể (remote config) — chỉ assert cái mọi biến thể phải có** (giá, chu kỳ, CTA, X, Privacy, ToS, Cancel anytime). Nội dung riêng biến thể: chụp ảnh, không assert. — 29/09; Artspire 3 biến thể (07/10).
- **Thiếu "nội dung mong đợi" ⇒ xin ảnh paywall trước khi chờ spec** (1 ảnh mở khoá case 03 trong 5'). — 29/09.
- **Navigator chỉ tới paywall/home/settings; màn khác (play_sheet…) case tự mở bằng step.** — SKILL §10.
- **Text trùng: chọn theo vị trí.** Trang huỷ Play có "Cancel subscription" 2 lần (tiêu đề + nút) → lấy node `cy` lớn nhất; dòng pháp lý "By tapping 'Subscribe'…" chứa chữ Subscribe → resolver khớp **nguyên chuỗi**. — 15/09, 28/09.
- **Cú tap đầu hay bị nuốt** (nút Premium, Settings, CTA, mở lại paywall; app vừa restart) → retry có trần + đọc lại. — 15/09, 14/10.
- **App Compose = 0 resource-id của app → selector text/desc/cấu trúc; ads có resource-id SDK.** Không selector id cứng cho app. — 15/09.
- **Gói chọn chỉ thể hiện bằng màu (Artspire) → đọc pixel (`plan_rows.mode: pixel`, threshold 15).** — 07/10.

## D. Trạng thái sub, Google Play, License Testing
- **Trạng thái nằm trên Google account, một chiều FREE → ACTIVE → CANCELLED → hết kỳ → FREE.** Gỡ/cài app không về Free. Sai thứ tự = SKIP/verdict rác ⇒ chạy theo Run_Plan. — 15/09…10/10.
- **Kỳ test đo được: Weekly ~5', Monthly ~5', Yearly ~30'; gia hạn tối đa ~6 lần rồi tự hết.** Đo lại cho app mới qua "Upcoming charges" trên trang chi tiết gói (VN: `₫184,000/5 minutes`). Không suy từ gói này sang gói kia. — đo 14/09–09/10.
- **Huỷ xong sub test hết hạn chỉ vài phút sau ⇒ đọc Play NGAY sau cancel; case chờ hết hạn phải chờ theo mốc hết hạn trên Play, không chờ cố định.** — Linguza 33/34 lỗi đo 12/10.
- **Case cần Pro chạy ngay sau lần mua**; Run_Plan (`--cho-free-phut`) tự huỷ/chờ FREE/mua lại Weekly. — 09/10.
- **Play "Server error" ≠ FREE.** Đọc không được ⇒ `KHONG_BIET`, thử lại 1 lần rồi dừng; kiểm chéo dấu hiệu trong app (nút Premium/Get Pro). Không chạy case mua/huỷ khi Play lỗi; dùng `wait_play_then_resume_run_plan.py`. — 30/09, 08/10.
- **Chờ trang Play tải xong mới đọc** (đọc sớm ra FREE giả). — 09/10.
- **"already subscribed" khi mua chuẩn bị ⇒ coi là ACTIVE.** — 09/10.
- **Huỷ trên máy B phải thật sự chạy trên B** (`device: B`); huỷ trên máy đang kiểm không chứng minh đồng bộ. Nhãn en-US "Canceled" quy về "Cancelled" (`_LABEL_DONG_NGHIA`). — 02/10.
- **Trang Play: dòng status đổi trước, dòng chi tiết có thể vẫn "Next payment" → lỗi hiển thị phía Play, không phải app.** — Linguza 39 (12/10).
- **Cache entitlement: app từng mua có thể vẫn coi là Premium sau khi sub hết → gỡ hẳn rồi cài lại.** — user 07/10 (Artspire).
- **Remote config đọc 1 lần/ngày** (Linguza `limit_chat_sub_per_day`, lưu `chat_prefs`) → đổi RC giữa ngày cần `pm clear` hoặc sang ngày mới. — 13/10.
- **Case "qua ngày" làm được bằng đổi ngày máy qua adb** (`cmd time_detector set_auto_detection_enabled false` + `cmd alarm set-time`), luôn trả lại giờ + bật auto. App restart sau đổi ngày nuốt tap. — 14/10 (case 66 PASS).

## E. Billing (bug thật, đã xác nhận ở 2 app)
- **Play Store restart khi app đang mở ⇒ app không reconnect BillingClient; Continue im lặng, log `PurchaseEG: onPurchasesUpdated code: -1`.** Tái hiện: paywall → `am force-stop com.android.vending` → bấm Continue. ADA903 case 55 (2/2 auto + 3/3 tay), Linguza 55. — 09–10/10.
- **Hệ quả cho runner: đọc trang Play làm Play restart ⇒ trước case có bước mua phải `am force-stop <app>` rồi mở lại.** — 09/10.
- **Gate an toàn thanh toán (`billing_safety.py`) không được nới; thẻ thật ⇒ dừng cả lượt.** Gate phải nằm TRÊN đường đi (interpreter/`_gate_mua`) — từng có 2 lần gate viết kỹ mà không ai gọi. Thêm đường chạy mới ⇒ kiểm lại mọi gate. — 14/09, 15/09.

## F. Đo đạc & verdict
- **Phép đo hỏng trông y hệt bug app.** Trước khi gọi FAIL: mở ảnh `fail_<case>_*.png`, xem evidence trỏ text/desc gì, chạy lại ≥1 lần. — 14/09 (3 "bug" giả: Restore, mất chọn gói, thời hạn).
- **PASS giả nguy hiểm hơn FAIL giả.** Hỏi: PASS vì app đúng hay vì đang ở màn khác/nguồn rỗng? — 15/09 (case 30 sau kill về onboarding).
- **`not_visible` PASS là tín hiệu yếu** (resolver khớp nguyên chuỗi; intent khai sai chữ ⇒ PASS vĩnh viễn). Text có số/ngày ⇒ `khong_co_text: {pattern}`. Intent phải từng resolve được ở đâu đó. — 30/09 case 34.
- **Tap xong phải đọc lại xác minh** (cancel_subscription từng tap trúng tiêu đề mà trả True). — 28/09.
- **Assert đặt đúng màn app đang đứng sau step cuối** (sau Back khỏi dialog Play app về paywall, không về Home). — 29/09 case 28.
- **Đừng thêm assertion không có trong Expected Result.** — 15/09 case 25.
- **Case tự khai `requires_state` + `screen_after`**, không hard-code theo tc_id. — 15/09.
- **Test chỉ có giá trị khi đã thấy nó đỏ** (cố tình phá implementation rồi chạy lại). — 14/09.
- **Chạy thật sớm** (5–10 case thật ngay khi smoke thông), đừng build hết rồi mới chạy. — 14/09.
- **Verdict**: PASS · FAIL (app sai) · ERROR (bộ đo sai — ô kết quả để trống, lý do ở cột ghi chú) · SKIP (sai trạng thái) · NOT_EVALUATED/PARTIAL (thiếu điều kiện ngoài/chờ người quyết) · BLOCKED (thiếu máy/quyền) · N/A (app không có tính năng). Không trộn N/A với NOT_EVALUATED. — SKILL §3.
- **Lỗi đo thường gặp**: canh giờ hết hạn (33/34), ads reward đã preload trước khi tắt mạng (64 — phải tắt mạng trước preload), đọc lúc nút đang spinner (63), Aria đang gõ (nút "Stop" thay "Send"), kẹt màn ngôn ngữ dạng xổ xuống/onboarding A/B (thử lại 1 lần), máy màn nhỏ nút Cancel ngoài màn (bounds 0 → cuộn), `window_count` đếm cả `imeLayeringTarget`. — 15/09–12/10.
- **`adb pull` có thể thất bại im lặng** → kiểm file đã về máy. `pgrep -f` tự khớp chính nó (dùng `'android-ui-crawl[e]r'`). `.pyc` cũ khi cp trong cùng giây → xoá `__pycache__`. — 15/09.

## G. Nghi bug cần tái hiện thêm (chưa xác minh đủ)
- Linguza 36 / Artspire 42: app mất Pro ~1 phút quanh mốc auto-renew dù Play Active (ADS full-screen hiện lại). Cần mở app đúng lúc renew + log Billing. (chưa xác minh)
- Linguza: mở lại app sau khi huỷ (còn hạn) thấy native ad + inter + paywall trước khi về Pro — chưa tách khỏi việc xoá data. (chưa xác minh)

## H. Tài liệu/comment
- **Comment code/tên file giải thích lý do, không ghi số phase/mã finding.** — SKILL §16.
- **Sai lệch so với sheet chưa phải bug cho tới khi QA/PO xác nhận; báo kèm ảnh + lệnh tái lập.** (tiền lệ: "thiếu Restore" phải rút lại). — 14/09.
- **Giao việc cho agent: đưa hết vào dispatch ban đầu, đừng nhắn giữa chừng** (agent nghi prompt injection). — 14/09.
