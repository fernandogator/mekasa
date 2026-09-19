"""Tests for receipt OCR + product catalog enrichment (REQ-005)."""

import os
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

os.environ["ALLOW_TEST_AUTH"] = "true"
os.environ["ENVIRONMENT"] = "test"
os.environ["HOUSEHOLD_PERSISTENCE"] = "memory"


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


def _household(client: TestClient) -> str:
    created = client.post(
        "/v1/households",
        json={"name": "Casa Receipt"},
        headers=_auth(),
    )
    assert created.status_code == 201
    return created.json()["id"]


def test_receipt_scan_enriches_matched_and_flags_unidentified(client: TestClient) -> None:
    """
    Satisfies: REQ-005 AC1–AC2
    Spec version: 1.0
    """
    from app.models import ProductSearchHit, ProductSearchResponse

    household_id = _household(client)

    async def fake_search(query: str, *, limit: int = 8, client=None):
        if "milk" in query.casefold():
            return ProductSearchResponse(
                query=query,
                results=[
                    ProductSearchHit(
                        barcode="041220576037",
                        name="Whole Milk",
                        brand="Generic",
                        category="Dairy",
                        image_url="https://images.openfoodfacts.org/milk.jpg",
                        source="openfoodfacts",
                    )
                ],
            )
        # Obscure OCR name → no useful hit
        return ProductSearchResponse(query=query, results=[])

    with patch("app.receipt_ocr.search_products", new=AsyncMock(side_effect=fake_search)):
        scanned = client.post(
            f"/v1/households/{household_id}/receipts/scan",
            json={
                "raw_text": (
                    "WHOLE MILK 3.49\n"
                    "ZZZ UNKNOWN SKU 9.99\n"
                    "SUBTOTAL 13.48\n"
                    "TOTAL 13.48\n"
                )
            },
            headers=_auth(),
        )

    assert scanned.status_code == 200
    body = scanned.json()
    assert body["engine"] == "text"
    assert len(body["items"]) == 2

    milk = body["items"][0]
    assert milk["identified"] is True
    assert milk["barcode"] == "041220576037"
    assert milk["image_url"] == "https://images.openfoodfacts.org/milk.jpg"
    assert milk["category"] == "Dairy"
    assert milk["price_paid"] == 3.49

    unknown = body["items"][1]
    assert unknown["identified"] is False
    assert unknown["barcode"] is None
    assert unknown["image_url"]  # placeholder still present
    assert "placehold.co" in unknown["image_url"]
    assert unknown["price_paid"] == 9.99


def test_receipt_scan_every_item_has_image_url(client: TestClient) -> None:
    from app.models import ProductSearchResponse

    household_id = _household(client)
    with patch(
        "app.receipt_ocr.search_products",
        new=AsyncMock(return_value=ProductSearchResponse(query="x", results=[])),
    ):
        scanned = client.post(
            f"/v1/households/{household_id}/receipts/scan",
            json={"raw_text": "BANANAS 1.29\nSOURDOUGH LOAF 4.99\nTOTAL 6.28\n"},
            headers=_auth(),
        )
    assert scanned.status_code == 200
    for item in scanned.json()["items"]:
        assert item["image_url"]
        assert item["identified"] is False
