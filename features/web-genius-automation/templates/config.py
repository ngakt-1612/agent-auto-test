"""Cau hinh tap trung cho bo automation Genius Web.

Moi gia tri deu co the override bang bien moi truong, de chay duoc ca tren may
local lan tren CI ma khong phai sua code.
"""

import os
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent

# ---------------------------------------------------------------- Environment
BASE_URL = os.getenv("GENIUS_BASE_URL", "https://genius.style")
HOME_URL = f"{BASE_URL}/home"
API_BASE = os.getenv(
    "GENIUS_API_BASE",
    "https://api-ai-genius-iip055.aperogroup.ai",
)
REFRESH_URL = f"{API_BASE}/api/v2/auth/refresh"

# Endpoint that su dung khi bam Generate (xac nhan 22/09/2026 qua network log).
# Mot endpoint duy nhat cho ca 5 tool, khong phai /generate nhu du doan ban dau.
EXECUTE_PATH = "/api/v2/web/execute"
EXECUTE_URL = f"{API_BASE}{EXECUTE_PATH}"
EXECUTE_GLOB = f"**{EXECUTE_PATH}"

AUTH_FILE = Path(os.getenv("GENIUS_AUTH_FILE", PROJECT_ROOT / "auth.json"))
EXCEL_FILE = Path(
    os.getenv("GENIUS_EXCEL", PROJECT_ROOT / "TC_Genius_Web_Automation.xlsx")
)

REPORTS_DIR = PROJECT_ROOT / "reports"
SCREENSHOT_DIR = REPORTS_DIR / "screenshots"
RESULTS_JSON = REPORTS_DIR / "results.json"
FIXTURES_DIR = PROJECT_ROOT / "fixtures"

# ---------------------------------------------------------------- Browser
HEADLESS = os.getenv("HEADLESS", "1") not in ("0", "false", "False")
SLOW_MO = int(os.getenv("SLOW_MO", "0"))
DEFAULT_VIEWPORT = {"width": 1440, "height": 900}
VIEWPORTS = {
    "desktop": {"width": 1440, "height": 900},
    "laptop": {"width": 1024, "height": 768},
    "mobile": {"width": 430, "height": 932},
}

# ---------------------------------------------------------------- Timeouts (ms)
NAV_TIMEOUT = int(os.getenv("NAV_TIMEOUT", "30000"))
ACTION_TIMEOUT = int(os.getenv("ACTION_TIMEOUT", "15000"))
IMAGE_GEN_TIMEOUT = int(os.getenv("IMAGE_GEN_TIMEOUT", "180000"))
VIDEO_GEN_TIMEOUT = int(os.getenv("VIDEO_GEN_TIMEOUT", "300000"))

# ---------------------------------------------------------------- Credit
# [AMBIGUOUS #12] Chua co bang gia credit tu PO/BA.
# Cac gia tri duoi day la GIA DINH, lay tu precondition "credit >= 4" trong TC.
# Khi PO/BA xac nhan, chi can sua o day, khong phai sua test.
CREDIT_COST = {
    "image": int(os.getenv("CREDIT_COST_IMAGE", "4")),
    "video": int(os.getenv("CREDIT_COST_VIDEO", "4")),
}
DAILY_CREDIT_BUDGET = int(os.getenv("DAILY_CREDIT_BUDGET", "10"))
# Neu True, test [Logic] se assert so credit giam DUNG bang CREDIT_COST.
# Giu False cho toi khi PO/BA chot bang gia; khi do test chi assert "co giam".
ASSERT_EXACT_CREDIT_COST = os.getenv("ASSERT_EXACT_CREDIT", "0") == "1"

# ---------------------------------------------------------------- Test data
PROMPT_IMAGE = "A cute cat sitting on a meadow, digital art, high quality"
PROMPT_VIDEO = (
    "A cute cat running through a meadow, cinematic motion, high quality"
)
PROMPT_XSS = "<script>alert(1)</script>"
PROMPT_MAX_LENGTH = 1999

# ---------------------------------------------------------------- Routes
ROUTES = {
    "home": "/home",
    "image": "/agent/image",
    "video": "/agent/video",
    "speech": "/agent/speech",
    "music": "/agent/music",
    "chat": "/agent/chat",
    "gallery": "/gallery",
    "unknown": "/agent/unknown-tool",
}

# Cac dang URL khong ton tai, phuc vu TC 29.
# Phan biet: /agent/* co the fallback co chu dich, duong dan goc thi phai 404.
UNKNOWN_URLS = {
    "agent_unknown_tool": "/agent/unknown-tool",   # URL trong spec
    "agent_random": "/agent/abc123",
    "root_random": "/khong-ton-tai",
    "gallery_child": "/gallery/abc123",
}

# ---------------------------------------------------------------- Error copy
# [BLOCKER P1] Can PO/BA xac nhan noi dung hien thi chinh xac cua 4 ma loi nay.
ERROR_COPY = {
    "ERR_AUTH_001": "Your session has expired. Please sign in again.",
    "ERR_NET_001": (
        "No internet connection. Please check your network and try again."
    ),
    "ERR_NET_003": "Something went wrong on our end. Please try again later.",
    "ERR_VAL_003": "File format not supported.",
}


def url(route_key: str) -> str:
    """Tra ve URL tuyet doi tu khoa route."""
    return f"{BASE_URL}{ROUTES[route_key]}"


# ---------------------------------------------------------------- data-testid
# Cac testid DA CO SAN trong app (xac nhan qua DevTools 21/09/2026).
# Dung ten o day thay vi doan, khong can cho FE bo sung.
TESTIDS = {
    "credit_chip": "credit-chip",          # title="Credits remaining"
    "header_activate": "header-activate",
    "header_signin": "header-signin",
    "email_input": "email-input",
    "email_continue": "email-continue",
    "social_google": "social-google",
    "social_apple": "social-apple",
}
