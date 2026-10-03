"""Tests for Gemini receipt extraction with OCR fallback (REQ-005)."""

import base64
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
    monkeypatch.setenv("RECEIPT_LLM_ENABLED", "true")
    monkeypatch.setenv("GCP_PROJECT_ID", "test-project")
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
    created = client.post("/v1/households", json={"name": "Casa Gemini"}, headers=_auth())
    assert created.status_code == 201
    return created.json()["id"]


def _no_catalog_hits():
    from app.models import ProductSearchResponse

    return patch(
        "app.receipt_ocr.search_products",
        new=AsyncMock(return_value=ProductSearchResponse(query="x", results=[])),
    )


def test_receipt_scan_uses_gemini_extraction(client: TestClient) -> None:
    """
    Satisfies: REQ-005 AC1
    Spec version: 1.0
    """
    from app.receipt_llm import _Extraction, _ExtractedItem

    household_id = _household(client)
    extraction = _Extraction(
        items=[
            _ExtractedItem(
                name="Great Value Whole Milk 1 Gallon",
                receipt_text="GV WHL MLK 1GAL 3.49",
                category="Dairy",
                quantity=1,
                price_paid=3.49,
            ),
            _ExtractedItem(
                name="Bananas",
                receipt_text="BANANAS 2 @ 0.25",
                category="Fruit",  # not an allowed category → Other
                quantity=2,
                price_paid=0.5,
            ),
        ]
    )
    generate = AsyncMock(return_value=extraction)
    with patch("app.receipt_llm._generate", new=generate), _no_catalog_hits():
        scanned = client.post(
            f"/v1/households/{household_id}/receipts/scan",
            json={"image_base64": base64.b64encode(b"\x89PNGfake").decode()},
            headers=_auth(),
        )

    assert scanned.status_code == 200
    body = scanned.json()
    assert body["engine"] == "gemini"
    assert [item["name"] for item in body["items"]] == [
        "Great Value Whole Milk 1 Gallon",
        "Bananas",
    ]
    assert body["items"][0]["category"] == "Dairy"
    assert body["items"][1]["category"] == "Other"
    assert body["items"][1]["quantity"] == 2
    assert body["items"][1]["price_paid"] == 0.5
    assert all(item["image_url"] for item in body["items"])

    image_part = generate.await_args.args[1][0]
    assert image_part.inline_data.mime_type == "image/png"


def test_receipt_scan_falls_back_to_ocr_when_gemini_fails(client: TestClient) -> None:
    """
    Satisfies: REQ-005 AC1
    Spec version: 1.0
    """
    household_id = _household(client)
    with patch(
        "app.receipt_llm._generate", new=AsyncMock(side_effect=RuntimeError("quota"))
    ), _no_catalog_hits():
        scanned = client.post(
            f"/v1/households/{household_id}/receipts/scan",
            json={"raw_text": "BANANAS 1.29\nTOTAL 1.29\n"},
            headers=_auth(),
        )

    assert scanned.status_code == 200
    body = scanned.json()
    assert body["engine"] == "text"
    assert body["items"][0]["name"] == "Bananas"


def test_receipt_scan_falls_back_when_gemini_finds_nothing(client: TestClient) -> None:
    from app.receipt_llm import _Extraction

    household_id = _household(client)
    with patch(
        "app.receipt_llm._generate", new=AsyncMock(return_value=_Extraction(items=[]))
    ), _no_catalog_hits():
        scanned = client.post(
            f"/v1/households/{household_id}/receipts/scan",
            json={"raw_text": "WHOLE MILK 3.49\n"},
            headers=_auth(),
        )

    assert scanned.status_code == 200
    assert scanned.json()["engine"] == "text"
