"""Unit tests for product name search (REQ-006 / REQ-007 AC2)."""

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


def test_product_search_requires_auth(client: TestClient) -> None:
    assert client.get("/v1/products/search", params={"q": "oreo"}).status_code == 401


def test_product_search_returns_variants(client: TestClient) -> None:
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.raise_for_status = MagicMock()
    mock_response.json.return_value = {
        "count": 3,
        "page_size": 24,
        "products": [
            {
                "code": "0044000032324",
                "product_name": "Oreo Chocolate Sandwich Cookies",
                "brands": "Oreo",
                "categories_tags": ["en:cookies"],
                "image_front_url": "https://images.openfoodfacts.org/oreo-regular.jpg",
            },
            {
                "code": "0044000044853",
                "product_name": "Oreo Double Stuf Chocolate Sandwich Cookies",
                "brands": "Oreo",
                "categories_tags": ["en:cookies"],
                "image_front_url": "https://images.openfoodfacts.org/oreo-double.jpg",
            },
            {
                "code": "0044000050120",
                "product_name": "Oreo Thins",
                "brands": "Oreo",
                "categories_tags": ["en:cookies"],
                "image_url": "https://images.openfoodfacts.org/oreo-thins.jpg",
            },
            {
                # Duplicate barcode — should be skipped
                "code": "0044000032324",
                "product_name": "Oreo Chocolate Sandwich Cookies Family Size",
                "brands": "Oreo",
                "categories_tags": ["en:cookies"],
            },
        ],
    }

    mock_client = AsyncMock()
    mock_client.get.return_value = mock_response
    mock_client.aclose = AsyncMock()

    with patch("app.barcode_lookup.httpx.AsyncClient", return_value=mock_client):
        response = client.get(
            "/v1/products/search",
            params={"q": "Oreos", "limit": 8},
            headers=_auth(),
        )

    assert response.status_code == 200
    body = response.json()
    assert body["query"] == "Oreos"
    assert len(body["results"]) == 3
    names = [hit["name"] for hit in body["results"]]
    assert any("Double Stuf" in name for name in names)
    assert any("Thins" in name for name in names)
    assert body["results"][0]["source"] == "openfoodfacts"
    assert body["results"][0]["barcode"] == "0044000032324"
    assert body["results"][0]["image_url"]
    assert body["results"][0]["category"] == "Pantry"


def test_product_search_short_query_empty(client: TestClient) -> None:
    response = client.get(
        "/v1/products/search",
        params={"q": "a"},
        headers=_auth(),
    )
    assert response.status_code == 200
    assert response.json()["results"] == []


def test_product_search_http_error_returns_empty(client: TestClient) -> None:
    import httpx

    mock_client = AsyncMock()
    mock_client.get.side_effect = httpx.ConnectError("offline")
    mock_client.aclose = AsyncMock()

    with patch("app.barcode_lookup.httpx.AsyncClient", return_value=mock_client):
        response = client.get(
            "/v1/products/search",
            params={"q": "oreo"},
            headers=_auth(),
        )

    assert response.status_code == 200
    assert response.json()["results"] == []
