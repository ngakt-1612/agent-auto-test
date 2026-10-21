"""Ham tien ich dung chung cho cac test."""

import pytest


def skip_if_quota_blocked(page_obj, where=""):
    """Bien tinh huong het quota thanh SKIP thay vi FAIL.

    Het credit la van de moi truong, khong phai bug cua san pham.
    Neu de FAIL, nightly run se do moi ngay va team se ngung doc report.
    """
    if page_obj.quota_modal_visible(timeout=2000):
        pytest.skip(f"Het quota khi {where} - khong verify duoc ket qua that")


def skip_if_chain_unavailable(chain):
    """Skip cac TC phu thuoc vao lan generate dung chung."""
    if chain.get("skipped"):
        pytest.skip(f"Chuoi generate anh khong chay duoc: {chain['skipped']}")


def assert_all_visible(locators, label=""):
    missing = [name for name, loc in locators.items() if loc.count() == 0]
    assert not missing, f"{label} thieu element: {missing}"
