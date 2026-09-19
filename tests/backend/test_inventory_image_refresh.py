"""Tests for inventory image refresh (UI-006 / ADR-006)."""

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


def _household(client: TestClient, uid: str = "owner-1") -> str:
    created = client.post(
        "/v1/households",
        json={"name": "Casa Images"},
        headers=_auth(uid),
    )
    assert created.status_code == 201
    return created.json()["id"]


def test_refresh_image_requires_auth(client: TestClient) -> None:
    household_id = _household(client)
    created = client.post(
        f"/v1/households/{household_id}/inventory",
        json={"name": "Milk", "category": "Dairy", "barcode": "041220576037"},
        headers=_auth(),
    )
    item_id = created.json()["id"]
    assert (
        client.post(
            f"/v1/households/{household_id}/inventory/{item_id}/refresh-image"
        ).status_code
        == 401
    )


def test_refresh_image_from_barcode_lookup(client: TestClient) -> None:
    """Missing image_url is filled from Open Food Facts and persisted."""
    household_id = _household(client)
    created = client.post(
        f"/v1/households/{household_id}/inventory",
        json={
            "name": "Nutella",
            "category": "Pantry",
            "quantity": 1,
            "barcode": "3017624010701",
            "source": "barcode",
        },
        headers=_auth(),
    )
    assert created.status_code == 201
    item = created.json()
    assert item["image_url"] is None
    item_id = item["id"]

    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.raise_for_status = MagicMock()
    mock_response.json.return_value = {
        "status": 1,
        "code": "3017624010701",
        "product": {
            "product_name": "Nutella",
            "brands": "Ferrero",
            "categories_tags": ["en:spreads"],
            "image_front_url": "https://images.openfoodfacts.org/nutella.jpg",
        },
    }
    mock_client = AsyncMock()
    mock_client.get.return_value = mock_response
    mock_client.aclose = AsyncMock()

    with patch("app.barcode_lookup.httpx.AsyncClient", return_value=mock_client):
        response = client.post(
            f"/v1/households/{household_id}/inventory/{item_id}/refresh-image",
            headers=_auth(),
        )

    assert response.status_code == 200
    body = response.json()
    assert body["id"] == item_id
    assert body["image_url"] == "https://images.openfoodfacts.org/nutella.jpg"

    fetched = client.get(
        f"/v1/households/{household_id}/inventory/{item_id}",
        headers=_auth(),
    )
    assert fetched.json()["image_url"] == "https://images.openfoodfacts.org/nutella.jpg"


def test_refresh_image_skips_when_already_present(client: TestClient) -> None:
    household_id = _household(client)
    created = client.post(
        f"/v1/households/{household_id}/inventory",
        json={
            "name": "Milk",
            "category": "Dairy",
            "barcode": "041220576037",
            "image_url": "https://cdn.example/milk.jpg",
        },
        headers=_auth(),
    )
    item_id = created.json()["id"]

    with patch("app.barcode_lookup.lookup_barcode", new_callable=AsyncMock) as lookup:
        response = client.post(
            f"/v1/households/{household_id}/inventory/{item_id}/refresh-image",
            headers=_auth(),
        )
        lookup.assert_not_called()

    assert response.status_code == 200
    assert response.json()["image_url"] == "https://cdn.example/milk.jpg"


def test_refresh_image_placeholder_without_barcode(client: TestClient) -> None:
    household_id = _household(client)
    created = client.post(
        f"/v1/households/{household_id}/inventory",
        json={"name": "Bananas", "category": "Produce", "source": "manual"},
        headers=_auth(),
    )
    item_id = created.json()["id"]
    assert created.json()["image_url"] is None

    response = client.post(
        f"/v1/households/{household_id}/inventory/{item_id}/refresh-image",
        headers=_auth(),
    )
    assert response.status_code == 200
    assert "placehold.co" in response.json()["image_url"]
    assert "Produce" in response.json()["image_url"]


def test_refresh_image_unknown_barcode_leaves_unset(client: TestClient) -> None:
    household_id = _household(client)
    created = client.post(
        f"/v1/households/{household_id}/inventory",
        json={
            "name": "Mystery",
            "category": "Other",
            "barcode": "000000000000",
            "source": "barcode",
        },
        headers=_auth(),
    )
    item_id = created.json()["id"]

    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.raise_for_status = MagicMock()
    mock_response.json.return_value = {"status": 0, "status_verbose": "product not found"}
    mock_client = AsyncMock()
    mock_client.get.return_value = mock_response
    mock_client.aclose = AsyncMock()

    with patch("app.barcode_lookup.httpx.AsyncClient", return_value=mock_client):
        response = client.post(
            f"/v1/households/{household_id}/inventory/{item_id}/refresh-image",
            headers=_auth(),
        )

    assert response.status_code == 200
    assert response.json()["image_url"] is None
