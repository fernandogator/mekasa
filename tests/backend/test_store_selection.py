"""Saved store details, address geocoding and the store search provider (REQ-003 AC6–AC10)."""

import asyncio
import json
import os

import httpx
import pytest
from fastapi.testclient import TestClient

os.environ["ALLOW_TEST_AUTH"] = "true"
os.environ["ENVIRONMENT"] = "test"
os.environ["HOUSEHOLD_PERSISTENCE"] = "memory"


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ALLOW_TEST_AUTH", "true")
    monkeypatch.setenv("HOUSEHOLD_PERSISTENCE", "memory")
    monkeypatch.delenv("GOOGLE_PLACES_API_KEY", raising=False)
    from app.config import get_settings
    from app.repository import reset_household_repository

    get_settings.cache_clear()
    reset_household_repository()
    from app.main import create_app

    app = create_app()
    with TestClient(app) as test_client:
        test_client.app_ref = app  # type: ignore[attr-defined]
        yield test_client
    get_settings.cache_clear()
    reset_household_repository()


AUTH = {"Authorization": "Bearer test:owner-1"}


def _household(client: TestClient, **address) -> str:
    created = client.post("/v1/households", json={"name": "Casa", "photo_url": None}, headers=AUTH)
    assert created.status_code == 201
    household_id = created.json()["id"]
    if address:
        assert client.put(f"/v1/households/{household_id}/address", json=address, headers=AUTH).status_code == 200
    return household_id


def _with_settings(client: TestClient, **overrides) -> None:
    from app.config import Settings, get_settings

    client.app_ref.dependency_overrides[get_settings] = lambda: Settings(**overrides)  # type: ignore[attr-defined]


def test_saving_stores_with_details_returns_them_on_the_household(client: TestClient) -> None:
    """
    Satisfies: REQ-003 AC5, AC6
    Spec version: 1.0
    """
    household_id = _household(client, address="1 Main St", latitude=30.0, longitude=-97.0)
    saved = client.put(
        f"/v1/households/{household_id}/stores",
        json={
            "store_ids": ["b", "a"],
            "stores": [
                {"id": "a", "name": "H-E-B", "address": "1 Lamar", "distance_miles": 0.8},
                {"id": "b", "name": "Costco", "address": "2 Burnet", "distance_miles": 4.2},
                {"id": "z", "name": "Not selected", "address": "", "distance_miles": 9.0},
            ],
        },
        headers=AUTH,
    )
    assert saved.status_code == 200
    assert saved.json()["store_ids"] == ["b", "a"]
    assert [store["name"] for store in saved.json()["stores"]] == ["Costco", "H-E-B"]

    fetched = client.get("/v1/households/current", headers=AUTH).json()
    assert [store["id"] for store in fetched["stores"]] == ["b", "a"]


def test_saving_store_ids_only_clears_details(client: TestClient) -> None:
    """
    Satisfies: REQ-003 AC6
    Spec version: 1.0
    """
    household_id = _household(client)
    saved = client.put(f"/v1/households/{household_id}/stores", json={"store_ids": ["a"]}, headers=AUTH)
    assert saved.status_code == 200
    assert saved.json()["store_ids"] == ["a"]
    assert saved.json()["stores"] == []


def test_only_owners_save_stores(client: TestClient) -> None:
    """
    Satisfies: REQ-003 AC5
    Spec version: 1.0
    """
    household_id = _household(client)
    denied = client.put(
        f"/v1/households/{household_id}/stores",
        json={"store_ids": ["a"]},
        headers={"Authorization": "Bearer test:stranger"},
    )
    assert denied.status_code in {403, 404}


def test_address_without_coordinates_is_geocoded(client: TestClient, monkeypatch: pytest.MonkeyPatch) -> None:
    """
    Satisfies: REQ-003 AC7
    Spec version: 1.0
    """
    import app.routers as routers

    calls: list[str] = []

    async def fake_geocode(address: str, *, api_key: str):
        calls.append(address)
        return 30.27, -97.74

    monkeypatch.setattr(routers, "geocode_address", fake_geocode)
    household_id = _household(client)
    _with_settings(client, google_places_api_key="key", environment="test")
    saved = client.put(f"/v1/households/{household_id}/address", json={"address": "1842 Magnolia Ave"}, headers=AUTH)
    assert saved.status_code == 200
    assert (saved.json()["latitude"], saved.json()["longitude"]) == (30.27, -97.74)
    assert calls == ["1842 Magnolia Ave"]


def test_address_is_saved_when_geocoding_fails(client: TestClient, monkeypatch: pytest.MonkeyPatch) -> None:
    """
    Satisfies: REQ-003 AC7
    Spec version: 1.0
    """
    import app.routers as routers

    async def broken_geocode(address: str, *, api_key: str):
        raise httpx.ConnectError("down")

    monkeypatch.setattr(routers, "geocode_address", broken_geocode)
    household_id = _household(client)
    _with_settings(client, google_places_api_key="key", environment="test")
    saved = client.put(f"/v1/households/{household_id}/address", json={"address": "Nowhere"}, headers=AUTH)
    assert saved.status_code == 200
    assert saved.json()["address"] == "Nowhere"
    assert saved.json()["latitude"] is None


def test_search_asks_for_a_location_when_there_are_no_coordinates(client: TestClient) -> None:
    """
    Satisfies: REQ-003 AC10
    Spec version: 1.0
    """
    household_id = _household(client)
    nearby = client.get(f"/v1/households/{household_id}/stores/nearby", headers=AUTH)
    assert nearby.status_code == 200
    assert nearby.json()["needs_location"] is True


def test_production_never_returns_placeholder_stores(client: TestClient, monkeypatch: pytest.MonkeyPatch) -> None:
    """
    Satisfies: REQ-003 AC9
    Spec version: 1.0
    """
    import app.routers as routers

    household_id = _household(client, address="1 Main St", latitude=30.0, longitude=-97.0)

    _with_settings(client, environment="prod")
    nearby = client.get(f"/v1/households/{household_id}/stores/nearby", headers=AUTH)
    assert nearby.status_code == 200
    assert nearby.json()["stores"] == []
    assert nearby.json()["needs_location"] is False

    async def failing_fetch(**kwargs):
        raise httpx.HTTPStatusError("403", request=httpx.Request("POST", "https://x"), response=httpx.Response(403))

    monkeypatch.setattr(routers, "fetch_nearby_stores", failing_fetch)
    _with_settings(client, environment="prod", google_places_api_key="key")
    assert client.get(f"/v1/households/{household_id}/stores/nearby", headers=AUTH).json()["stores"] == []


def _place(place_id: str, name: str, lat: float, lng: float) -> dict:
    return {
        "id": place_id,
        "displayName": {"text": name},
        "shortFormattedAddress": f"{name} address",
        "location": {"latitude": lat, "longitude": lng},
    }


def test_places_search_keeps_groceries_and_known_big_box_chains() -> None:
    """
    Satisfies: REQ-003 AC4, AC8
    Spec version: 1.0
    """
    from app.places_lookup import FIELD_MASK, fetch_nearby_stores

    requests: list[dict] = []

    def handler(request: httpx.Request) -> httpx.Response:
        body = json.loads(request.content)
        requests.append({"body": body, "headers": request.headers})
        if "grocery_store" in body["includedTypes"]:
            places = [_place("heb", "H-E-B", 30.01, -97.0), _place("far", "Far Market", 31.5, -97.0)]
        else:
            places = [_place("wm", "Walmart Supercenter", 30.05, -97.0), _place("macys", "Macy's", 30.001, -97.0)]
        return httpx.Response(200, json={"places": places})

    async def run():
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as http:
            return await fetch_nearby_stores(latitude=30.0, longitude=-97.0, radius_miles=15, api_key="k", client=http)

    stores = asyncio.run(run())

    assert [store.id for store in stores] == ["heb", "wm"]
    assert all(store.provider == "places" for store in stores)
    assert stores[0].address == "H-E-B address"
    assert requests[0]["headers"]["X-Goog-Api-Key"] == "k"
    assert requests[0]["headers"]["X-Goog-FieldMask"] == FIELD_MASK
    assert requests[0]["body"]["rankPreference"] == "DISTANCE"
    assert requests[0]["body"]["locationRestriction"]["circle"]["radius"] == pytest.approx(15 * 1609.34, abs=1)


def test_geocode_returns_the_best_match_or_none() -> None:
    """
    Satisfies: REQ-003 AC7
    Spec version: 1.0
    """
    from app.places_lookup import geocode_address

    def found(request: httpx.Request) -> httpx.Response:
        assert request.url.params["address"] == "1842 Magnolia Ave"
        return httpx.Response(200, json={"status": "OK", "results": [{"geometry": {"location": {"lat": 1.5, "lng": 2.5}}}]})

    async def run(handler, address):
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as http:
            return await geocode_address(address, api_key="k", client=http)

    assert asyncio.run(run(found, "1842 Magnolia Ave")) == (1.5, 2.5)

    def empty(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"status": "ZERO_RESULTS", "results": []})

    assert asyncio.run(run(empty, "??")) is None
