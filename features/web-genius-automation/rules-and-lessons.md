# Rules & lessons — Genius Web automation

Định dạng: **Rule** — Why (source).

## A. Bảo mật / git
1. **Không đọc/copy/in `auth.json`; luôn gitignore** — chứa cookie Google + JWT còn sống (SETUP.md §2; transcript push 17/09: xác nhận auth.json vắng mặt trên remote).
2. **Trước push: quét secret file staged + `compileall` + chạy unit test không cần browser** — 19/09 hai test mới của `excel_test_runner` fail (`KeyError: 'action'` do loader giữ key nguyên văn header `"Action"`), agent hỏi user trước khi sửa vì vượt yêu cầu "push" (transcript f568968e).
3. **Chỉ push khi user bảo "push"**; commit tách theo chủ đề, conventional commit (memory user; transcript 18/09: 3 commit fix/feat).
4. **Ghi `.gitignore` phải có newline cuối** — lần append đầu dính vào dòng `*.png` (transcript 17/09).
5. **Không chạy test cần browser + session thật rồi tuyên bố pass khi chưa chạy** — nói rõ "chưa chạy test thật" (transcript 18/09).

## B. Quét DOM / locator
6. **Trước khi kết luận "phần tử không tồn tại": chờ đủ lâu + dump toàn bộ innerText container làm bằng chứng** — 3 kết luận sai liên tiếp (bộ đếm 0/1999, dropdown Duration 4s/8s/12s, nút Templates) vì `inspect_dom.py` chỉ liệt kê `data-testid` và test đọc `count()` ngay khi trang vừa tải (SPEC_DEVIATIONS A, B, I).
7. **Assertion message phải kèm nội dung đang render** — nhờ vậy mới thấy `4s | 8s | 12s` (SPEC_DEVIATIONS B).
8. **Nút Templates render muộn → `wait_for_tools_templates()` tối đa 15s** (SPEC_DEVIATIONS I).
9. **Có 2 nút "Templates" (Tools panel trái + `workspace-tab-templates`) → locator phải scope theo container**, nếu không Playwright strict mode violation (SPEC_DEVIATIONS I).
10. **Download/Expand trên card kết quả ẩn (`opacity-0`) → hover `figure` trước rồi click** (SPEC_DEVIATIONS H).
11. **`select` Duration: value là số `4`, text là `4s` → xử lý cả hai** (SPEC_DEVIATIONS B).
12. **Heading Home đổi theo giờ → regex `morning|afternoon|evening|night`**, không hardcode (commit 39d47b7).

## C. Network / mock
13. **Ghi network log trước khi viết mock, không đoán endpoint** — mock cũ dùng regex `(generate|image|job|task)` không chặn được gì, TC 12/15/28/29 chạy vào server thật; endpoint đúng `/api/v2/web/execute` (SPEC_DEVIATIONS J).
14. **TC lỗi server/offline/XSS dùng `page.route` hoặc `context.set_offline`** → 0 credit (SETUP.md §5).

## D. Auth / session
15. **Refresh token 1 lần cho cả suite (`auth_tokens` session-scope)** — refresh token rotation: test đầu refresh làm chết token các test sau → cả suite 401 (conftest docstring; SPEC_DEVIATIONS F).
16. **Sau mỗi test sync ngược token** — app tự gọi refresh khi đang chạy (conftest `page`).
17. **Chấp nhận HTTP 200 và 201 cho refresh; buffer 120s** — bản cũ chỉ nhận 201, buffer 60s rớt giữa suite 30′ (SETUP.md §8).
18. **TC hết hạn token dùng `force_expire_access_token()`**, không chờ 15 phút (SETUP.md §8).
19. **Session check 1 lần ở `pytest_sessionstart`** → tránh 32 test cùng báo lỗi auth (conftest).

## E. Credit / phân loại kết quả
20. **Hết credit / modal "You've reached your usage limit" → SKIP/BLOCKED, không FAIL** — vấn đề môi trường; nếu FAIL nightly đỏ mỗi ngày, team bỏ đọc report (helpers.py, SETUP.md §5).
21. **Gom generate: `image_chain` 1 ảnh cho nhiều TC, 1 video cho TC17** — budget 10 credit/ngày, 7 TC cần generate thật (~28 credit) → nightly ~8 credit (SETUP.md §5).
22. **Giá trị chưa chốt (giá credit, copy lỗi) để trong `config.py`, test dùng `xfail`/không assert exact** → PO trả lời chỉ sửa config (SETUP.md §7).
23. **Bug đã xác nhận → `xfail(strict=True)`** để khi FE fix, XPASS làm đỏ nhắc gỡ marker (SPEC_DEVIATIONS C).
24. **Feature thiếu mapping → exit ≠ 0**; bản cũ `return 0` làm CI xanh giả, 10/12 nhóm bị bỏ qua âm thầm (excel_test_runner docstring).
25. **Ghi kết quả ra file `_Result_<ts>.xlsx`, không sửa file TC gốc** (results_writer; khớp luật qa-e2e #13: xlsx của user chỉ để ĐỌC).

## F. Spec deviations đã biết (genius.style, 21–22/09/2026)
| Mã | Nội dung | Trạng thái |
|---|---|---|
| A/B/I/H | Counter 0/1999, Duration, Templates, Download — **có tồn tại** (kết luận cũ sai) | Đóng; đề xuất FE thêm testid `panel-prompt-counter`, `panel-duration` |
| G | Đã login: `upgrade-btn` "Upgrade"; chưa login: `header-activate` "Activate" | Đúng thiết kế |
| D | `/home` không redirect khi chưa login, chặn bằng modal "Sign in to keep going" | Sửa Expected TC3 |
| J | Endpoint generate `/api/v2/web/execute` | Đã sửa mock |
| K | `/gallery` chỉ có project card (Project options, Delete) — không Download; Download ở Creations feed | TC24 đổi, thêm 24b |
| L | `/plans` 3 gói (Weekly $9.99/140cr, Monthly $19.99/600cr, Yearly $49.99/7200cr), **không có Terms/Privacy** | Chờ PO |
| C | URL rác (`/agent/unknown-tool`, `/agent/abc123`, `/khong-ton-tai`, `/gallery/abc123`) đều redirect `/agent/image`, không 404 | **BUG**, xfail strict, cần Jira |
| E | Không thông báo lỗi ERR_AUTH_001 / ERR_NET_001 / ERR_NET_003; credit không trừ khi 500 (đúng) | xfail, chờ tester |
| F | Refresh token single-use (token cũ → 401) | Đã thêm TC 5b/6 |
| — | Video chọn 4s render ra 5s | Cần kiểm tra lại (chưa xác minh) |

## G. Flaky points
- Phần tử render muộn (Templates, workspace) → luôn `wait_for(...)` thay vì `count()` tức thì.
- Generate thật: 1–5 phút, phụ thuộc quota server → timeout 180s/300s, kết quả `quota_blocked` → skip.
- Token rotation giữa suite dài; nightly nên chạy ngay sau khi refresh.
- `page.go_back()` có thể restore từ bfcache ≠ click sidebar (điều hướng mới) — test "history giữ sau điều hướng" nên click sidebar đúng mô tả TC (transcript 18/09, chưa xác minh đã sửa).
