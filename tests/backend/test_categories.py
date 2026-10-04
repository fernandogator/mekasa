"""
Fixed eight-category list and mapping of finer labels.

Satisfies: REQ-017 (Spending Categorization)
Acceptance criteria: AC4
Spec version: 1.0
"""

import os

import pytest
from fastapi.testclient import TestClient

os.environ["ALLOW_TEST_AUTH"] = "true"
os.environ["ENVIRONMENT"] = "test"
os.environ["HOUSEHOLD_PERSISTENCE"] = "memory"

from app.categories import CATEGORIES, normalize_category  # noqa: E402


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ALLOW_TEST_AUTH", "true")
    monkeypatch.setenv("HOUSEHOLD_PERSISTENCE", "memory")
    from app.config import get_settings
    from app.repository import reset_household_repository

    get_settings.cache_clear()
    reset_household_repository()

    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client

    get_settings.cache_clear()
    reset_household_repository()


def _auth(uid: str = "owner-1") -> dict[str, str]:
    return {"Authorization": f"Bearer test:{uid}"}


def test_list_is_the_eight_categories_in_order() -> None:
    assert CATEGORIES == ("Produce", "Dairy", "Pantry", "Meat", "Frozen", "Beverages", "Household", "Other")


@pytest.mark.parametrize(
    ("label", "expected"),
    [
        ("Produce", "Produce"),
        ("  dairy ", "Dairy"),
        ("BEVERAGES", "Beverages"),
        ("Bakery", "Pantry"),
        ("Snacks", "Pantry"),
        ("Seafood", "Meat"),
        ("Alcohol", "Beverages"),
        ("Personal Care", "Household"),
        ("personal   care", "Household"),
        ("Baby", "Household"),
        ("Pet", "Household"),
        ("Fruit", "Other"),
        ("Plant based foods", "Other"),
        ("", "Other"),
        (None, "Other"),
    ],
)
def test_finer_and_unknown_labels_map_onto_the_list(label, expected) -> None:
    assert normalize_category(label) == expected


def test_barcode_lookup_never_returns_a_raw_tag() -> None:
    from app.barcode_lookup import _map_category

    assert _map_category(["en:plant-based-foods-and-beverages-x"], None) in CATEGORIES
    assert _map_category(["en:dietary-supplements"], None) == "Other"


def test_inventory_create_and_patch_store_only_listed_categories(client: TestClient) -> None:
    hid = client.post("/v1/households", json={"name": "Casa"}, headers=_auth()).json()["id"]
    created = client.post(
        f"/v1/households/{hid}/inventory",
        json={"name": "Croissants", "category": "Bakery"},
        headers=_auth(),
    )
    assert created.status_code == 201
    assert created.json()["category"] == "Pantry"

    patched = client.patch(
        f"/v1/households/{hid}/inventory/{created.json()['id']}",
        json={"category": "Seafood"},
        headers=_auth(),
    )
    assert patched.status_code == 200
    assert patched.json()["category"] == "Meat"


def test_receipt_line_model_maps_category() -> None:
    from app.models import ReceiptLineItem

    line = ReceiptLineItem(name="Dog food", category="Pet", quantity=1, price_paid=9.99)
    assert line.category == "Household"


def test_catalog_capture_correct_and_receipt_save_map_category() -> None:
    from app.catalog_repository import InMemoryCatalogRepository, ReceiptLineSave, household_hash

    repo = InMemoryCatalogRepository()
    hh = household_hash("household-a", salt="test-salt")
    created = repo.capture(
        store_chain_id="heb", upc="041220576037", hh=hh, fallback_name="Chips", fallback_category="Snacks",
    )
    assert created.product.category == "Pantry"

    corrected = repo.correct(product_id="041220576037", hh=hh, changes={"category": "Alcohol"})
    assert corrected.product.category == "Beverages"

    [pid] = repo.save_receipt_lines("heb", [ReceiptLineSave(raw_text="SALMON", description="Salmon", category="Seafood")])
    assert repo.get_product(pid).category == "Meat"
