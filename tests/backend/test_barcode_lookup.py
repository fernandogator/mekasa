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
            "image_front_url": "https://images.openfoodfacts.org/nutella.jpg",
            "image_url": "https://images.openfoodfacts.org/nutella-fallback.jpg",
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
    assert body["image_url"] == "https://images.openfoodfacts.org/nutella.jpg"


def test_barcode_lookup_uses_category_placeholder_without_off_image(client: TestClient) -> None:
    """ADR-006 step 3: category placeholder when OFF has no image."""
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.raise_for_status = MagicMock()
    mock_response.json.return_value = {
        "status": 1,
        "code": "012345678905",
        "product": {
            "product_name": "Organic Black Beans",
            "brands": "Test Brand",
            "categories_tags": ["en:canned-beans"],
        },
    }

    mock_client = AsyncMock()
    mock_client.get.return_value = mock_response
    mock_client.aclose = AsyncMock()

    with patch("app.barcode_lookup.httpx.AsyncClient", return_value=mock_client):
        response = client.get("/v1/barcode/012345678905", headers=_auth())

    assert response.status_code == 200
    body = response.json()
    assert body["found"] is True
    assert body["image_url"]
    assert "placehold.co" in body["image_url"]


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
    assert body["image_url"] is None


# --- Resilience: code shapes, sister databases, outages, caching -----------------


def _ok(payload: dict) -> MagicMock:
    response = MagicMock()
    response.status_code = 200
    response.raise_for_status = MagicMock()
    response.json.return_value = payload
    return response


def _not_found() -> MagicMock:
    response = MagicMock()
    response.status_code = 404
    response.raise_for_status = MagicMock()
    response.json.return_value = {"status": 0, "status_verbose": "product not found"}
    return response


def _router(routes: dict[str, MagicMock], default: MagicMock | None = None):
    """Return an AsyncMock `get` that picks a response by the code in the URL."""

    async def _get(url: str, params=None):
        code = url.rsplit("/", 1)[-1]
        for needle, response in routes.items():
            if needle in url or code == needle:
                return response
        if default is not None:
            return default
        return _not_found()

    return _get


def test_barcode_lookup_expands_upce_to_upca(client: TestClient) -> None:
    """A Coke can's UPC-E (04963406) resolves via the UPC-A record OFF actually has."""
    coke = _ok(
        {
            "status": 1,
            "product": {
                "code": "0049000006346",
                "product_name": "Coca-Cola Classic",
                "brands": "Coca-Cola",
                "categories_tags": ["en:sodas"],
            },
        }
    )
    mock_client = AsyncMock()
    mock_client.get.side_effect = _router({"openfoodfacts.org/api/v2/product/0049000006346": coke})
    mock_client.aclose = AsyncMock()

    with patch("app.barcode_lookup.httpx.AsyncClient", return_value=mock_client):
        response = client.get("/v1/barcode/04963406", headers=_auth())

    body = response.json()
    assert response.status_code == 200
    assert body["found"] is True
    assert body["name"] == "Coca-Cola Classic"
    assert body["barcode"] == "04963406"
    tried = [call.args[0] for call in mock_client.get.await_args_list]
    assert any(url.endswith("/0049000006346") for url in tried)


def test_barcode_lookup_falls_back_to_open_products_facts(client: TestClient) -> None:
    """Household items live in Open Products Facts, not Open Food Facts."""
    detergent = _ok(
        {
            "status": 1,
            "product": {
                "code": "0037000862390",
                "product_name": "Tide Pods",
                "brands": "Tide",
                "categories_tags": ["en:laundry-detergents"],
            },
        }
    )
    mock_client = AsyncMock()
    mock_client.get.side_effect = _router({"openproductsfacts.org": detergent})
    mock_client.aclose = AsyncMock()

    with patch("app.barcode_lookup.httpx.AsyncClient", return_value=mock_client):
        response = client.get("/v1/barcode/037000862390", headers=_auth())

    body = response.json()
    assert response.status_code == 200
    assert body["found"] is True
    assert body["name"] == "Tide Pods"
    assert body["source"] == "openproductsfacts"
    assert body["category"] == "Household"
    hosts = {call.args[0].split("/")[2] for call in mock_client.get.await_args_list}
    assert "world.openfoodfacts.org" in hosts
    assert "world.openproductsfacts.org" in hosts


def test_barcode_lookup_uses_localised_name_when_english_missing(client: TestClient) -> None:
    mock_client = AsyncMock()
    mock_client.get.return_value = _ok(
        {
            "status": 1,
            "product": {
                "code": "7501055300075",
                "product_name": "",
                "product_name_es": "Coca-Cola Sin Azúcar",
                "brands": "Coca-Cola",
                "categories_tags": ["en:sodas"],
            },
        }
    )
    mock_client.aclose = AsyncMock()

    with patch("app.barcode_lookup.httpx.AsyncClient", return_value=mock_client):
        response = client.get("/v1/barcode/7501055300075", headers=_auth())

    body = response.json()
    assert body["found"] is True
    assert body["name"] == "Coca-Cola Sin Azúcar"


def test_barcode_lookup_reports_503_when_databases_unreachable(client: TestClient) -> None:
    """Timeouts / 429 / 5xx must not masquerade as 'product not found'."""
    import httpx

    mock_client = AsyncMock()
    mock_client.get.side_effect = httpx.ReadTimeout("slow")
    mock_client.aclose = AsyncMock()

    with patch("app.barcode_lookup.httpx.AsyncClient", return_value=mock_client), patch(
        "app.barcode_lookup.asyncio.sleep", new_callable=AsyncMock
    ):
        response = client.get("/v1/barcode/049000006346", headers=_auth())

    assert response.status_code == 503
    assert "unavailable" in response.json()["detail"].casefold()


def test_barcode_lookup_rate_limited_then_404_is_not_found(client: TestClient) -> None:
    """A 429 from one database plus real 404s elsewhere still counts as unavailable."""
    throttled = MagicMock()
    throttled.status_code = 429
    throttled.headers = {}
    throttled.request = MagicMock()
    import httpx

    throttled.raise_for_status.side_effect = httpx.HTTPStatusError(
        "429", request=MagicMock(), response=throttled
    )
    mock_client = AsyncMock()
    mock_client.get.side_effect = _router({"openfoodfacts.org": throttled})
    mock_client.aclose = AsyncMock()

    with patch("app.barcode_lookup.httpx.AsyncClient", return_value=mock_client), patch(
        "app.barcode_lookup.asyncio.sleep", new_callable=AsyncMock
    ):
        response = client.get("/v1/barcode/049000006346", headers=_auth())

    assert response.status_code == 503


def test_barcode_lookup_caches_hits_and_misses(client: TestClient) -> None:
    nutella = _ok(
        {
            "status": 1,
            "product": {"code": "3017624010701", "product_name": "Nutella", "brands": "Ferrero"},
        }
    )
    mock_client = AsyncMock()
    mock_client.get.side_effect = _router({"3017624010701": nutella})
    mock_client.aclose = AsyncMock()

    with patch("app.barcode_lookup.httpx.AsyncClient", return_value=mock_client):
        first = client.get("/v1/barcode/3017624010701", headers=_auth())
        hit_calls = mock_client.get.await_count
        second = client.get("/v1/barcode/3017624010701", headers=_auth())
        assert mock_client.get.await_count == hit_calls, "second hit served from cache"

        client.get("/v1/barcode/000000000000", headers=_auth())
        miss_calls = mock_client.get.await_count
        client.get("/v1/barcode/000000000000", headers=_auth())
        assert mock_client.get.await_count == miss_calls, "misses are cached too"

    assert first.json()["found"] is True
    assert second.json()["name"] == first.json()["name"]


def test_barcode_lookup_outage_is_not_cached(client: TestClient) -> None:
    import httpx

    mock_client = AsyncMock()
    mock_client.get.side_effect = httpx.ReadTimeout("slow")
    mock_client.aclose = AsyncMock()

    with patch("app.barcode_lookup.httpx.AsyncClient", return_value=mock_client), patch(
        "app.barcode_lookup.asyncio.sleep", new_callable=AsyncMock
    ):
        assert client.get("/v1/barcode/049000006346", headers=_auth()).status_code == 503
        first_calls = mock_client.get.await_count
        assert client.get("/v1/barcode/049000006346", headers=_auth()).status_code == 503
        assert mock_client.get.await_count > first_calls


def test_category_mapping_uses_whole_words() -> None:
    """'cola' inside 'chocolate' must not turn a spread into a beverage."""
    from app.barcode_lookup import _map_category

    assert _map_category(["en:spreads", "en:cocoa-and-hazelnuts-spreads"], None) == "Pantry"
    assert _map_category(["en:meats", "en:steaks"], None) == "Meat"
    assert _map_category(["en:beverages", "en:colas"], None) == "Beverages"
    assert _map_category(["en:dairies", "en:chocolate-milks"], None) == "Dairy"
    assert _map_category(["en:fresh-fruits", "en:pineapples"], None) == "Produce"
