# Sinh TC cho automation — Genius iOS 2.9.0

Áp dụng khi user nói "tạo testcase để chạy automation test" từ spec Confluence. Luật chung ở `../../common/working-rules.md` §2; file này là chi tiết đã chốt cho Genius 2.9.0.

## Quy trình đã dùng
1. Đọc spec qua Confluence MCP (`confluence_get_page` pageId 323393416; ảnh đính kèm khi cần). Đọc 100% (spec ~465 dòng, 13 mục + Pre-Rollout).
2. Skill `anthropic-skills:qa-testcase-generator` — **Mode G** (sinh TC từ spec): SPEC_CONTEXT → soát spec → Ambiguity → TC plan theo tính năng → xuất xlsx.
3. Đọc code app (`<source>/iosApp/Features/...`) để biết nhãn thật, id, giới hạn → ghi vào cột M (ghi chú automation). Vd: Chat `ChatScreen.swift`, Library `LibraryScreen.swift`.
4. Sinh file bằng script Python (openpyxl) → `~/Downloads/TC_<App>_v<ver>_<Scope>.xlsx` **và** `spec-cases.json` (cho report). Mẫu: `templates/gen_ai_chat_testcases.py <out.xlsx> <spec-cases.json>`.
   - openpyxl có ở `python3` thường (user site, 3.1.5) — KHÔNG có khi chạy `python3 -I`.
5. Gửi user tóm tắt (số TC, Auto/Auto + setup, Ambiguity chính) → chờ user "chốt".

## Luật user đã chốt (18/10, áp dụng lại 20/10)
| Luật | Nguồn |
|---|---|
| Scope theo user nói: lần 1 chỉ **Update UI + Library**, AI Chat làm sau (lần 2) | 18/10 "hiện tại chỉ tạo testcase của scope Update UI+Library, AI Chat để sau" |
| **Không có TC manual.** Bản đầu 122 TC (70 Auto / 37 Semi / 15 Manual) → bỏ 15 Manual | 18/10 "bỏ các testcase manual, tại sao có đến 37 case test bán tự động…" |
| Không gọi "Semi" — case script được nhưng cần dựng môi trường = **`Auto + setup`**, cột M ghi cần dựng gì | cùng tin trên |
| **Bỏ case giả lỗi server, làm chậm server, đổi giá trị Remote Config** (107 → 84 TC) | 18/10 "bỏ các case giả lỗi, làm chậm server, đổi gía trị remote config" |
| Case chỉ *yêu cầu* RC đang bật sẵn (vd `enable_ai_chat_feature = true`) thì GIỮ — đó là tiền đề, không phải đổi RC | lần lọc lại 18/10 (đã giữ TC-LIB01-003, 2 case màu tab) |
| Case cần lỗi/timeout server thật: chỉ chấm khi **gặp thật** khi chạy, không bơm lỗi | Automation Setup sheet AI Chat |
| TC viết cho **máy thật** (devicectl, Airplane qua Settings), không simulator | 18/10 "chốt testcase trên, sẽ chạy auto trên máy thật" |
| File AI Chat phải **cùng khuôn 13 cột + cùng kiểu TC ID** với file UI/Library để gộp được | memory genius-v290-testcase-scope |

## Format 13 cột (A–M) — sheet TC
`N° | Feature | Test Description | Sub-scenario | Precondition | Test Data | Action | Expected Result | PASS/FAIL | TC ID | Priority | Automation | Ghi chú automation`
- Hàng 1: dòng nguồn spec (vd `spec: Genius 2.9.0 — IIP055.1.20 AI Chat (pageId 323393416 §3–11) — scope: …`). Hàng 2: header. Có hàng nhóm `▌ <Feature>` ngăn các nhóm.
- 9 cột đầu theo mẫu UTM; 4 cột thêm cho automation: **TC ID** (`TC-<NHÓM><nn>-<nnn>`, vd `TC-CH07-002`), **Priority** (critical/high/medium/low), **Automation** (`Auto` | `Auto + setup`), **Ghi chú automation** (cách assert / harness).
- Precondition đánh số, có dòng tiền đề chuẩn: `1. App Genius 2.9.0 đã cài, mở app tới Home (301)\n2. RC: enable_ai_chat_feature = true` (+ gói/lượt/trạng thái cuộc trò chuyện). Các hằng BASE/SUB/NOSUB/EMPTY/HASRES/TWORES/VIBES trong generator.
- Action/Expected đánh số dòng; Expected ghi chuỗi UI chính xác (tiếng Anh như app) khi biết.
- Mã màn theo spec: 301 Home · 901 Chat · 902 màn xem kết quả · 236 paywall Chat · 238 last-chance · 237 topup · 481 hộp thoại hết lượt.

## Sheet phụ (bắt buộc)
| Sheet | Nội dung |
|---|---|
| **Ambiguity** | `# | Mục spec | Điểm mơ hồ — cần PO/BA confirm | TC liên quan`. Mã U*/L* (UI/Library), C* (Chat). Gắn tag `[⚠️ AMBIGUOUS C1]` trong cột M của TC liên quan |
| **Automation Setup** | `Hạng mục | Ghi chú`: Platform, Cài app/runner, Chọn element, Tài khoản/Trạng thái gói, Lượt tạo, Mạng, Dữ liệu ảnh/video, Remote Config, **Đã loại** (liệt kê case bị bỏ + lý do), Ngoài scope |
| **Summary** | `Feature | Số TC | Auto | Auto + setup | critical | high | medium | low` |

## Ví dụ Ambiguity đã ghi (dùng lại khi spec đổi)
- L1: §13 nhắc lọc Photo/Conversation, §12 chỉ All·Image·Video. L3: §13 "lượt vẫn bị trừ" vs Chat §4 "lỗi không trừ". L5: chuỗi lẫn EN/VN.
- C1: spec thông báo tiếng Việt, app chỉ tiếng Anh → **chấm theo nghĩa**. C2: "Up to %d characters". C4: kết quả về muộn sau 180 s có trừ lượt? C7: "hoàn lượt" vs "không trừ". C10: hết lượt = hộp thoại 481 hay màn topup? C11: RC false không sinh TC (user không đổi RC).

## Ghi chú harness hay dùng ở cột M
- Mất mạng: Airplane Mode + tắt Wi-Fi qua app Settings (`SettingsNetworkDriver`), luôn trả mạng ở `defer`.
- Gói/hết hạn: Sandbox Apple ID đăng nhập sẵn; chờ hết hạn thật (probe 10 phút); huỷ gói trong app.
- Gỡ/cài lại: `xcrun devicectl device uninstall app …` (case gỡ app xếp cuối vì mất dữ liệu/lịch sử Chat).
- Quyền Photos: `SettingsPhotosDriver.setAccess("None"|"Full Access")`.
- Đếm ảnh Photos: `PHAsset.fetchAssets` (target UI test cần `NSPhotoLibraryUsageDescription`).
- So màu/kính: tỉ lệ pixel tím/đỏ, `regionSignature` — không cần ảnh chuẩn.
- Lượt tạo: mỗi lần gửi Chat trừ 1, 20 lượt/ngày → gom nhiều TC vào 1 lần gửi.

## Danh mục đã loại khỏi file UI/Library (để biết KHÔNG thêm lại)
- 15 manual: chuyển động (Home/Upload/Generating/Library/khay), chữ Trends tím, nút bỏ tím, cuộn nhanh, đồng bộ 2 máy, gói Stripe, Apple→Stripe, gộp topup sang máy khác.
- 10 đổi RC: tắt Chat (3 tab), tắt Try-on, Start creating khi tắt Chat, 7 case `home_banner_texts`.
- 13 giả lỗi server: xoá lỗi 500/timeout 15 s/xoá một phần, Gen Failed, công cụ Create lỗi, ErrorCollapse, khay lỗi, thử lại từ khay, trừ lượt khi lỗi, `Tap to retry`, hero ảnh lỗi, dải thứ 6 rỗng.
- Phần không còn được test → nói rõ với user ("mọi trạng thái lỗi tạo nền/xoá", "home_banner_texts").

## Checklist trước khi giao file TC
- [ ] 0 TC manual; cột L chỉ `Auto` / `Auto + setup`; mỗi `Auto + setup` có cột M nói rõ setup.
- [ ] Không TC nào cần đổi RC / proxy / mock server.
- [ ] TC ID liên tục theo nhóm, không trùng file cũ; spec-cases.json khớp ID với xlsx (20/10 từng lệch 5 mã CH02 → phải sửa cả notes và test).
- [ ] Ambiguity + Automation Setup + Summary đầy đủ.
- [ ] Tóm tắt cho user kèm phần spec KHÔNG còn được test.
