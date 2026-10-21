"""Log every outgoing Stripe HTTP request as an equivalent curl command.

Only the secret key (the token in the ``Authorization: Bearer sk_...`` header) is
masked — method, URL, all other headers, and the body are printed verbatim so the
line can be copy/pasted to reproduce the call. Response status/body is logged too.

Usage (once, after ``stripe.api_key`` is set)::

    import stripe_curl_logger
    stripe_curl_logger.install()
"""
import logging
import shlex

import stripe

logger = logging.getLogger("stripe.curl")

# How much of the response body to print (bytes). Responses can be large.
_MAX_RESPONSE_CHARS = 2000


def _mask_auth(value: str) -> str:
    """'Bearer sk_test_51Abc...xyz' -> 'Bearer sk_test_***MASKED***'.

    Keeps the key-type prefix (sk_test_ / sk_live_ / rk_...) so you can tell
    which mode/key was used, but hides the secret part.
    """
    parts = value.split(" ", 1)
    if len(parts) == 2 and parts[1]:
        token = parts[1]
        # Keep only up to and including the second underscore (e.g. "sk_test_").
        bits = token.split("_")
        prefix = "_".join(bits[:2]) + "_" if len(bits) >= 2 else token[:4]
        return f"{parts[0]} {prefix}***MASKED***"
    return "***MASKED***"


def _decode(data) -> str:
    if isinstance(data, bytes):
        try:
            return data.decode("utf-8", "replace")
        except Exception:
            return repr(data)
    return str(data)


def _to_curl(method: str, url: str, headers, post_data) -> str:
    lines = [f"curl -X {method.upper()} {shlex.quote(url)}"]
    for key, value in (headers or {}).items():
        if key.lower() == "authorization":
            value = _mask_auth(str(value))
        lines.append(f"  -H {shlex.quote(f'{key}: {value}')}")
    if post_data:
        lines.append(f"  --data {shlex.quote(_decode(post_data))}")
    return " \\\n".join(lines)


def install() -> None:
    """Wrap the Stripe HTTP client so every request is logged as curl."""
    client = stripe.default_http_client
    if client is None:
        # Force a concrete client now so we can wrap it before the first call.
        client = stripe.RequestsClient()
        stripe.default_http_client = client

    if getattr(client, "_curl_logging_installed", False):
        return

    original = client.request_with_retries

    def wrapped(method, url, headers, post_data=None, *args, **kwargs):
        try:
            logger.info("→ Stripe request:\n%s", _to_curl(method, url, headers, post_data))
        except Exception:  # logging must never break the actual request
            logger.debug("failed to render curl log", exc_info=True)

        content, status_code, resp_headers = original(
            method, url, headers, post_data, *args, **kwargs
        )

        try:
            body = _decode(content)
            if len(body) > _MAX_RESPONSE_CHARS:
                body = body[:_MAX_RESPONSE_CHARS] + f"… ({len(body)} chars total)"
            logger.info("← Stripe response %s %s:\n%s", status_code, url, body)
        except Exception:
            logger.debug("failed to render response log", exc_info=True)

        return content, status_code, resp_headers

    client.request_with_retries = wrapped
    client._curl_logging_installed = True
    logger.info("Stripe curl logging installed (secret key masked).")
