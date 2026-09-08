"""Unit tests for barcode / UPC lookup (REQ-004)."""

import os
from unittest.mock import AsyncMock, MagicMock, patch

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


def test_barcode_lookup_requires_auth(client: TestClient) -> None:
    assert client.get("/v1/barcode/3017624010701").status_code == 401


def test_barcode_lookup_found(client: TestClient) -> None:
    """
    Satisfies: REQ-004 AC1
    Spec version: 1.0
    """
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.raise_for_status = MagicMock()
    mock_response.json.return_value = {
        "status": 1,
        "code": "3017624010701",
        "product": {
            "product_name": "Nutella",
            "brands": "Ferrero",
            "categories": "Spreads",
            "categories_tags": ["en:breakfasts", "en:spreads"],
        },
    }

    mock_client = AsyncMock()
    mock_client.get.return_value = mock_response
    mock_client.aclose = AsyncMock()

    with patch("app.barcode_lookup.httpx.AsyncClient", return_value=mock_client):
        response = client.get("/v1/barcode/301-762-4010701", headers=_auth())

    assert response.status_code == 200
    body = response.json()
    assert body["found"] is True
    assert body["barcode"] == "3017624010701"
    assert "Nutella" in body["name"]
    assert body["source"] == "openfoodfacts"
    assert body["category"]


def test_barcode_lookup_unknown(client: TestClient) -> None:
    """
    Satisfies: REQ-004 AC2
    Spec version: 1.0
    """
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.raise_for_status = MagicMock()
    mock_response.json.return_value = {"status": 0, "status_verbose": "product not found"}

    mock_client = AsyncMock()
    mock_client.get.return_value = mock_response
    mock_client.aclose = AsyncMock()

    with patch("app.barcode_lookup.httpx.AsyncClient", return_value=mock_client):
        response = client.get("/v1/barcode/000000000000", headers=_auth())

    assert response.status_code == 200
    body = response.json()
    assert body["found"] is False
    assert body["barcode"] == "000000000000"
