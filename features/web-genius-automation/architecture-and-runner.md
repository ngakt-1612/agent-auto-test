# Kiến trúc & runner — Genius Web automation

## Cấu trúc (`/Users/kieunga/Downloads/genius-web-automation`)
```
config.py              URL, route, timeout, CREDIT_COST, ERROR_COPY, TESTIDS (đều override bằng env)
conftest.py            fixture browser/page/auth, credit_guard, image_chain, evidence, ghi results.json
auth_manager.py        decode JWT, saved_session_error, refresh (chấp nhận 200/201), force_expire_access_token
setup_login.py         login Google 1 lần → auth.json, rồi chạy pytest
auth_status.py         in trạng thái session
helpers.py             skip_if_quota_blocked, skip_if_chain_unavailable, assert_all_visible
excel_test_runner.py   chạy pytest theo Excel (--feature/--tc/--check/--list/--write-results)
results_writer.py      đổ reports/results.json → *_Result_<ts>.xlsx
inspect_dom.py         quét DOM các màn → dom_report.txt
inspect_network.py     ghi request thật khi bấm Generate + dump HTML vùng cần soi → network_report.txt
check_templates.py     soi nút Templates
update.sh              cập nhật code từ zip, giữ .venv/auth/report
pages/                 base_page.py, home_page.py (HomePage, GalleryPage, LoginPage), generator_page.py (5 tool)
tests/                 9 file, 37 test cho 35 TC (auth, home, image, video, tools_ui, projects, credit, navigation, regression)
```
Bản cũ `selenium-project`: `pages/{login,image_generator,video_generator}_page.py`, `tests/conftest.py`, `tests/test_*`, `excel_test_runner.py` (đơn giản), `TEST_SCENARIOS.md`, `plans/2026091x-*`.

## Mapping Excel ↔ pytest
- Mỗi test gắn `@pytest.mark.tc(N)` = số N° trong Excel; tên hàm `test_tcNN_<mô tả>` (runner `--tc N` dùng `-k tcNN`).
- `FEATURE_TARGETS` trong `excel_test_runner.py`: key **phải trùng chữ** cột Feature (vd `"Image Generator"`, không phải `"Image Generator (/agent/image)"`).
- Feature không có mapping → exit code 3 (CI đỏ), không `return 0`.
- `--check`: báo feature thiếu mapping / mapping thừa → dùng mỗi khi Excel đổi.

## Markers (`pytest.ini`, `--strict-markers`)
`tc(n)`, `smoke` (~3′, 0 credit), `ui`, `mock` (page.route / set_offline), `credit` (tốn credit thật, 1 lần/ngày sau reset), `e2e`, `manual`.

## Fixtures chính (`conftest.py`)
| Fixture | Scope | Vai trò |
|---|---|---|
| `browser` | session | Chromium, headless theo env |
| `auth_tokens` | session | Refresh token **1 lần** cho cả phiên (refresh token xoay vòng, dùng 1 lần) |
| `page` | function | Context mới từ `auth.json`, đồng bộ token phiên, refresh nếu sắp hết hạn (buffer 90s), sau test sync ngược token app tự xoay |
| `unauth_page` | function | Context không login (TC3) |
| `home`/`gallery`/`image_page`/`video_page`/`generator(tool)` | function | Page object đã mở |
| `credit_guard(cost_key)` | function | Đọc credit header; thiếu / modal quota → **SKIP** |
| `image_chain` | session | Generate **đúng 1 ảnh** dùng chung cho chuỗi TC (SETUP.md ghi 12/22/24/25/31, docstring ghi 13/23/25/26/35 — lệch do đánh số lại Excel; kiểm theo marker `tc` thực tế) |
| `evidence` | autouse | Screenshot `reports/screenshots/TC<NN>.png` sau mỗi test có marker tc |
Hook `pytest_runtest_makereport` → `_RESULTS[tc] = {status PASS/FAIL/BLOCKED, duration, message, nodeid}`; `pytest_sessionfinish` ghi `reports/results.json`. Skip & xfail → BLOCKED.

## Page object (`pages/base_page.py`)
- Locator ưu tiên `data-testid` thật (đã xác nhận qua `dom_report.txt`): `credit-chip`, `header-signin`, `header-activate`, `upgrade-btn`, `social-google`, `panel-prompt`, `panel-aspect`, `panel-generate`, `tool-panel`, `tool-tile-*`, `workspace-tab-*`, `gallery-*`, `explore-tab-*`.
- `testid_or(name, fallback)`: có testid thì dùng, chưa có thì fallback role/placeholder/text → FE thêm testid không phải sửa test.
- Phần tử thiếu testid: bộ đếm ký tự (`<p>` sau `panel-prompt`, `textarea maxlength=1999`), dropdown Duration (`select[aria-label=Duration]`, value `4/8/12`, text `4s/8s/12s`), nút Style, dark mode, chuông, avatar, nút Download/Expand trên card (`figure.group`, hiện khi hover).
- Fallback thêm: thuộc tính `data-track` (vd `panel.generate`, `header.signin`).

## Endpoint quan trọng
- Generate (cả 5 tool): `POST {API}/api/v2/web/execute` → mock bằng `page.route("**/api/v2/web/execute", ...)`.
- Refresh: `POST {API}/api/v2/auth/refresh` (200 hoặc 201; token cũ bị vô hiệu ngay).
- Token lưu localStorage key `genius.tokens` (`accessToken`, `refreshToken`).

## Tool chẩn đoán
- `python inspect_dom.py` → `dom_report.txt`: testid, placeholder, role, button text, theme attr mỗi màn (home, image, video, speech, music, chat, gallery) + kiểm tra URL không tồn tại. Hạn chế: chỉ liệt kê phần tử có testid → **phải kết hợp dump innerText container** (xem rules).
- `python inspect_network.py` → `network_report.txt`: request thật khi bấm Generate, HTML panel Video, /gallery. Chạy **trước** khi viết mock.
