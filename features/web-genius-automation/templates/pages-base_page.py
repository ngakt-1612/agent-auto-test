"""Base page object — locator theo data-testid THAT (dom_report 21/09/2026).

Khong con doan selector. Moi testid duoi day da xac nhan ton tai trong DOM.
"""

import re

from config import ACTION_TIMEOUT, BASE_URL, NAV_TIMEOUT, ROUTES

QUOTA_MODAL_TEXT = "You've reached your usage limit"
SIGNIN_MODAL_TEXT = "Sign in to keep going"


class BasePage:
    def __init__(self, page):
        self.page = page
        page.set_default_timeout(ACTION_TIMEOUT)
        page.set_default_navigation_timeout(NAV_TIMEOUT)

    # ------------------------------------------------------------- Navigation
    def goto(self, route_key, wait_until="domcontentloaded"):
        self.page.goto(f"{BASE_URL}{ROUTES[route_key]}", wait_until=wait_until)
        return self

    def current_path(self):
        return self.page.url.replace(BASE_URL, "").split("?")[0]

    # ------------------------------------------------------------- Locators
    def testid(self, name):
        return self.page.locator(f"[data-testid='{name}']")

    def testid_or(self, name, fallback_locator):
        loc = self.testid(name)
        if loc.count() > 0:
            return loc.first
        return fallback_locator

    # ------------------------------------------------------------- Shell
    def app_shell(self):
        return self.testid("app-shell")

    def header(self):
        """App khong dung the <header>; header nam trong app-shell."""
        return self.testid("app-shell")

    # ------------------------------------------------------------- Header
    def credit_chip(self):
        """<a data-testid="credit-chip" title="Credits remaining">2</a>"""
        return self.testid("credit-chip")

    def _read_credit_once(self):
        loc = self.credit_chip()
        if loc.count() == 0:
            return None
        try:
            text = loc.first.inner_text(timeout=5000)
        except Exception:
            return None
        match = re.search(r"\b(\d{1,5})\b", text)
        return int(match.group(1)) if match else None

    def read_credit(self, stable_ms=1200, timeout=12000):
        """Doc so credit, cho toi khi gia tri ON DINH.

        Credit-chip render '0' truoc roi moi cap nhat gia tri that. Neu doc
        ngay se lay nham 0 -> test bao 'credit bi tru' hoac 'bi cong them'.
        """
        waited = 0
        previous = self._read_credit_once()
        while waited < timeout:
            self.page.wait_for_timeout(stable_ms)
            waited += stable_ms
            current = self._read_credit_once()
            if current is not None and current == previous:
                return current
            previous = current
        return previous

    def credit_is_low(self):
        loc = self.credit_chip()
        if loc.count() == 0:
            return None
        return loc.first.get_attribute("data-low") == "true"

    def upgrade_button(self):
        """Da dang nhap: <button data-testid="upgrade-btn">Upgrade</button>.
        Chua dang nhap: <a data-testid="header-activate">Activate</a>."""
        for name in ("upgrade-btn", "header-activate"):
            loc = self.testid(name)
            if loc.count() > 0:
                return loc.first
        return self.page.get_by_text(
            re.compile(r"^(Upgrade|Activate)$", re.I)
        ).first

    upgrade_link = upgrade_button  # giu ten cu

    def feedback_button(self):
        return self.page.get_by_role("button", name=re.compile("Feedback", re.I))

    def sign_in_button(self):
        return self.testid("header-signin")

    def avatar(self):
        """Avatar user o goc phai header. Khong co testid rieng.

        Nhan dien qua anh dai dien hoac nut chu cai dung ngay sau upgrade-btn.
        """
        by_img = self.page.locator("header img[src*='googleusercontent']")
        if by_img.count() > 0:
            return by_img.first
        return self.page.locator(
            "[data-testid='upgrade-btn'] ~ button, "
            "[data-testid='header-activate'] ~ button"
        ).last

    def is_logged_in(self):
        """Dang nhap = co credit-chip va KHONG co nut Sign in."""
        return self.credit_chip().count() > 0 and self.sign_in_button().count() == 0

    # ------------------------------------------------------------- Sidebar
    def sidebar(self):
        """<aside data-testid="sidebar" role="navigation">"""
        return self.testid("sidebar")

    def sidebar_toggle(self):
        return self.testid("sidebar-collapse")

    def sidebar_item(self, name):
        return self.sidebar().get_by_text(name, exact=True)

    def sidebar_link(self, route_key):
        return self.sidebar().locator(f"a[href='{ROUTES[route_key]}']")

    def sidebar_buttons(self):
        return self.sidebar().locator("button")

    def theme_toggle(self):
        """Khong co testid; la nut cuoi cung o chan sidebar."""
        return self.sidebar_buttons().last

    # ------------------------------------------------------------- Modals
    def quota_modal(self):
        return self.page.get_by_text(QUOTA_MODAL_TEXT, exact=False)

    def quota_modal_visible(self, timeout=3000):
        try:
            return self.quota_modal().first.is_visible(timeout=timeout)
        except Exception:
            return False

    def dismiss_quota_modal(self):
        if self.quota_modal_visible():
            btn = self.page.get_by_role("button", name=re.compile("Not now", re.I))
            if btn.count() > 0:
                btn.first.click()

    def signin_modal_visible(self, timeout=3000):
        try:
            return self.page.get_by_text(
                SIGNIN_MODAL_TEXT, exact=False
            ).first.is_visible(timeout=timeout)
        except Exception:
            return False

    # ------------------------------------------------------------- Misc
    def has_text(self, text, timeout=5000):
        try:
            self.page.get_by_text(text, exact=False).first.wait_for(timeout=timeout)
            return True
        except Exception:
            return False

    def horizontal_overflow(self):
        return self.page.evaluate(
            "() => document.documentElement.scrollWidth >"
            " document.documentElement.clientWidth"
        )

    def html_theme(self):
        return self.page.evaluate(
            "() => document.documentElement.getAttribute('data-theme')"
            " || document.documentElement.className"
        )
