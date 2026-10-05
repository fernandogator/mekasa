"""
Standard produce PLU list identifies printed PLUs the shared catalog does not know.

Satisfies: REQ-RCP-022 (Standard Produce PLU List) AC1–AC7
Spec version: 1.0
"""

import json
import os
from pathlib import Path
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

os.environ["ALLOW_TEST_AUTH"] = "true"
os.environ["ENVIRONMENT"] = "test"
os.environ["HOUSEHOLD_PERSISTENCE"] = "memory"

DATA = Path(__file__).resolve().parents[2] / "backend" / "app" / "data"


# --- list rules ---------------------------------------------------------------


@pytest.mark.parametrize(
    ("code", "name"),
    [
        ("4011", "Bananas"),
        ("94011", "Organic Bananas"),
        ("4048", "Regular Limes"),
        ("3283", "Honeycrisp Apples"),
        (" 4131 ", "Large Fuji Apples"),
    ],
)
def test_produce_name(code: str, name: str) -> None:
    from app.produce_plu import produce_name

    assert produce_name(code) == name


@pytest.mark.parametrize("code", ["84011", "14011", "2000", "5000", "401", "940111", "", None, "abcd"])
def test_non_standard_codes_are_not_produce(code: str | None) -> None:
    from app.produce_plu import produce_name

    assert produce_name(code) is None


def test_retailer_assigned_codes_are_excluded() -> None:
    from app.produce_plu import produce_name

    raw = json.loads((DATA / "plu_codes.json").read_text())
    retailer = [code for code, name in raw.items() if name.startswith("Retailer Assigned")]
    assert retailer
    assert all(produce_name(code) is None and produce_name(f"9{code}") is None for code in retailer)


def test_names_fit_the_catalog_limit() -> None:
    from app.produce_plu import _codes

    names = _codes().values()
    assert len(names) > 1000
    assert all(0 < len(name) <= 120 and "(" not in name and "  " not in name for name in names)
    assert not [name for name in names if name[-1] in " -,/"]


def test_license_is_bundled() -> None:
    assert "MIT License" in (DATA / "plu_codes.LICENSE.txt").read_text()


@pytest.mark.parametrize(
    ("produce", "texts", "expected"),
    [
        ("Organic Bananas", ("ORG BANANAS",), True),
        ("Large Fuji Apples", ("FUJI APPLE",), True),
        ("Small Regular - Red Tomatoes", ("TOMATO RED",), True),
        ("Bananas", ("PAPER TOWELS", "Paper Towels"), False),
        ("Organic Bananas", ("ORGANIC MILK",), False),
    ],
)
def test_looks_like(produce: str, texts: tuple[str, ...], expected: bool) -> None:
    from app.produce_plu import looks_like

    assert looks_like(produce, *texts) is expected


# --- receipt scan ---------------------------------------------------------------


def _reset() -> None:
    from app.catalog_repository import reset_catalog_repository
    from app.config import get_settings
    from app.inventory_repository import reset_inventory_repository
    from app.repository import reset_household_repository

    get_settings.cache_clear()
    reset_household_repository()
    reset_inventory_repository()
    reset_catalog_repository()


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ALLOW_TEST_AUTH", "true")
    monkeypatch.setenv("HOUSEHOLD_PERSISTENCE", "memory")
    monkeypatch.setenv("RECEIPT_LLM_ENABLED", "true")
    monkeypatch.setenv("GCP_PROJECT_ID", "test-project")
    for name in ("DATABASE_URL", "PRODUCT_PHOTO_BUCKET", "ITEM_PHOTO_BUCKET"):
        monkeypatch.delenv(name, raising=False)
    _reset()
    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client
    _reset()


def _auth(uid: str = "owner-1") -> dict[str, str]:
    return {"Authorization": f"Bearer test:{uid}"}


def _household(client: TestClient) -> str:
    created = client.post("/v1/households", json={"name": "Casa"}, headers=_auth())
    assert created.status_code == 201
    return created.json()["id"]


def _extraction(*lines: tuple[str, str, str | None, str]):
    from app.receipt_llm import _Extraction, _ExtractedItem

    return _Extraction(
        store_name="H-E-B",
        items=[
            _ExtractedItem(name=name, receipt_text=text, receipt_code=code, category=category, price_paid=1.29)
            for name, text, code, category in lines
        ],
    )


def _scan(client: TestClient, hid: str, extraction, off: AsyncMock):
    with patch("app.receipt_llm._generate", new=AsyncMock(return_value=extraction)), patch(
        "app.receipt_ocr.search_products", new=off
    ):
        scanned = client.post(f"/v1/households/{hid}/receipts/scan", json={"raw_text": "x"}, headers=_auth())
    assert scanned.status_code == 200, scanned.text
    return scanned.json()


def _no_off() -> AsyncMock:
    from app.models import ProductSearchResponse

    return AsyncMock(return_value=ProductSearchResponse(query="x", results=[]))


def test_printed_organic_plu_is_identified_without_off(client: TestClient) -> None:
    from app.category_icons import category_placeholder_url

    hid = _household(client)
    off = _no_off()
    body = _scan(client, hid, _extraction(("Organic Bananas", "ORG BANANAS", "94011", "Produce")), off)
    [line] = body["items"]
    assert line["identified"] is True
    assert line["name"] == "Organic Bananas"
    assert line["category"] == "Produce"
    assert line["match_method"] == "plu_standard"
    assert line["matched_product_id"] is None
    assert line["barcode"] is None
    assert line["image_url"] == category_placeholder_url("Produce")
    assert line["price_paid"] == 1.29
    off.assert_not_awaited()


def test_shared_word_identifies_when_category_is_wrong(client: TestClient) -> None:
    hid = _household(client)
    body = _scan(client, hid, _extraction(("Fuji Apple", "FUJI APPLE", "4131", "Other")), _no_off())
    assert body["items"][0]["match_method"] == "plu_standard"
    assert body["items"][0]["category"] == "Produce"


def test_item_number_on_non_produce_line_is_not_produce(client: TestClient) -> None:
    hid = _household(client)
    body = _scan(client, hid, _extraction(("Paper Towels", "PAPER TWL", "4011", "Household")), _no_off())
    assert body["items"][0]["identified"] is False
    assert body["items"][0]["match_method"] is None


def test_catalog_product_wins_over_list(client: TestClient) -> None:
    hid = _household(client)
    item = client.post(
        f"/v1/households/{hid}/inventory", json={"name": "Chiquita Bananas", "category": "Produce"}, headers=_auth()
    ).json()
    captured = client.post(f"/v1/households/{hid}/inventory/{item['id']}/capture", json={"plu_code": "4011"}, headers=_auth())
    assert captured.status_code == 200, captured.text

    body = _scan(client, hid, _extraction(("Bananas", "BANANAS", "4011", "Produce")), _no_off())
    assert body["items"][0]["match_method"] == "plu"
    assert body["items"][0]["matched_product_id"] == "plu:4011"


def test_list_applies_when_catalog_is_down(client: TestClient) -> None:
    hid = _household(client)
    with patch("app.receipt_ocr.match_catalog", side_effect=RuntimeError("db down")):
        body = _scan(client, hid, _extraction(("Bananas", "BANANAS", "4011", "Produce")), _no_off())
    assert body["items"][0]["match_method"] == "plu_standard"


def test_prompt_asks_for_plu() -> None:
    from app.receipt_llm import _PROMPT

    assert "produce PLU" in _PROMPT
