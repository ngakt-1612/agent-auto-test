"""Fixtures dung chung cho toan bo suite.

Diem quan trong:
- `credit_guard`  : SKIP thay vi FAIL khi khong du credit -> nightly run khong do oan.
- `image_chain`   : 1 lan generate anh duy nhat, dung chung cho TC 13/23/25/26/35.
- `pytest_runtest_makereport`: ghi ket qua theo so TC de do nguoc vao Excel.
"""

import json
import time
from datetime import datetime

import pytest
from playwright.sync_api import sync_playwright

import config as cfg
from auth_manager import (
    ensure_valid_session,
    get_tokens,
    is_access_token_expiring,
    refresh_access_token,
    saved_session_error,
    set_tokens,
)
from pages.base_page import BasePage
from pages.generator_page import GeneratorPage
from pages.home_page import GalleryPage, HomePage

_RESULTS = {}


# ------------------------------------------------------------------ Markers
def pytest_configure(config):
    for marker in [
        "tc(n): so thu tu testcase trong TC_Genius_Web_Automation.xlsx",
        "smoke: bo smoke nhanh, khong ton credit",
        "ui: kiem tra UI tinh, khong ton credit",
        "mock: dung page.route / set_offline, khong ton credit",
        "credit: TON CREDIT THAT - chi chay 1 lan/ngay",
        "e2e: luong xuyen suot",
        "manual: khong tu dong hoa duoc, chay tay",
    ]:
        config.addinivalue_line("markers", marker)

    cfg.REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    cfg.SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)


def pytest_sessionstart(session):
    """Kiem tra session dang nhap MOT LAN truoc khi mo Chromium.

    Tranh tinh trang 32 test cung bao loi auth giong nhau.
    """
    if session.config.getoption("--collect-only"):
        return
    error = saved_session_error()
    if error:
        pytest.exit(
            f"\n[AUTH] {error}\n[AUTH] Chay: python setup_login.py\n",
            returncode=4,
        )


# ------------------------------------------------------------------ Browser
@pytest.fixture(scope="session")
def playwright_instance():
    with sync_playwright() as p:
        yield p


@pytest.fixture(scope="session")
def browser(playwright_instance):
    browser = playwright_instance.chromium.launch(
        headless=cfg.HEADLESS,
        slow_mo=cfg.SLOW_MO,
    )
    yield browser
    browser.close()


def _new_context(browser, authenticated=True, viewport=None):
    kwargs = {"viewport": viewport or cfg.DEFAULT_VIEWPORT}
    if authenticated:
        kwargs["storage_state"] = str(cfg.AUTH_FILE)
    return browser.new_context(**kwargs)


@pytest.fixture
def context(browser):
    ctx = _new_context(browser)
    yield ctx
    ctx.close()


@pytest.fixture(scope="session")
def auth_tokens(browser):
    """Refresh token MOT LAN cho ca phien chay, roi chia se cho moi test.

    Backend xoay vong refresh token (moi token chi dung 1 lan). Neu de moi
    test tu goi refresh, test dau tien lam chet token cua cac test sau ->
    ca suite ERROR voi HTTP 401. Fixture nay bao dam chi refresh 1 lan.
    """
    ctx = _new_context(browser)
    pg = ctx.new_page()
    pg.goto(cfg.HOME_URL, wait_until="domcontentloaded")
    try:
        ensure_valid_session(pg)
        tokens = dict(get_tokens(pg))
    finally:
        ctx.close()
    return tokens


@pytest.fixture
def page(context, auth_tokens):
    """Trang da dang nhap, dung token chung cua phien chay."""
    pg = context.new_page()
    pg.goto(cfg.HOME_URL, wait_until="domcontentloaded")

    # Dong bo token cua phien vao context nay
    try:
        current = get_tokens(pg)
    except AssertionError:
        current = {}
    if current.get("accessToken") != auth_tokens.get("accessToken"):
        set_tokens(pg, auth_tokens)
        pg.reload(wait_until="domcontentloaded")

    # Chi refresh khi token sap het han giua chung suite dai
    if is_access_token_expiring(pg, buffer_seconds=90):
        refresh_access_token(pg)
        auth_tokens.update(get_tokens(pg))

    yield pg

    # App co the tu goi refresh trong luc test chay va xoay vong token.
    # Dong bo nguoc de test sau khong cam token da chet.
    try:
        latest = get_tokens(pg)
        if latest.get("refreshToken") != auth_tokens.get("refreshToken"):
            auth_tokens.update(latest)
            print("[AUTH] App da tu xoay vong token, da dong bo lai.")
    except Exception:
        pass


@pytest.fixture
def unauth_page(browser):
    """Trang chua dang nhap, phuc vu TC #3."""
    ctx = _new_context(browser, authenticated=False)
    pg = ctx.new_page()
    yield pg
    ctx.close()


@pytest.fixture
def base(page):
    return BasePage(page)


@pytest.fixture
def home(page):
    return HomePage(page)


@pytest.fixture
def gallery(page):
    return GalleryPage(page)


@pytest.fixture
def image_page(page):
    return GeneratorPage(page, "image").open()


@pytest.fixture
def video_page(page):
    return GeneratorPage(page, "video").open()


@pytest.fixture
def generator(page):
    """Factory: generator(tool_key) -> GeneratorPage da mo."""

    def _make(tool):
        return GeneratorPage(page, tool).open()

    return _make


# ------------------------------------------------------------------ Credit
@pytest.fixture
def credit_guard(base):
    """Skip test neu khong du credit hoac da dinh modal het quota.

    Het quota la van de MOI TRUONG, khong phai bug -> SKIP, khong FAIL.
    """

    def _require(cost_key="image"):
        cost = cfg.CREDIT_COST[cost_key]
        if base.quota_modal_visible(timeout=1500):
            pytest.skip("Da het quota ngay (modal usage limit dang hien)")
        balance = base.read_credit()
        if balance is None:
            pytest.skip(
                "Khong doc duoc so credit tren header "
                "(can data-testid='header-credit-counter')"
            )
        if balance < cost:
            pytest.skip(
                f"Khong du credit: con {balance}, can {cost} cho 1 {cost_key}"
            )
        return balance

    return _require


# ------------------------------------------------------------------ Shared generation
@pytest.fixture(scope="session")
def session_context(browser):
    ctx = _new_context(browser)
    yield ctx
    ctx.close()


@pytest.fixture(scope="session")
def image_chain(session_context, auth_tokens):
    """Generate DUNG 1 anh cho ca chuoi TC 13 / 23 / 25 / 26 / 35.

    Ngan sach 10 credit/ngay khong du de moi TC tu generate rieng.
    Tra ve dict trang thai; cac test chi doc, khong generate lai.
    """
    pg = session_context.new_page()
    pg.goto(cfg.HOME_URL, wait_until="domcontentloaded")
    set_tokens(pg, auth_tokens)
    pg.reload(wait_until="domcontentloaded")

    gen = GeneratorPage(pg, "image").open()
    state = {
        "page": pg,
        "generator": gen,
        "prompt": cfg.PROMPT_IMAGE,
        "skipped": None,
        "credit_before": None,
        "credit_after": None,
        "cards_before": 0,
        "cards_after": 0,
        "submit_disabled_during_run": None,
        "elapsed": None,
    }

    if gen.quota_modal_visible(timeout=1500):
        state["skipped"] = "Modal het quota hien ngay khi mo man Image"
        yield state
        return

    balance = gen.read_credit()
    state["credit_before"] = balance
    cost = cfg.CREDIT_COST["image"]
    if balance is None:
        state["skipped"] = "Khong doc duoc so credit tren header"
        yield state
        return
    if balance < cost:
        state["skipped"] = f"Khong du credit: con {balance}, can {cost}"
        yield state
        return

    state["cards_before"] = gen.creation_count()
    gen.fill_prompt(cfg.PROMPT_IMAGE)
    started = time.time()
    gen.submit()

    # Ngay sau khi bam: nut phai khoa lai, khong nhan click thu hai (TC #12.1)
    try:
        pg.wait_for_timeout(500)
        state["submit_disabled_during_run"] = not gen.submit_button().is_enabled()
    except Exception:
        state["submit_disabled_during_run"] = None

    outcome = gen.wait_until_generation_settled(cfg.IMAGE_GEN_TIMEOUT)
    state["elapsed"] = round(time.time() - started, 1)

    if outcome == "quota_blocked":
        state["skipped"] = "Generate bi chan boi quota (modal usage limit)"
        yield state
        return

    pg.wait_for_timeout(2000)
    state["cards_after"] = gen.creation_count()
    state["credit_after"] = gen.read_credit()

    yield state


# ------------------------------------------------------------------ Evidence + results
def _tc_number(item):
    marker = item.get_closest_marker("tc")
    if marker and marker.args:
        return marker.args[0]
    return None


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    outcome = yield
    report = outcome.get_result()
    if report.when != "call":
        return

    tc = _tc_number(item)
    if tc is None:
        return

    status = "PASS"
    if report.failed:
        status = "FAIL"
    elif report.skipped:
        status = "BLOCKED"

    _RESULTS[str(tc)] = {
        "tc": tc,
        "nodeid": item.nodeid,
        "status": status,
        "duration": round(report.duration, 2),
        "message": str(report.longrepr)[:1500] if report.failed else "",
        "timestamp": datetime.now().isoformat(timespec="seconds"),
    }


@pytest.fixture(autouse=True)
def evidence(request):
    """Chup screenshot lam bang chung cho moi TC co marker tc."""
    yield
    tc = _tc_number(request.node)
    if tc is None:
        return
    for name in ("page", "unauth_page"):
        if name not in request.fixturenames:
            continue
        try:
            pg = request.getfixturevalue(name)
            label = f"{tc:02d}" if isinstance(tc, int) else str(tc)
            pg.screenshot(
                path=str(cfg.SCREENSHOT_DIR / f"TC{label}.png"),
                full_page=False,
            )
        except Exception:
            pass
        break


def pytest_sessionfinish(session, exitstatus):
    if not _RESULTS:
        return
    cfg.REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    cfg.RESULTS_JSON.write_text(
        json.dumps(_RESULTS, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"\n[RESULTS] Da ghi {len(_RESULTS)} ket qua vao {cfg.RESULTS_JSON}")
