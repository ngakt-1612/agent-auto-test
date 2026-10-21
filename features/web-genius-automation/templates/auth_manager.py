"""Quan ly phien dang nhap Genius.

Thay doi so voi ban cu:
- Chap nhan ca HTTP 200 va 201 tu API refresh (ban cu chi chap nhan 201).
- Doc URL/duong dan tu config.py thay vi hardcode.
- Them force_expire_access_token() phuc vu TC #4 va TC #5 (khong phai cho 15 phut).
"""

import base64
import json
import time

from config import AUTH_FILE, BASE_URL, REFRESH_URL

TOKEN_KEY = "genius.tokens"
ACCEPTED_REFRESH_STATUS = (200, 201)


def decode_jwt(token):
    """Decode phan payload cua JWT, khong verify chu ky."""
    try:
        payload = token.split(".")[1]
    except IndexError:
        raise AssertionError("JWT khong dung dinh dang")
    payload += "=" * (-len(payload) % 4)
    return json.loads(base64.urlsafe_b64decode(payload))


def saved_session_error():
    """Tra ve mo ta loi neu auth.json khong dung duoc, None neu hop le."""
    if not AUTH_FILE.exists():
        return "Khong tim thay auth.json. Chay setup_login.py truoc."

    try:
        saved_state = json.loads(AUTH_FILE.read_text(encoding="utf-8"))
        genius_origin = next(
            origin
            for origin in saved_state.get("origins", [])
            if origin.get("origin") == BASE_URL
        )
        token_entry = next(
            item
            for item in genius_origin.get("localStorage", [])
            if item.get("name") == TOKEN_KEY
        )
        tokens = json.loads(token_entry["value"])
    except (KeyError, StopIteration, TypeError, ValueError):
        return "auth.json khong hop le. Chay lai setup_login.py."

    access_token = tokens.get("accessToken")
    refresh_token = tokens.get("refreshToken")

    if not refresh_token:
        return "Thieu refreshToken. Chay lai setup_login.py."

    # Access token het han van OK vi con refresh token; chi fail khi CA HAI het han.
    try:
        refresh_exp = decode_jwt(refresh_token).get("exp", 0)
    except Exception:
        return "refreshToken khong doc duoc. Chay lai setup_login.py."

    if refresh_exp <= int(time.time()):
        return "Refresh token da het han. Chay setup_login.py de dang nhap lai."

    if not access_token:
        return "Thieu accessToken. Chay lai setup_login.py."

    return None


def get_tokens(page):
    raw = page.evaluate(f"() => localStorage.getItem('{TOKEN_KEY}')")
    if not raw:
        raise AssertionError(f"Khong tim thay {TOKEN_KEY} trong localStorage")
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        raise AssertionError(f"{TOKEN_KEY} khong phai JSON hop le")


def set_tokens(page, tokens):
    page.evaluate(
        f"(t) => localStorage.setItem('{TOKEN_KEY}', JSON.stringify(t))",
        tokens,
    )


def persist_tokens_to_file(tokens):
    """Ghi token moi nguoc vao auth.json.

    Backend xoay vong refresh token (moi token chi dung duoc 1 lan). Neu khong
    ghi lai, auth.json giu token cu da chet -> lan chay sau bao HTTP 401.
    """
    if not AUTH_FILE.exists():
        return False
    try:
        state = json.loads(AUTH_FILE.read_text(encoding="utf-8"))
    except (ValueError, OSError):
        return False

    for origin in state.get("origins", []):
        if origin.get("origin") != BASE_URL:
            continue
        for item in origin.get("localStorage", []):
            if item.get("name") == TOKEN_KEY:
                item["value"] = json.dumps(tokens, separators=(",", ":"))
                AUTH_FILE.write_text(
                    json.dumps(state, ensure_ascii=False), encoding="utf-8"
                )
                print(f"[AUTH] Da cap nhat token moi vao {AUTH_FILE.name}")
                return True
    return False


def access_token_remaining(page):
    """So giay con lai cua access token."""
    tokens = get_tokens(page)
    access_token = tokens.get("accessToken")
    if not access_token:
        raise AssertionError("Khong tim thay accessToken")
    exp = decode_jwt(access_token).get("exp")
    if not exp:
        raise AssertionError("accessToken khong co truong exp")
    return exp - int(time.time())


def is_access_token_expiring(page, buffer_seconds=120):
    remaining = access_token_remaining(page)
    print(f"[AUTH] Access token con {remaining}s")
    return remaining <= buffer_seconds


def force_expire_access_token(page):
    """Ghi de accessToken bang token da het han.

    Dung cho TC #4 (session het han khi dang thao tac) va TC #5
    (auto refresh) — khong phai ngoi cho 15 phut.
    """
    tokens = get_tokens(page)
    access_token = tokens["accessToken"]
    header, payload_b64, signature = access_token.split(".")
    payload = decode_jwt(access_token)
    payload["exp"] = int(time.time()) - 60
    new_payload = (
        base64.urlsafe_b64encode(
            json.dumps(payload, separators=(",", ":")).encode()
        )
        .decode()
        .rstrip("=")
    )
    tokens["accessToken"] = f"{header}.{new_payload}.{signature}"
    set_tokens(page, tokens)
    return tokens["accessToken"]


def refresh_access_token(page):
    tokens = get_tokens(page)
    refresh_token = tokens.get("refreshToken")
    if not refresh_token:
        raise AssertionError("Khong tim thay refreshToken")

    print("[AUTH] Goi API refresh token...")
    result = page.evaluate(
        """
        async ({ refreshUrl, refreshToken }) => {
            const response = await fetch(refreshUrl, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                credentials: "include",
                body: JSON.stringify({ refreshToken })
            });
            let body = null;
            try { body = await response.json(); } catch (e) { body = null; }
            return { status: response.status, body };
        }
        """,
        {"refreshUrl": REFRESH_URL, "refreshToken": refresh_token},
    )

    status = result["status"]
    print(f"[AUTH] Refresh API status: {status}")

    if status not in ACCEPTED_REFRESH_STATUS:
        hint = (
            "Refresh token trong auth.json da bi vo hieu hoa. Backend xoay "
            "vong token, moi token chi dung duoc 1 lan; phien nay da bi mot "
            "tien trinh khac doi mat."
            if status == 401
            else ""
        )
        raise AssertionError(
            f"Refresh that bai. HTTP {status}. {hint}\n"
            "Cach xu ly: python setup_login.py --login-only"
        )

    data = (result.get("body") or {}).get("data")
    if not data:
        raise AssertionError("Response refresh khong co truong data")

    new_access = data.get("accessToken")
    new_refresh = data.get("refreshToken")
    if not new_access or not new_refresh:
        raise AssertionError("Response refresh thieu accessToken hoac refreshToken")

    tokens["accessToken"] = new_access
    tokens["refreshToken"] = new_refresh
    set_tokens(page, tokens)
    persist_tokens_to_file(tokens)
    print("[AUTH] Refresh thanh cong.")
    return status


def ensure_valid_session(page, buffer_seconds=120):
    """Bao dam token con han truoc moi test.

    buffer 120s (ban cu la 60s): suite chay 25-40 phut, token song 15 phut,
    buffer qua nho se de token het han giua chung test.
    """
    if not is_access_token_expiring(page, buffer_seconds):
        return
    refresh_access_token(page)
    if is_access_token_expiring(page, buffer_seconds):
        raise AssertionError("Access token van het han sau khi refresh")
