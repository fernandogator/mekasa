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


def test_product_search_http_error_returns_503(client: TestClient) -> None:
    """An OFF outage is reported as 503, not as an empty result list."""
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

    assert response.status_code == 503
    assert "unavailable" in response.json()["detail"].casefold()
    # Retries transient OFF failures before giving up.
    assert mock_client.get.await_count >= 3


def test_product_search_partial_outage_still_returns_hits(client: TestClient) -> None:
    """If one expanded query fails but another succeeds, hits are returned normally."""
    import httpx

    ok = MagicMock()
    ok.status_code = 200
    ok.raise_for_status = MagicMock()
    ok.json.return_value = {
        "products": [
            {
                "code": "0049000006346",
                "product_name": "Coca-Cola Classic",
                "brands": "Coca-Cola",
                "categories_tags": ["en:sodas"],
            }
        ]
    }
    mock_client = AsyncMock()
    # "coke" query fails on every retry, the "coca-cola" alias succeeds.
    mock_client.get.side_effect = [httpx.ConnectError("offline")] * 3 + [ok] * 10
    mock_client.aclose = AsyncMock()

    with patch("app.barcode_lookup.httpx.AsyncClient", return_value=mock_client):
        response = client.get("/v1/products/search", params={"q": "coke"}, headers=_auth())

    assert response.status_code == 200
    assert response.json()["results"][0]["name"] == "Coca-Cola Classic"


def test_product_search_coke_expands_to_coca_cola(client: TestClient) -> None:
    """Brand nickname 'coke' should also query coca-cola and return beverage hits."""
    empty = MagicMock()
    empty.status_code = 200
    empty.raise_for_status = MagicMock()
    empty.json.return_value = {"products": []}

    cola = MagicMock()
    cola.status_code = 200
    cola.raise_for_status = MagicMock()
    cola.json.return_value = {
        "products": [
            {
                "code": "049000028911",
                "product_name": "Diet Coke",
                "brands": "Coca-Cola",
                "categories_tags": ["en:sodas", "en:beverages"],
                "image_front_url": "https://images.openfoodfacts.org/diet-coke.jpg",
            },
            {
                "code": "049000050103",
                "product_name": "Coca-Cola Classic",
                "brands": "COCA-COLA SERVICES SA/NV,Coca-Cola",
                "categories_tags": ["en:sodas", "en:carbonated-soft-drinks"],
                "categories": "Beverages, Sodas, Soft drinks",
            },
        ],
    }

    mock_client = AsyncMock()

    async def _get(*_args, **kwargs):
        terms = kwargs.get("params", {}).get("search_terms", "")
        if terms.casefold() == "coke":
            return empty
        return cola

    mock_client.get.side_effect = _get
    mock_client.aclose = AsyncMock()

    with patch("app.barcode_lookup.httpx.AsyncClient", return_value=mock_client):
        response = client.get(
            "/v1/products/search",
            params={"q": "coke", "limit": 8},
            headers=_auth(),
        )

    assert response.status_code == 200
    body = response.json()
    assert body["query"] == "coke"
    assert len(body["results"]) >= 1
    names = " ".join(hit["name"].casefold() for hit in body["results"])
    assert "coke" in names or "coca" in names
    assert body["results"][0]["category"] == "Beverages"
    # Prefer consumer brand over corporate legal name.
    brands = {hit.get("brand") for hit in body["results"]}
    assert "Coca-Cola" in brands
    searched = [
        call.kwargs["params"]["search_terms"]
        for call in mock_client.get.await_args_list
    ]
    assert "coke" in searched
    assert any("coca" in term.casefold() for term in searched)

def test_product_search_retries_then_succeeds(client: TestClient) -> None:
    import httpx

    fail = MagicMock()
    fail.status_code = 503
    fail.request = MagicMock()
    fail.raise_for_status.side_effect = httpx.HTTPStatusError(
        "503", request=fail.request, response=fail
    )

    ok = MagicMock()
    ok.status_code = 200
    ok.raise_for_status = MagicMock()
    ok.json.return_value = {
        "products": [
            {
                "code": "049000042566",
                "product_name": "Coca-Cola",
                "brands": "Coca-Cola",
                "categories_tags": ["en:sodas"],
            }
        ]
    }

    mock_client = AsyncMock()
    mock_client.get.side_effect = [fail, ok]
    mock_client.aclose = AsyncMock()

    with patch("app.barcode_lookup.httpx.AsyncClient", return_value=mock_client):
        response = client.get(
            "/v1/products/search",
            params={"q": "coca-cola", "limit": 5},
            headers=_auth(),
        )

    assert response.status_code == 200
    assert len(response.json()["results"]) == 1
    assert mock_client.get.await_count == 2


def test_expand_search_queries_coke() -> None:
    from app.barcode_lookup import expand_search_queries

    queries = expand_search_queries("Coke")
    assert queries[0] == "Coke"
    assert any("coca-cola" == q.casefold() for q in queries)


def test_map_category_soda_not_produce() -> None:
    from app.barcode_lookup import _map_category

    assert (
        _map_category(
            ["en:sodas", "en:beverages", "en:sans-jus-de-fruit"],
            "Beverages, Sodas, Soft drinks without fruit juice",
        )
        == "Beverages"
    )


def test_receipt_strong_match_coke_nickname() -> None:
    from app.receipt_ocr import _is_strong_match

    assert _is_strong_match("Coke", "Coca-Cola Original Taste")
    assert _is_strong_match("coca-cola", "Diet Coke")
