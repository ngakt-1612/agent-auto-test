# Luật & bài học — Genius iOS Subscription Sandbox

Nguồn: RUNBOOK mục 00-A (user chốt 07/09/2026: «chị đã nhắc nhiều lần rồi mà em vẫn lặp lại như thế là không được») + plan SUB. Mỗi lần vấp lại ⟹ tăng số lần vấp ở RUNBOOK 00-A, đừng chỉ thêm ghi chú cuối.

## A. 19 QUY TẮC BẤT BIẾN (tóm tắt — bảng đầy đủ ở RUNBOOK 00-A)
> Plan UI-Baseline 19–24/09 ghi RUNBOOK đã lên **22–25 luật**; bản RUNBOOK trong `~/qa-e2e/genius/` hiện có 19. Luôn đếm lại trong RUNBOOK mới nhất, đọc thêm luật mới ngoài bảng này.
| # | Luật | Dấu hiệu tự phát hiện |
|---|---|---|
| 1 | Đọc HẾT `plan tổng/` (runbook + mọi plan con, mục 🔄 đọc từ dưới lên) trước khi build/Appium/đụng testcase | Sắp build mà chưa in được «✅ Đã đọc plan tổng: <file>» |
| 2 | Chỉ mở round khi user bảo «check round mới»; hết round BÁO rồi DỪNG, không tự mở round/feature khác | Định chạy tiếp «cho đỡ trống» |
| 3 | Một round = chạy HẾT case làm được; tốn thời gian/phải mua/dựng state/chờ ≠ lý do dừng | Báo «xong round» khi mới xong 1 nhóm |
| 4 | **Chờ người khác gỡ ⟹ «Chờ» (ô Status TRỐNG, Actual: «CHỜ — cần <ai> làm <việc>, đã ping <giờ>»), KHÔNG Blocked.** Blocked chỉ cho thứ không ai gỡ được | Blocked > nửa bộ case ⟹ chắc chấm sai |
| 5 | **Bàn giao mua 5 bước không đảo**: tới đúng màn → chọn sẵn gói → chụp ảnh → MỚI ping (verify `mentions[]` không rỗng) → DỪNG HẲN. Auto-Lock=Never, KHÔNG tự tap Continue. Áp cho MỌI lần xin mua | Tin ping có chữ «mua» mà ảnh không phải paywall |
| 6 | Chờ user mua: KHÔNG đụng máy (không Appium/Settings/quyền/NLC/Auto-Lock/cài lại/**reboot**/case khác). Được: sửa report/plan/script, phân tích | Vừa ping mà đang gõ lệnh gen_drive/net_drive/devicectl |
| 7 | KHÔNG tự sinh testcase. Sheet có cột ID mới là case; bảng tra cứu không nở thành case. Chỉ được tách case gộp 2 nửa | Tổng case khác bộ gốc |
| 8 | Report chỉ gen khi round CHẠY XONG (còn «Chờ» = chưa xong). Đủ bộ case, % trên tổng bộ, 5 chỉ số % + thời gian, không dùng chữ «gộp Round» | Định gen HTML khi còn dòng «Chờ» |
| 9 | Không tự đặt thang chấm: chỉ Pass · Fail · Skip · N/A · Blocked (+ «Chờ» = ô trống) | Report có tên ô lạ (Match/Diff…) |
| 10 | **Cửa sổ state ngắn** (Weekly ~18′ · Yearly ~1h · gói lẻ ~45′): liệt kê trước danh sách case phụ thuộc + thứ tự; việc cần tay user / phá state xếp TRƯỚC TIÊN; relaunch đọc header sau mỗi case | Bắt đầu cửa sổ mà chưa có danh sách |
| 11 | Đối chứng (tap 1 phần tử cùng loại đã biết chạy) + ảnh trước khi kết luận «X lỗi» — `/source` có thể vẫn báo màn cũ khi sheet hệ thống phủ lên | Viết «không hoạt động» mà chưa có đối chứng + ảnh |
| 12 | Kiểm tiền đề luật cũ; số đo cũ không phải hằng số; tên key RC tra trong build + console | Dùng con số round trước không đo lại |
| 13 | **Không tự diễn giải điều kiện case** (trích nguyên văn Precondition); **xlsx của user chỉ ĐỌC** | Lý do Chờ có chữ không có trong bộ case |
| 14 | «Chờ» chỉ cho việc CHỜ NGƯỜI KHÁC; mỗi dòng Chờ trả lời: ai gỡ? · đã ping? · số đo nào chứng minh mình không tự làm được? | User hỏi «sao vẫn chờ tận N case?» |
| 15 | Mọi thao tác map về 1 case ID; không tự thao tác «dựng state» ngoài Step; không tự đổi tổng case đã chốt (SUB = 53) | Không trả lời được «thao tác này thuộc case nào?» |
| 16 | Đầu round xác nhận BỘ CASE MỚI NHẤT: file folder (mtime) + link trong kênh `bot_sub` + hỏi user nếu lệch | Số case khác con số user nói |
| 17 | «Chạy lại» ⟹ Round 1, bộ case từ trắng; chỉ «chạy tiếp» mới n+1 | Ghi số round >1 khi user nói «chạy lại/bắt đầu» |
| 18 | ID testcase = số tịnh tiến từ 1, mỗi file đếm riêng; tách case chèn số tiếp, không hậu tố a/b; giữ bảng đối chiếu ID cũ→mới; nhắc case kèm tên file («LogOut#7») | ID có chữ, hoặc file không bắt đầu từ 1 |
| 19 | **Đầu ra chỉ HTML «testcase + report»**, bỏ results_round*.json; ghi verdict vào HTML NGAY sau mỗi case | Sắp tạo file .json |

### Cổng bắt buộc — in đủ trước khi bắt đầu round
```
✅ Đã đọc plan tổng: <liệt kê từng file>
⛔ Đã đọc 19 QUY TẮC BẤT BIẾN (00-A) — hay vấp: #4 #5 #8 #10 #13 #14 #15 #16 #17 #18 #19
📌 Quy tắc áp dụng round này: <3–6 gạch>
📋 Bộ testcase: <số case, file/sheet nào>
▶️ Bắt đầu: <việc đầu tiên>
```
### Cổng trước MỖI lần ping xin mua / thao tác tay
```
🖥️ Màn hiện tại (đọc /source): <tên màn> → đúng màn cần bấm? [có/không]
🎯 Gói đã chọn sẵn: <Weekly/Yearly> → verify radio trong ẢNH
📸 Ảnh: <đường dẫn>
🔒 Auto-Lock = Never · NLC = off
📨 mentions[] sau khi ping: <danh sách> → rỗng là gửi lại
⛔ Từ giờ KHÔNG đụng máy
```

## B. Nguyên tắc chung của runbook
- Không sửa source để test (chỉ để build được, phải báo/duyệt). Không ghi ngược Confluence.
- Pass chỉ khi quan sát đúng Expected lấy từ spec (không bịa từ code). Spec mơ hồ → Skip, tô vàng #FFF2CC.
- Bước có điều kiện (vd Reset onboarding) → hỏi user đúng 1 lần, lưu quyết định. Genius: KHÔNG Reset OB (chốt 22/08).
- Mọi file tạo mới gắn ngày `_YYYY-MM-DD` trước đuôi, không ghi đè bản cũ.

## C. Sub / credit — số đo & bài học
- **Credit: KHÔNG fake / mock / đổi response / nhờ BE seed — kể cả không được đề xuất** (user chốt 26/08). Credit chỉ test bằng thao tác thật. Nhóm credit = 0 chạy CUỐI.
- Credit = 0 chỉ dựng bằng gen cạn thật (Free vẫn gen được, paywall không chặn). Dừng ở credit = 1 chạy S2V-E12 trước rồi mới về 0.
- Số dư Free KHÔNG reset hằng ngày (đo 27/08) → cửa sổ credit = 0 không gấp. «20 AI creations every day» là quyền lợi Pro.
- Thời gian gen: ~36 s khi có credit (đo 07/09); số cũ «5 phút/gen» là của state khác → cạn 60 lượt ≈ 40–60′, không phải 6h (luật #12).
- Mua Weekly 07/09: credit 0 → 20, dùng được thật. Mua Yearly 27/08, 28/08: KHÔNG cộng → Y-2b Fail nặng; chưa rõ bug chỉ ở Yearly hay đã fix ⇒ báo dev theo từng gói, mua lại Yearly để chốt.
- Hết hạn sub thu hồi luôn credit đã cộng (18 lượt mất sạch) — không để dành lượt.
- Luật mua đúng (đính chính 28/08): «ở các ĐIỂM CHẠM không mua lại trong cùng 1 round» — KHÔNG phải «chỉ mua 1 lần/round». Weekly là điểm mua khác Yearly → vẫn phải chạy, ping xin mua.
- Sandbox: Weekly ≈ 3′/chu kỳ, tối đa ~6 lần renew (~18′); Yearly ≈ 1h. Sub round trước không còn → coi máy là Free đầu round.
- **Đầu round phải RELAUNCH (terminate_app + activate_app) rồi mới đọc state Free/Pro** — sáng 28/08 sub đã hết vẫn không hiện nút «Pro» cho tới khi relaunch.
- Round có case cancel Weekly: CANCEL TRƯỚC TIÊN (1–2′ đầu), rồi mới case xác nhận Pro/gen (mất W-4a 07/09 vì Weekly đã Expired).
- Số lớp paywall phụ thuộc điểm chạm + state: Free 2 lớp (Meet Your Best Version → Limited Offer 50% OFF); đã sub mà BE chưa cộng quota 3 lớp (+ offer lẻ 0.99$); nút Pro ở Home 1 lớp ⇒ đóng TỪNG lớp và đọc /source sau mỗi lần.
- LO-*: điều kiện thật là «App đang lưu 1 email đã verify / Premium đến từ email» — KHÔNG phải «email Stripe» (chữ agent tự đặt rồi ghi đè vào xlsx, round sau đọc lại tưởng thật). Nhập `qa202` vào [410] → «Email not found…». Cần 1 email đã mua gói trên web.
- D-1 không dựng được: bản Debug ký dev thì StoreKit luôn Sandbox.

## D. Điều khiển máy — bài học kỹ thuật
- App chưa có accessibility id → match theo chữ hiển thị (app mặc định tiếng Anh).
- Alert hệ thống không có trong XML source WDA → `GET /session/{id}/alert/text`, `POST …/alert/accept|dismiss`, chụp ảnh làm bằng chứng.
- Switch trong iOS Settings chỉ ăn khi tap đúng control bên phải (x≈331 pt trên iPhone 14 Pro); `element/click` không ăn → luôn đọc lại value.
- Row trong [Setting] của app phải tap vào NHÃN (x≈117), tap tâm row (x=196) không ăn.
- Đổi quyền Photo/Camera → iOS kill app → `activate_app` lại, điều hướng từ Home.
- `devicectl device info apps` báo rỗng trên iOS 26 là SAI; cài đè giữ container/quyền/credit.
- Progress gen dừng 85% = chờ BE, không phải treo.
- Session Appium chết khi nghỉ lâu → tạo lại session + `activate_app` (state máy giữ nguyên). `newCommandTimeout` ≥ 900. KHÔNG reconnect khi bảng password đang mở.
- Cắm USB, Auto-Lock = Never; Wi-Fi hay «socket hang up».
- KHÔNG dùng deeplink `geniusopenapp`: bị app khác trên máy chiếm («"Motyn" Beta Has Expired» chặn tap ~5′).
- Số dư đọc được: Setting → «My Balance» → «Today's available creations: N»; «Get More» → [Top-up creations] (1 Creation 29.000đ).
- Force-update: store lên version cao hơn bản QA → «Update Required» chặn toàn app. User duyệt tắt trong CODE bản QA (`return false` đầu `shouldShowForceUpdate()`, comment `[QA-ONLY]`, giữ `ForceUpdateRepositoryImpl.swift.ORIGINAL`); KHÔNG tắt bằng RC (`show_force_update` là cờ production). **Kiểm cờ force-update TRƯỚC khi mở round** (08/09 mất 2h13′ = 77,5% thời gian máy).
- Firebase MCP có thể trỏ nhầm project (đã đọc nhầm `iip036-boopix-dev` 08/09) → không kết luận «key RC không tồn tại»; tên key + default tra trong `RemoteConfigKeys.swift`, trạng thái console cần quyền đọc project `iip055-genius`.
- Discord ping phải có @mention và đọc lại tin kiểm `mentions[]` (HTTP 200 ≠ user nhận được). Tên file đính kèm không dấu/space (tránh lỗi 400).

## E. Quan hệ với `common/working-rules.md`
- «Tự chạy tiếp không chờ nhắc» áp TRONG round (luật #3); KHÔNG tự mở round mới (luật #2).
- Thang chấm của feature này (#9) thay bảng phân loại chung; MISMATCH/CHECK không dùng ở đây (spec mơ hồ → Skip).
