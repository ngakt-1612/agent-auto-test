# Luật & bài học — Genius UI toàn app

## 0. Cổng BẮT BUỘC (user chốt 19/09: «mỗi lần test auto đều phải đọc file plan trước, đấy là bắt buộc»)
Đọc HẾT plan tổng (kể cả các mục 🔄, đọc từ dưới lên) + RUNBOOK 00-A, rồi in khối này trước khi build/Appium/đụng testcase:
```
✅ Đã đọc plan UI-Baseline: Plan_UI-Baseline-ToanApp_2026-09-19_Genius.html
   · mục 11 (quy trình đã chốt) · mục 08 (thang chấm) · 🔄 mới nhất: <ngày>
   · Bộ case đang dùng: <tên file trong Testcase+Report/> — <N> case
✅ Đã đọc RUNBOOK mục 00-A · <số> quy tắc bất biến
```
Không nhớ theo trí nhớ, không suy từ session trước — quy trình có thể đã đổi. Plan nháp chỉ vào plan tổng sau khi user nói «duyệt».

## 1. Phạm vi & Expected
- Chỉ chấm cái NHÌN THẤY: đúng node Figma · đi đúng màn · trạng thái nút. Business logic ngoài phạm vi.
- **12.6 — KHÔNG test log event** (24/09). Case toàn event ⟹ bỏ, đánh lại ID (luật #18) kèm bảng đối chiếu. Case vừa UI vừa event ⟹ giữ, gỡ hẳn dòng event khỏi Step/Expected/Precondition/Actual/tên case.
- **12.1 — Chỉ đối chiếu với node Figma gắn ở cột Expected.** Không kéo nghĩa vụ policy (POL-SUB-xx của bộ SUB) hay phép tính sang bộ UI. (Vấp: case 31 UI-I2I chấm Fail vì «thiếu giá gạch ngang» — Figma không vẽ.)
- **12.2 — Không sinh case so sánh GIÁ.** Giá do RevenueCat trả theo storefront: chỉ kiểm CÓ dòng giá + đúng mẫu chữ design («Now only <giá>/week»); không so số, USD↔VND, quy đổi tuần, % giảm.
- **12.3 — Cấm tự đặt Expected.** Mỗi Expected trỏ về: dòng `events.json` ✓, 1 node Figma, hoặc 1 điều trong `sub_policy.md`. Không có nguồn ⟹ ghi quan sát vào Actual hoặc phiếu hỏi PO/BA, không thành tiêu chí Fail. Nhóm SR-INT (`derived:`) là giả định, không phải căn cứ chấm. (Vấp: case 35 «mọi câu quảng cáo phải nói đúng Genius» → bỏ.)
- **12.4 — Không đo thời gian gen, không case đo time**, kể cả app ghi «This usually takes 10–15 seconds». Màn xử lý chỉ chấm: có progress + % · % tăng dần · xong tự chuyển màn · không treo vô hạn · lỗi có báo + lối thoát. Thời gian ghi Actual làm dữ liệu cho dev.
- **12.7 — Mất mạng TRƯỚC khi gọi API: app im lặng là ĐÚNG.** Expected: đứng yên ở màn hiện tại · không trừ credit · không treo; không chấm Fail vì thiếu «No internet».
- 193/336 event `✗ code-only` KHÔNG dùng làm Expected (đáng 1 phiếu hỏi BA).
- Spec + design đều không nói ⟹ `[SPEC CHƯA ĐỀ CẬP]`, tô vàng #FFF2CC, chấm Skip, hỏi PO/BA — không tự chọn nhánh.
- Diff ≠ bug: diff chỉ nói «có đổi»; kết luận bug phải đối chiếu Expected. Checkpoint fail không đẻ thành testcase mới.
- Lỗi nằm trong chính design (vd «ReelMe» trên màn Rating Genius, «Tap a start», «Subcription», Version 1.3.0 cũ, email hard-code) = phiếu hỏi designer/BA, KHÔNG phải bug app.

## 2. Testcase
- **Luật #7 được mở riêng cho bộ UI (19/09)**: được sinh testcase từ ảnh Figma. Ngoài bộ UI vẫn cấm tự sinh.
- Thứ tự bắt buộc: **testcase TRƯỚC, test SAU** («từ ảnh đã có e nên tạo file testcase để thành kịch bản test rồi hãy test»).
- Bộ UI đếm ID riêng từ 1, KHÔNG cộng vào tổng feature (SUB vẫn 53, I2V vẫn 58).
- Dedupe trước khi map: paywall «Meet Your Best Version» xuất hiện 3 node; `19986:5521` ≡ `19986:5515`; ảnh chụp nhiều phiên/build khác nhau.
- 148 ảnh dán không diff tự động được layout/màu, nhưng DÙNG ĐƯỢC lấy Expected về copy/label (vd `19986:5517` «Supports JPG, PNG up to 10MB» chống lưng S2V-406).

## 3. Thang chấm (dùng đúng thang user — không tự đặt Match/Diff/Chưa map)
| Verdict | Khi nào |
|---|---|
| Pass | Đúng Expected (Figma / ID_trigger ✓), có ảnh kèm |
| Fail | Không khớp; Actual ghi thấy gì + ảnh → phiếu bug, mở testcase feature (Lane 3) |
| Skip | Không truy được nguồn ⟹ `[SPEC CHƯA ĐỀ CẬP]`, vàng #FFF2CC |
| Blocked | Không AI gỡ được để tới màn |
| N/A | Chỉ khi build không có tính năng |
| «Chờ» (ô trống) | Chờ NGƯỜI KHÁC gỡ; Actual: `CHỜ — cần <ai> làm <việc>, đã ping <giờ>`. Không tính vào % chưa cover |

## 4. So sánh & điều hướng (chốt 19/09)
- **Phương án C**: cây accessibility (phần tử · chữ · thứ tự) là tầng quyết định, được chấm Fail; **ảnh pixel KHÔNG tự chấm Fail** — chỉ là bằng chứng đặt cạnh ảnh Figma. Luôn bỏ vùng status bar; màn có kết quả AI thì mask vùng ảnh/video, chỉ so khung.
- Đi tới màn bằng **kịch bản ghi sẵn** ở cột đường đi của file testcase (file testcase = script). Không deeplink, không crawler tự bò (dễ chạm mua/xoá).
- App không có accessibility id → locator bám chữ hiển thị; dev đổi text là gãy → sửa kịch bản, không sửa tool.
- 2 baseline: Figma (bắt sai design, chỉ chạy khi design đổi) + build trước (bắt regression, mỗi build). Diff-với-build-trước không bao giờ bắt lỗi sai từ đầu.
- Lane 1 chỉ verify **hợp đồng trong code** (unit test gọi thẳng hàm track, không chạm UI) → báo «143 event đúng hợp đồng trong code», KHÔNG ghi «đã verify».

## 5. Cạm bẫy kỹ thuật đã gặp
- Build trong thư mục cloud-sync (`Documents - Trinh's MDT/…`) → codesign LUÔN fail («resource fork, Finder information… not allowed»); `xattr -cr` vô dụng → `-derivedDataPath` ngoài vùng sync, không dấu cách (vd `~/GeniusBuild/DerivedData-device`).
- Giữ `-disableAutomaticPackageResolution` (build không cần mạng). SSH Permission denied KHÔNG chặn SPM (20/20 package https; chỉ `AiServiceKit-Binary` là repo AperoVN — cần https token khi đổi package).
- Giải nén zip source bằng `ditto -xk`, KHÔNG `unzip` (vỡ tên file CJK, báo nhầm «disk full»).
- Zip «bản mới» có thể trùng code cũ: kiểm `unzip -z` (commit) · `diff -rq` · `MARKETING_VERSION` trước khi thay; ghi đè bừa mất `Genius.storekit` + DerivedData ~4,8 GB.
- Lane 1: PHẢI boot simulator trước (script `set -euo pipefail` + `grep Booted` → exit 1, log rỗng). `.event-tracking.json` trỏ iPhone 16 Pro không còn → dùng iPhone 17 Pro.
- Đọc kết quả `XCTAssertEqual(actualKeys, expectedKeys)`: giá trị ĐẦU là ACTUAL (suýt báo 78 bug oan do generator parse rỗng).
- `generate-event-contract-tests.py` cần 3 fix mới chạy (patch `tools/fix_generate-event-contract-tests_2026-09-07.patch`) — sửa script/source phải xin duyệt TỪNG lần (07/09 sửa 3 lần chỉ được duyệt 1, tự `xattr -cr` + xoá `.DS_Store` không hỏi = sai).
- Figma MCP: 20 lượt/tháng (seat View) → dùng REST + personal access token của user (`figma_fetch_rest.py`, không tốn quota). Token user dán vào chat ⟹ nhắc thu hồi + tạo mới. Kiểm `lastModified` của file design trước khi tin bản trích cũ.
- Firebase/Figma MCP có thể trỏ nhầm project/file → xác nhận đúng file key trước khi kết luận.
- WDA 19/09: `com.apero.wda` → CoreDeviceError 10002; Appium tự build WDA → RemoteDisconnected ⟹ gỡ WDA trước khi viết sweep.
