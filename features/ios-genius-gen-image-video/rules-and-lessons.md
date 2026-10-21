# Luật & bài học — Genius I2I / I2V autotest (ĐỌC TRƯỚC TIÊN)

Format: **Luật** — Vì sao (ngày / nguồn). "user" = lời chỉnh trực tiếp của user. Nguồn viết tắt:
SKILL = `ios-xcuitest-device-automation`, VSKILL = `ios-video-generate-automation`, PLAN-I/PLAN-V =
plan HTML Image/Video, H290 = handoff 2.9.0, S2 = report Seedance2 round 11.

## A. Phạm vi & cách làm việc với user (user corrections)

1. **R1 — Chỉ chạy TC của file spec user đưa lần này; plan/report/skill cũ là công cụ, không phải phạm vi.**
   Trước khi chạy, map tài liệu cũ vào danh sách TC mới. — 18/10 tự chạy lại full 51+62 TC cũ cho 2.9.0, mất ~1h máy; user: "tôi không yêu cầu bạn chạy lại toàn bộ… là công cụ, kiến thức để bạn áp dụng" (memory).
2. **R2 — Tự chạy tiếp, xâu chuỗi suite trong 1 script nền; chỉ dừng cho việc cần người (mật khẩu sandbox, mở khoá máy, chọn ảnh/đích share) và báo đúng 1 lần cần làm gì.** — 18/10 user phải gõ "chạy tiếp" ~8 lần ("auto chạy tiếp ko cần tôi nhắc"); 17–19/09 cũng vậy.
3. **R3 — Đọc spec HIỆN HÀNH từng trường trước mỗi lượt (pre/act/exp/sub/desc/section), không chỉ đếm case thêm/bớt.** — 25/09 user: "TC 51 đã ghi là share qua app Telegram mà sao bạn cứ chọn app Notes" (spec đổi đích 4 ngày trước, diff cũ không thấy ⇒ 2 ngày verdict N/A sai). (PLAN-V #7)
4. **R4 — Script dựng report/artifact phải đọc file spec hiện hành, không trỏ snapshot.** — 25/09 user: "TC 71 tôi đã sửa Action sang bật mạng rồi mà ở artifact vẫn hiện 1. Tắt mạng".
5. **R5 — Quy tắc verdict user đã chốt cho bộ video:** không thấy toast spec đòi (Share failed / Report sent / Report failed) ⇒ **FAIL**; không đo được vì nằm ngoài app ⇒ **N/A** (sau đó đổi sang case bàn giao); PO xác nhận hành vi ⇒ ghi theo PO (TC 40 PASS "PO confirm không chặn NSFW"). — user 24–25/09.
6. **R6 — Mỗi FAIL/NA/chưa chốt phải có ảnh bằng chứng đặt cạnh testcase trong artifact; report ngắn gọn.** — user 23/09 "case fail không có ảnh screenshot hả"; 25/09 "trình bày lại artifact report cho ngắn gọn, các testcase thì gắn kèm ảnh bằng chứng bên cạnh".
7. **R7 — Không ghi BLOCKED/"test tay" hời hợt: mỗi case phải có lý do kỹ thuật + ai gỡ + mất bao lâu; trước khi xếp "không tự động hoá được" thử biến thành case bàn giao.** — user 19/09 "tại sao tận 14 case phải test tay", 21/09 "tại sao còn 7 case bị blocked" ⇒ cuối cùng gỡ hết.
8. **R8 — Lưu tiến trình + đóng gói (artifact/handoff/skill) cuối mỗi buổi để hôm sau chạy tiếp; cập nhật skill khi học được bẫy mới.** — user 17/09, 19/09, 23/09 "update vào skill… sau tôi chạy lại sẽ không mất thời gian sửa yêu cầu".
9. **R9 — Không commit/push file sinh ra khi user chưa bảo "push".** — memory no-push (10/10). User đã từng chủ động yêu cầu push Gen-Video-Genius (24–25/09) — chỉ làm khi được bảo.
10. **R10 — Style video ở tít cuối Home (gần style World Cup); không thấy ⇒ cuộn tiếp/deep link, đừng kết luận "không có tính năng".** — user 17/09 "style video ở tít cuối, chỗ style world cup ấy".
11. **R11 — 2.9.0: không đổi Remote Config, không mock/proxy server, không viết TC tay.** — user 18/10 (memory genius-v290).

## B. Thứ tự buổi chạy & trạng thái máy (sai là mất cả buổi)

12. **KHÔNG gỡ app sau khi mua sub** — gỡ xoá container ⇒ mất entitlement ⇒ mọi gen ra paywall giống bug app; đổi quyền giữa buổi thì qua Settings. (PLAN-I/V #1, mất 1 buổi 19/09)
13. **Gỡ app 2 lần, cả 2 trước khi mua: trước dây quyền và trước suite camera** — dây quyền kết thúc camera `denied`, suite camera chỉ xử `notDetermined`; đảo thứ tự cũng hỏng (TC 5/7 mất verdict). (report 14/09)
14. **Thứ tự video:** preflight → probe entry point → gỡ app → dây quyền → chọn ảnh → gỡ app → camera → mua Yearly → Result → offline → cắt mạng giữa render → phục hồi/lifecycle → cắt ngang → 3G → input limits → share/report/double-tap → E2E → TC 11 thu hồi quyền **cuối cùng**. (PLAN-V)
15. **Case phá trạng thái xếp cuối dây** (Don't Allow vĩnh viễn, thu hồi quyền TC 11, rời màn Result / Regenerate) — chạy sớm chặn mọi case sau. (SKILL §3)
16. **Mua gói Yearly; probe entitlement trước mỗi nhóm tốn credit** — weekly sống 3 phút; yearly 1–6 giờ không đoán được (19/09 ~6h, 24/09 1h20). (PLAN-V #3)
17. **Paywall/hết credit ⇒ `XCTSkip` "chưa đo được", không FAIL** — lượt đầu báo 3 FAIL chỉ vì chưa có sub; 2.9.0 paywall có thể là hết lượt ngày (kiểm nút Pro). (VSKILL §4, H290 #9)
18. **Mỗi verdict case cần gen ghi kèm: badge credit, có/không paywall, lượt gen thứ mấy trong phiên** — paywall hiện dù badge 18; lượt 1 OK lượt 2 fail lặp lại. (principles §11)
19. **S2: gate gen là CREDIT, không phải SUBSCRIPTION; "vào được màn Loading" không chứng minh credit > 0; xoá app không về "user mới" (RevenueCat ID trong Keychain); sub hết hạn thì máy về FREE (cold start thấy lại nút Pro).** — S2 28/08.
20. **Không build-for-testing khi suite đang chạy; không sửa file script đang chạy (bash đọc dần từng dòng).** — mất lượt TC 38 (23/09); hỏng 1 lượt (H290 #2).
21. **Đừng bỏ bước dựng tiền đề để né crash** (vd bỏ `network.ensureOn()`) — lượt sau bắt đầu offline. Sửa crash, giữ tiền đề. (summary 23/09)
22. **`tearDown` luôn trả mạng (`ensureOn`), tắt Network Link Conditioner; Settings về trang gốc trước khi lái Wi-Fi** — quên NLC ⇒ cả buổi chậm không dấu hiệu; lái Wi-Fi từ trang NLC ⇒ runner crash "Executed 0 tests". (VSKILL §7)
23. **Airplane Mode: app dev-signed cần mạng lúc khởi chạy** (`Developer App Certificate is not trusted`) ⇒ mở app trước, cắt mạng sau; case offline luôn tự trả mạng. (cookbook, H290 #6)
24. **Mạng: ghi rõ cache lạnh/ấm** — offline vẫn vào màn Upload được nếu list template đã tải. (S2 ④)

## C. Bẫy XCUITest (kỹ thuật)

25. **Máy khoá ⇒ `Timed out while enabling automation mode` / `Unlock iPhone…` / `SBMainWorkspace … Locked`** — không phải lỗi test; Auto-Lock = Never, runner script tự chờ + retry 30×30s. (SKILL §1)
26. **Env gate `TEST_RUNNER_*` đặt TRƯỚC `xcodebuild`** — đặt sau thành build setting, test skip 0.004s trông như "đã chạy". (SKILL §4)
27. **Không dùng `isHittable`/`element.tap()` — THROW `Activation point invalid`, chết cả method dù `continueAfterFailure`; chốt `frame` rồi bấm toạ độ neo `app.coordinate(.zero)`.** — `element.coordinate()` giải element lười, element biến mất ⇒ `Failed to get matching snapshot`. (SKILL bẫy 1, VSKILL §8)
28. **Kiểm `app.state` trước mọi query** — app bị kill (đổi quyền Photos ⇒ iOS kill) hoặc app ngoài (`com.apple.mobilenotes`) chưa chạy ⇒ throw. `launch()` lại (có khi 2–3 lượt), `activate()` không dựng lại process chết. (SKILL bẫy 2)
29. **Luôn đóng PHPicker trước case sau** — còn mở ⇒ `kAXErrorServerNotFound`, dây 9 case chết ở case 6. (SKILL bẫy 3)
30. **Không tin cú bấm — đọc lại giá trị, in `✓/✗`, thử ≤3 lượt** — Airplane "bật" 4 lần mà value vẫn 0; switch đúng là element **không label** rộng 63 ở mép phải; hàng `None` của Photos chỉ là staticText. (principles §1)
31. **Nhãn thật ≠ nhãn đoán — in ra:** `Don’t Allow` (U+2019), `Wi‑Fi` (U+2011), camera `Dismiss`, `New Quick Note`, back chỉ có label. Tra ASCII trượt ⇒ popup chặn toast (TC 44 sai). (SKILL bẫy 6)
32. **Id trên view gốc gộp cả cây ⇒ `.accessibilityElement(children: .contain)`** — "Result thiếu nút Report" sai. (SKILL bẫy 5, VSKILL §2)
33. **Mốc nhận diện phải riêng cho màn cần đo + mỗi case guard tiền đề ở đầu** — TC 56 báo FAIL 3/3 lượt rồi rút lại: cửa sổ Notes còn treo, "Notes" khớp nhầm. (PLAN-V #6, 24/09)
34. **Hai tap sát nhau bị gộp ⇒ giãn ~200ms; style cần 2 ảnh ⇒ `pickPhotosUntilReady()`.** (VSKILL §8)
35. **Popup quyền app hiện chậm 13–17s sau khi deny** — timeout 15s hụt. **Đừng bấm Don't Allow sớm** (deny là iOS không hỏi lại). `denyMarkers` giữ nguyên: nhánh "bấm nút cuối" từng tự deny vĩnh viễn. (SKILL §3)
36. **Lỗi tầng runner không phải verdict:** `connection was invalidated`, `state=1` 3 lượt, `Executed 0 tests/unexpected exit` ⇒ chạy 1 suite 0 credit đã PASS để phân định rồi chạy lại. (principles §12)
37. **Đừng dùng curl từ Mac kết luận BE sống/chết** — 2 đường mạng khác; health-check bằng suite 0 credit trên chính máy. (principles §2)

## D. Gen & backend

38. **Timeout: ảnh 240s, video 420s (mạng chậm 600s); progress video đứng 99% > 30s là bình thường.** Spec "không đứng quá 30s" viết cho ảnh ⇒ MISMATCH để PO chốt, không phải bug. (VSKILL §3)
39. **BE chập là biến đo: `Try Again` ≤2 lượt, in message mỗi lượt; hỏng 3/3 ⇒ dừng nhóm gen, chạy nhóm 0 credit, ghi giờ "chưa đo được vì BE".** — 11/09 BE chết, 18 case mất verdict cả ngày (6/6 lượt kẹt 85% rồi "Something went wrong…"); 1 buổi 4/8 lượt hỏng lần đầu. (PLAN-I, VSKILL §9)
40. **Gộp case cùng màn Result vào 1 lượt gen** (Save+Share+Report = 1 credit); **nhưng case đang FAIL phải có method riêng + đối chứng dương cùng lượt** — TC 54 nằm áp chót method gộp, 1 bước trước throw là mất ảnh bằng chứng. Gate mẫu `RUN_VIDEO_TC54_ONLY`. (pre-run §9)
41. **Bug thật nằm ở nhánh thất bại; chứng minh bằng "cùng thao tác, 2 ngữ cảnh, cùng phiên"** — TC 47 Save online có toast 18:09, TC 54 offline 18:10 không gì. (VSKILL §10)
42. **Case có tiền đề trái nhau = 2 method** (Try Again ở màn failed vs Back ở màn failed; TC 48 Report sau TC 47 rời Result). (SKILL §3, report 14/09)
43. **Tiền đề tổ hợp quyền: đặt tường minh từng quyền qua Settings rồi đọc lại** (vd TC 44: Photos None + Camera authorized). (principles §14)
44. **Không bấm mù vào app nhắn tin/Mail trong share sheet** — gửi tin thật không thu hồi được; dùng case bàn giao (in bảng hướng dẫn ra terminal, mốc máy đọc được, timeout 5 phút, hết giờ ⇒ "chưa đo được" + snap). (PLAN-V)
45. **Không tự sinh ảnh nhạy cảm (gore/nudity) cho case policy** — QA cấp ảnh sẵn trong máy. (summary 23/09)
46. **Không tách/gộp TC tuỳ tiện; nếu Precondition là phép HOẶC cho 2 verdict khác ⇒ tách 1 case con và giải thích trong report** (luật không-gộp-2-nửa, user chốt 27/08). Không tự sinh case mới. (S2)

## E. Report & xlsx

47. **Verdict nhãn: PASS (kèm số đo) · FAIL · MISMATCH (app khác spec, PO chốt) · N/A (by design, chứng minh bằng dump cây) · CHƯA ĐO · BLOCKED (lý do kỹ thuật + ai + bao lâu).** Chỉ in `✅` khi assert đạt. (principles §3)
48. **Xem ảnh trước khi chốt FAIL; rút lại verdict sai bằng mục "rút lại" tường minh** — 4 kết luận sai 08–09/09 đều do "tap là xong". (PLAN-I lịch sử)
49. **Ghi md5 + mtime spec vào đầu report; verdict gắn với 1 bản spec.** Số case bị gỡ khỏi spec ⇒ giữ nguyên số các case còn lại. (pre-run §5, §8)
50. **xlsx: escape `<>&`** (bản 62 case 23/09 hỏng XML vì `<` ở TC 18); mở thử bằng zipfile+ElementTree trước khi gửi; backup trước khi ghi. (pre-run §8)
51. **Lượt N/A sau không đè kết quả thật trước; `verdict-notes.json` (đã xem ảnh) đè mọi lượt.** (H290 #10)
52. **Ngoài phạm vi, ghi sẵn lý do:** đọc pixel/codec/thời lượng video (cần ffprobe trên `resultUrl`), tỷ lệ 4:3, "đúng ảnh lần 2", cuộc gọi đến (cần SIM + FaceTime sign-in), bộ nhớ đầy, camera chụp mặt người (in ảnh đặt trước máy). (VSKILL case-to-suite-map)
