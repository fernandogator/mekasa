"""Backend unit tests for shopping list CRUD + low-stock sync."""

import os

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
        json={"name": "Casa List"},
        headers=_auth(uid),
    )
    assert created.status_code == 201
    return created.json()["id"]


def test_shopping_list_crud_approve_and_sync(client: TestClient) -> None:
    """
    Satisfies: REQ-011, REQ-012, REQ-013, REQ-014
    Spec version: 1.0
    """
    household_id = _household(client)

    custom = client.post(
        f"/v1/households/{household_id}/shopping-list",
        json={"name": "Tortillas", "quantity": 2, "kind": "custom"},
        headers=_auth(),
    )
    assert custom.status_code == 201
    custom_id = custom.json()["id"]
    assert custom.json()["quantity"] == 2

    # Merge open rows by name
    merged = client.post(
        f"/v1/households/{household_id}/shopping-list",
        json={"name": "tortillas", "quantity": 1, "kind": "custom"},
        headers=_auth(),
    )
    assert merged.status_code == 201
    assert merged.json()["id"] == custom_id
    assert merged.json()["quantity"] == 3

    request = client.post(
        f"/v1/households/{household_id}/shopping-list",
        json={
            "name": "Candy",
            "quantity": 1,
            "needs_approval": True,
            "requested_by": "Leo",
            "kind": "request",
        },
        headers=_auth(),
    )
    assert request.status_code == 201
    request_id = request.json()["id"]
    assert request.json()["needs_approval"] is True

    approved = client.post(
        f"/v1/households/{household_id}/shopping-list/{request_id}/approve",
        headers=_auth(),
    )
    assert approved.status_code == 200
    assert approved.json()["needs_approval"] is False

    checked = client.patch(
        f"/v1/households/{household_id}/shopping-list/{custom_id}",
        json={"is_checked": True},
        headers=_auth(),
    )
    assert checked.status_code == 200
    assert checked.json()["is_checked"] is True

    # Low-stock inventory → sync
    inv = client.post(
        f"/v1/households/{household_id}/inventory",
        json={
            "name": "Bananas",
            "category": "Produce",
            "quantity": 1,
            "low_stock_threshold": 2,
            "source": "manual",
        },
        headers=_auth(),
    )
    assert inv.status_code == 201

    synced = client.post(
        f"/v1/households/{household_id}/shopping-list/sync-from-inventory",
        headers=_auth(),
    )
    assert synced.status_code == 200
    assert any(item["name"] == "Bananas" for item in synced.json()["added"])
    assert any(item["name"] == "Bananas" for item in synced.json()["items"])

    listed = client.get(
        f"/v1/households/{household_id}/shopping-list",
        headers=_auth(),
    )
    assert listed.status_code == 200
    assert len(listed.json()["items"]) >= 3

    pending = client.post(
        f"/v1/households/{household_id}/shopping-list",
        json={
            "name": "Soda",
            "quantity": 1,
            "needs_approval": True,
            "requested_by": "Mia",
            "kind": "request",
        },
        headers=_auth(),
    )
    pending_id = pending.json()["id"]
    rejected = client.post(
        f"/v1/households/{household_id}/shopping-list/{pending_id}/reject",
        headers=_auth(),
    )
    assert rejected.status_code == 204


def test_shopping_list_forbidden_for_other_user(client: TestClient) -> None:
    household_id = _household(client, "a")
    created = client.post(
        f"/v1/households/{household_id}/shopping-list",
        json={"name": "Milk", "quantity": 1},
        headers=_auth("a"),
    )
    assert created.status_code == 201
    assert (
        client.get(
            f"/v1/households/{household_id}/shopping-list",
            headers=_auth("b"),
        ).status_code
        == 403
    )
