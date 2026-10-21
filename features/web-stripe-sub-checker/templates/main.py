"""
Stripe Subscription Checker — simple dev tool.

Lists subscriptions from your Stripe account, joins with the customer to show
which emails currently have a subscription. Secret key stays on the backend.

Run:
    cp env.example .env   # then paste your FULL Stripe secret key into .env
    pip install -r requirements.txt
    uvicorn main:app --reload
    open http://127.0.0.1:8000
"""
import logging
import os
from pathlib import Path
from typing import Optional

import stripe
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel

import stripe_curl_logger

load_dotenv()

STRIPE_SECRET_KEY = os.getenv("STRIPE_SECRET_KEY", "").strip()
if not STRIPE_SECRET_KEY:
    raise RuntimeError(
        "STRIPE_SECRET_KEY is not set. Copy env.example to .env and paste your key."
    )
stripe.api_key = STRIPE_SECRET_KEY

# Log every outgoing Stripe call as an equivalent curl (secret key masked).
# Toggle off by setting STRIPE_CURL_LOG=0 in your .env.
if os.getenv("STRIPE_CURL_LOG", "1").strip() not in ("0", "false", "False", ""):
    logging.basicConfig(level=logging.INFO)
    logging.getLogger("stripe.curl").setLevel(logging.INFO)
    stripe_curl_logger.install()

# Statuses we treat as "has a subscription" and let the user filter on.
ALLOWED_STATUSES = {"active", "trialing", "past_due", "canceled"}

app = FastAPI(title="Stripe Subscription Checker")
BASE_DIR = Path(__file__).resolve().parent


def _fmt_amount(sub) -> str:
    """Best-effort human-readable price for a subscription."""
    try:
        item = sub["items"]["data"][0]
        price = item["price"]
        amount = price.get("unit_amount")
        currency = (price.get("currency") or "").upper()
        if amount is None:
            return "—"
        value = amount / 100
        recurring = price.get("recurring") or {}
        interval = recurring.get("interval")
        suffix = f"/{interval}" if interval else ""
        return f"{value:.2f} {currency}{suffix}"
    except (KeyError, IndexError, TypeError):
        return "—"


# Product names, keyed by product id. Products rarely change, so caching across
# requests avoids re-fetching the same product for every subscription.
_product_name_cache: dict[str, str] = {}


def _product_name(product) -> Optional[str]:
    """Resolve a price's product to a display name. `product` is a dict when
    expanded, or a plain id string when not (we only expand 4 levels deep, so
    the product comes back as an id and is fetched lazily here)."""
    if isinstance(product, dict):
        return product.get("name") or product.get("id")
    if isinstance(product, str):
        if product not in _product_name_cache:
            try:
                fetched = stripe.Product.retrieve(product)
                _product_name_cache[product] = fetched.get("name") or product
            except stripe.error.StripeError:
                _product_name_cache[product] = product
        return _product_name_cache[product]
    return None


def _plan_name(sub) -> str:
    try:
        item = sub["items"]["data"][0]
        price = item["price"]
        nickname = price.get("nickname")
        if nickname:
            return nickname
        return _product_name(price.get("product")) or price.get("id") or "—"
    except (KeyError, IndexError, TypeError):
        return "—"


def _period_end(sub):
    """current_period_end lives on the subscription in old API versions and on
    the item in newer ones — check both."""
    end = sub.get("current_period_end")
    if end:
        return end
    try:
        return sub["items"]["data"][0].get("current_period_end")
    except (KeyError, IndexError, TypeError):
        return None


def _first_item(sub):
    try:
        return sub["items"]["data"][0]
    except (KeyError, IndexError, TypeError):
        return None


def _ids(sub) -> dict:
    """Extract item / price / product ids so the UI can act on them.
    We only expand 4 levels, so price.product is a plain id string."""
    item = _first_item(sub) or {}
    price = item.get("price") or {}
    product = price.get("product")
    product_id = product.get("id") if isinstance(product, dict) else product
    return {
        "item_id": item.get("id"),
        "price_id": price.get("id"),
        "product_id": product_id,
    }


def _customer_email(sub) -> str:
    cust = sub.get("customer")
    if isinstance(cust, dict):
        return cust.get("email") or "(no email)"
    return "(unknown)"


@app.get("/")
def index():
    return FileResponse(BASE_DIR / "index.html")


@app.get("/api/subscriptions")
def list_subscriptions(
    statuses: str = Query(
        "active,trialing,past_due,canceled",
        description="Comma-separated statuses to include.",
    )
):
    wanted = {s.strip() for s in statuses.split(",") if s.strip()}
    invalid = wanted - ALLOWED_STATUSES
    if invalid:
        raise HTTPException(status_code=400, detail=f"Invalid statuses: {sorted(invalid)}")

    rows = []
    try:
        # status="all" returns every subscription; we filter to the requested set.
        iterator = stripe.Subscription.list(
            status="all",
            limit=100,
            expand=["data.customer", "data.items.data.price"],
        ).auto_paging_iter()
        for sub in iterator:
            if sub.get("status") not in wanted:
                continue
            rows.append(
                {
                    "email": _customer_email(sub),
                    "status": sub.get("status"),
                    "plan": _plan_name(sub),
                    "amount": _fmt_amount(sub),
                    "current_period_end": _period_end(sub),
                    "cancel_at_period_end": sub.get("cancel_at_period_end"),
                    "customer_id": sub.get("customer", {}).get("id")
                    if isinstance(sub.get("customer"), dict)
                    else sub.get("customer"),
                    "subscription_id": sub.get("id"),
                    **_ids(sub),
                }
            )
    except stripe.error.AuthenticationError:
        raise HTTPException(status_code=401, detail="Stripe auth failed — check your key.")
    except stripe.error.StripeError as e:
        raise HTTPException(status_code=502, detail=f"Stripe error: {e.user_message or str(e)}")

    # Unique emails that currently have any subscription in the requested set.
    unique_emails = sorted({r["email"] for r in rows if r["email"] not in ("(no email)", "(unknown)")})

    return JSONResponse(
        {
            "count": len(rows),
            "unique_email_count": len(unique_emails),
            "unique_emails": unique_emails,
            "subscriptions": rows,
        }
    )


# --- Write actions -------------------------------------------------------
# These mutate the Stripe account. The UI confirms before calling them; the
# secret key still stays server-side.


def _stripe_call(fn):
    """Run a Stripe mutation, mapping Stripe errors to clean HTTP errors."""
    try:
        return fn()
    except stripe.error.AuthenticationError:
        raise HTTPException(status_code=401, detail="Stripe auth failed — check your key.")
    except stripe.error.InvalidRequestError as e:
        raise HTTPException(status_code=400, detail=f"Stripe rejected: {e.user_message or str(e)}")
    except stripe.error.StripeError as e:
        raise HTTPException(status_code=502, detail=f"Stripe error: {e.user_message or str(e)}")


# Stripe's prebuilt test PaymentMethod for the 4242 4242 4242 4242 Visa. Only
# valid in test mode; charges succeed immediately. We use this instead of the
# raw card number because Stripe blocks raw PANs over the API.
TEST_CARD_PAYMENT_METHOD = "pm_card_visa"


class CustomerBody(BaseModel):
    email: str
    name: Optional[str] = None
    # When set, also create a subscription on this price for the new customer.
    price_id: Optional[str] = None


class CancelBody(BaseModel):
    at_period_end: bool = True


class PriceBody(BaseModel):
    price_id: str


@app.get("/api/prices")
def list_prices():
    """Active prices the UI can offer as plans when creating a subscription."""
    out = []
    try:
        iterator = stripe.Price.list(
            active=True, limit=100, expand=["data.product"]
        ).auto_paging_iter()
        for price in iterator:
            product = price.get("product")
            # Skip prices whose product is archived/deleted.
            if isinstance(product, dict) and product.get("active") is False:
                continue
            product_name = _product_name(product)
            amount = price.get("unit_amount")
            currency = (price.get("currency") or "").upper()
            recurring = price.get("recurring") or {}
            interval = recurring.get("interval")
            label_price = "—" if amount is None else f"{amount / 100:.2f} {currency}"
            suffix = f"/{interval}" if interval else ""
            out.append(
                {
                    "price_id": price.get("id"),
                    "product_name": product_name or "(no product)",
                    "nickname": price.get("nickname"),
                    "amount": amount,
                    "currency": currency,
                    "interval": interval,
                    "recurring": bool(recurring),
                    "label": f"{product_name or price.get('id')} — {label_price}{suffix}",
                }
            )
    except stripe.error.AuthenticationError:
        raise HTTPException(status_code=401, detail="Stripe auth failed — check your key.")
    except stripe.error.StripeError as e:
        raise HTTPException(status_code=502, detail=f"Stripe error: {e.user_message or str(e)}")
    # Recurring prices first (subscribable), then one-off; alphabetical within.
    out.sort(key=lambda p: (not p["recurring"], p["label"].lower()))
    return {"count": len(out), "prices": out}


@app.post("/api/customers")
def create_customer(body: CustomerBody):
    """Create a new Stripe customer from an email (optional name). If price_id is
    given, attach the test Visa card and start a subscription that charges
    automatically, so it goes active immediately (test mode only)."""
    email = body.email.strip()
    if "@" not in email:
        raise HTTPException(status_code=400, detail="Please enter a valid email.")
    name = (body.name or "").strip() or None
    customer = _stripe_call(lambda: stripe.Customer.create(email=email, name=name))

    subscription = None
    price_id = (body.price_id or "").strip() or None
    if price_id:
        # Attach the prebuilt test Visa and make it the customer's default, so
        # the subscription can charge it automatically on creation.
        pm = _stripe_call(
            lambda: stripe.PaymentMethod.attach(
                TEST_CARD_PAYMENT_METHOD, customer=customer["id"]
            )
        )
        _stripe_call(
            lambda: stripe.Customer.modify(
                customer["id"],
                invoice_settings={"default_payment_method": pm["id"]},
            )
        )
        subscription = _stripe_call(
            lambda: stripe.Subscription.create(
                customer=customer["id"],
                items=[{"price": price_id}],
                collection_method="charge_automatically",
                default_payment_method=pm["id"],
            )
        )

    return {
        "ok": True,
        "customer_id": customer.get("id"),
        "email": customer.get("email"),
        "name": customer.get("name"),
        "subscription_id": subscription.get("id") if subscription else None,
        "subscription_status": subscription.get("status") if subscription else None,
    }


@app.post("/api/subscriptions/{sub_id}/cancel")
def cancel_subscription(sub_id: str, body: CancelBody):
    """Cancel at period end (reversible via /resume) or immediately."""
    if body.at_period_end:
        sub = _stripe_call(lambda: stripe.Subscription.modify(sub_id, cancel_at_period_end=True))
    else:
        sub = _stripe_call(lambda: stripe.Subscription.cancel(sub_id))
    return {
        "ok": True,
        "subscription_id": sub_id,
        "status": sub.get("status"),
        "cancel_at_period_end": sub.get("cancel_at_period_end"),
    }


@app.post("/api/subscriptions/{sub_id}/resume")
def resume_subscription(sub_id: str):
    """Undo a scheduled cancel (only works while cancel_at_period_end is set;
    a fully-canceled subscription cannot be resumed)."""
    sub = _stripe_call(lambda: stripe.Subscription.modify(sub_id, cancel_at_period_end=False))
    return {
        "ok": True,
        "subscription_id": sub_id,
        "status": sub.get("status"),
        "cancel_at_period_end": sub.get("cancel_at_period_end"),
    }


@app.post("/api/subscriptions/{sub_id}/price")
def change_price(sub_id: str, body: PriceBody):
    """Swap the subscription's plan to a different price, with prorations."""
    sub = _stripe_call(lambda: stripe.Subscription.retrieve(sub_id))
    item = _first_item(sub)
    if not item or not item.get("id"):
        raise HTTPException(status_code=400, detail="Subscription has no line item to update.")
    updated = _stripe_call(
        lambda: stripe.Subscription.modify(
            sub_id,
            items=[{"id": item["id"], "price": body.price_id}],
            proration_behavior="create_prorations",
        )
    )
    return {"ok": True, "subscription_id": sub_id, "status": updated.get("status"), **_ids(updated)}


@app.post("/api/subscriptions/{sub_id}/refund")
def refund_subscription(sub_id: str):
    """Refund the subscription's most recent payment (latest invoice)."""
    sub = _stripe_call(
        lambda: stripe.Subscription.retrieve(sub_id, expand=["latest_invoice.payment_intent"])
    )
    invoice = sub.get("latest_invoice")
    if not isinstance(invoice, dict):
        raise HTTPException(status_code=400, detail="No invoice found to refund.")
    pi = invoice.get("payment_intent")
    pi_id = pi.get("id") if isinstance(pi, dict) else pi
    if not pi_id:
        raise HTTPException(status_code=400, detail="Latest invoice has no payment to refund.")
    refund = _stripe_call(lambda: stripe.Refund.create(payment_intent=pi_id))
    return {
        "ok": True,
        "subscription_id": sub_id,
        "refund_id": refund.get("id"),
        "amount": (refund.get("amount") or 0) / 100,
        "currency": (refund.get("currency") or "").upper(),
        "status": refund.get("status"),
    }
