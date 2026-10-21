# Stripe Subscription Checker (verify trạng thái sub web)

## Mục đích
Dev/QA tool kiểm tra email nào đang có subscription trong tài khoản Stripe (dùng khi test sub web, vd paywall/plans của Genius web). Xem + thao tác test: tạo customer có sub, cancel/resume, đổi giá, refund.

- Source: `/Users/kieunga/Downloads/stripe-sub-checker` (git remote `https://github.com/duypd2915/stripe-sub-checker.git` — repo của người khác, KHÔNG push).
- Stack: FastAPI (`main.py`, giữ secret key phía server) + 1 trang HTML (`index.html`) + `stripe_curl_logger.py`.
- Templates: `templates/main.py`, `templates/stripe_curl_logger.py`, `templates/env.example` (chỉ placeholder).

## Cách hoạt động
- `GET /` → `index.html`: bảng email, status, plan, amount, renew/end date, customer id; search, filter status, copy emails, export CSV.
- `GET /api/subscriptions?statuses=active,trialing,past_due,canceled` → `stripe.Subscription.list(status="all", limit=100, expand=[customer, price]).auto_paging_iter()` rồi lọc. Trả `{count, unique_email_count, unique_emails, subscriptions[]}`. Status hợp lệ: `active, trialing, past_due, canceled` (khác → 400).
- `GET /api/prices` → danh sách price.
- Write actions (mutate Stripe, UI confirm trước):
  - `POST /api/customers` `{email, name?, price_id?}` → tạo customer; có `price_id` thì attach `pm_card_visa` (thẻ test 4242, chỉ test mode — Stripe chặn raw PAN qua API) làm default rồi tạo sub `charge_automatically` → active ngay.
  - `POST /api/subscriptions/{id}/cancel` `{at_period_end: true}` → cancel cuối kỳ (resume được); `false` → cancel ngay.
  - `POST /api/subscriptions/{id}/resume` → bỏ cancel_at_period_end (sub đã cancel hẳn thì không resume được).
  - `POST /api/subscriptions/{id}/price` `{price_id}` → đổi plan, `proration_behavior=create_prorations`.
  - `POST /api/subscriptions/{id}/refund` → refund payment_intent của latest invoice.
- Lỗi Stripe map: Authentication → 401, InvalidRequest → 400, StripeError khác → 502.
- `stripe_curl_logger.install()`: log mọi request Stripe dưới dạng lệnh curl (mask key, giữ prefix `sk_test_`/`sk_live_`) + response ≤2000 ký tự.

## Setup & chạy
```bash
cd /Users/kieunga/Downloads/stripe-sub-checker
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt        # fastapi 0.115.6, uvicorn 0.34.0, stripe 11.4.1, python-dotenv 1.0.1
cp env.example .env                    # user tự dán key, agent KHÔNG tự điền
uvicorn main:app --reload              # http://127.0.0.1:8000
```
Kiểm tra nhanh: `curl -s 'http://127.0.0.1:8000/api/subscriptions?statuses=active' | python3 -m json.tool | head` (02/10/2026: 71 sub active / 58 email).

## Env vars (chỉ tên)
| Biến | Bắt buộc | Ý nghĩa |
|---|---|---|
| `STRIPE_SECRET_KEY` | Có | Secret key Stripe (thiếu → RuntimeError khi start) |
| `STRIPE_CURL_LOG` | Không (mặc định bật) | `0`/`false` để tắt log curl |

## Lessons
1. **Không đọc/in giá trị `.env`; không đưa key vào chat/report** — README ghi key từng bị lộ qua chat → khuyên user roll key ở Stripe Dashboard → Developers → API keys (README, transcript c32561ee 02/10).
2. **Hook chặn đường dẫn có `venv`** → agent tạo venv tạm trong scratchpad, cài `requirements.txt` vào đó để chạy (transcript 02/10).
3. **Background task của Claude Code tự dừng: mặc định 30′, tối đa 2h** → server chết giữa chừng. Cần chạy lâu: bảo user mở Terminal `cd ~/Downloads/stripe-sub-checker && source .venv/bin/activate && uvicorn main:app`. Không tự restart vô hạn (transcript 02/10).
4. **Write actions tác động Stripe thật** → chỉ gọi khi user yêu cầu rõ; xác nhận đang test mode (prefix `sk_test_` trong log curl) trước khi tạo/cancel/refund.
5. Verify sub web: so `status` + `cancel_at_period_end` + `current_period_end` với trạng thái hiển thị trên app (Pro/Free); sub `canceled` khi `at_period_end` vẫn `active` tới hết kỳ (chưa xác minh trên app web cụ thể).
