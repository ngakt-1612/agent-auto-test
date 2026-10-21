# Setup môi trường — Genius Web automation

## 1. Python + browser
```bash
cd /Users/kieunga/Downloads/genius-web-automation
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt     # playwright>=1.44, pytest>=8.0, pytest-html>=4.1, openpyxl>=3.1
playwright install chromium
```
- Chỉ dùng Chromium (`p.chromium.launch`). Mặc định headless; xem trình duyệt: `HEADLESS=0 SLOW_MO=300`.
- Hook của Claude Code (`scout-block.cjs`) **chặn mọi lệnh có chữ `.venv`** → agent không gọi `.venv/bin/python` trực tiếp được. Cách xử lý: tạo venv tạm trong scratchpad, hoặc nhờ user chạy trong Terminal, hoặc dùng `source` qua user. Không sửa `.ckignore` khi chưa được user cho phép.
- Python hệ thống không có `openpyxl` → đọc Excel phải dùng venv có cài.

## 2. Đăng nhập (Google OAuth, 1 lần)
```bash
python setup_login.py              # login nếu cần rồi chạy pytest -m "not credit"
python setup_login.py --login-only # chỉ login
python auth_status.py              # xem session còn hạn không
```
Luồng `setup_login.py`: mở Chromium headed → `/home` → bấm `[data-testid=header-signin]` → modal "Sign in to keep going" → `[data-testid=social-google]` → **user tự nhập tài khoản Google** (agent KHÔNG nhập mật khẩu) → chờ tối đa 5 phút tới khi localStorage có `genius.tokens` → `context.storage_state()` lưu `auth.json`.

- Nếu DOM đổi, script không crash, in hướng dẫn để user bấm tay.
- Session hợp lệ khi `auth.json` có origin `BASE_URL` + key `genius.tokens` + `refreshToken` chưa hết hạn (access token hết hạn vẫn OK vì sẽ refresh).
- `pytest_sessionstart` kiểm tra session 1 lần; lỗi → `pytest.exit(returncode=4)` kèm gợi ý chạy `setup_login.py`.

## 3. auth.json — TUYỆT ĐỐI
- Chứa cookie phiên Google còn sống (NID, OTZ…) + `genius.tokens` (access/refresh JWT).
- KHÔNG đọc nội dung, KHÔNG copy, KHÔNG in, KHÔNG đưa vào report/artifact/repo/knowledge package.
- Đã có trong `.gitignore` (`auth.json`, `*.auth.json`, `.env`). Trước mỗi push: xác nhận `git ls-files | grep auth` rỗng.
- Muốn biết trạng thái session → chạy `auth_status.py`, không cat file.

## 4. Biến môi trường (override `config.py`, không cần sửa code)
| Biến | Mặc định | Ý nghĩa |
|---|---|---|
| `GENIUS_BASE_URL` | `https://genius.style` | Web app |
| `GENIUS_API_BASE` | `https://api-ai-genius-iip055.aperogroup.ai` | API |
| `GENIUS_AUTH_FILE` | `<project>/auth.json` | Storage state |
| `GENIUS_EXCEL` | `<project>/TC_Genius_Web_Automation.xlsx` | File TC |
| `HEADLESS` / `SLOW_MO` | `1` / `0` | Hiển thị browser |
| `NAV_TIMEOUT` / `ACTION_TIMEOUT` | 30000 / 15000 ms | |
| `IMAGE_GEN_TIMEOUT` / `VIDEO_GEN_TIMEOUT` | 180000 / 300000 ms | Chờ generate |
| `CREDIT_COST_IMAGE` / `CREDIT_COST_VIDEO` | 4 / 4 | Giả định, chờ PO chốt |
| `DAILY_CREDIT_BUDGET` | 10 | |
| `ASSERT_EXACT_CREDIT` | 0 | `1` = assert trừ đúng số credit |

## 5. Cập nhật code từ zip mới
```bash
./update.sh                                   # tự lấy zip mới nhất ~/Downloads/genius-web-automation-v*.zip
./update.sh ~/Downloads/genius-web-automation-v9.zip
```
rsync bỏ qua `.venv`, `auth.json`, `reports/`, `*_Result_*.xlsx` → giữ nguyên session + kết quả cũ.
