"""Soft-delete / restore / purge inventory (REQ-INV-016–018)."""

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
    from app.inventory_repository import reset_inventory_repository
    from app.repository import reset_household_repository

    get_settings.cache_clear()
    reset_household_repository()
    reset_inventory_repository()

    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client

    get_settings.cache_clear()
    reset_household_repository()
    reset_inventory_repository()


def _auth(uid: str = "owner-1") -> dict[str, str]:
    return {"Authorization": f"Bearer test:{uid}"}


def _item(client: TestClient) -> tuple[str, str]:
    hh = client.post("/v1/households", json={"name": "Swipe House"}, headers=_auth())
    assert hh.status_code == 201
    household_id = hh.json()["id"]
    created = client.post(
        f"/v1/households/{household_id}/inventory",
        json={"name": "Avocados", "category": "Produce", "quantity": 1},
        headers=_auth(),
    )
    assert created.status_code == 201
    return household_id, created.json()["id"]


def test_soft_delete_restore_purge(client: TestClient) -> None:
    """REQ-INV-016 / 017 / 018."""
    household_id, item_id = _item(client)

    soft = client.delete(
        f"/v1/households/{household_id}/inventory/{item_id}",
        headers=_auth(),
    )
    assert soft.status_code == 204
    assert (
        client.get(
            f"/v1/households/{household_id}/inventory/{item_id}",
            headers=_auth(),
        ).status_code
        == 404
    )

    restored = client.post(
        f"/v1/households/{household_id}/inventory/{item_id}/restore",
        headers=_auth(),
    )
    assert restored.status_code == 200
    assert restored.json()["name"] == "Avocados"
    assert restored.json()["deleted"] is False

    client.delete(
        f"/v1/households/{household_id}/inventory/{item_id}",
        headers=_auth(),
    )
    purge = client.post(
        f"/v1/households/{household_id}/inventory/{item_id}/purge",
        headers=_auth(),
    )
    assert purge.status_code == 204
    assert (
        client.post(
            f"/v1/households/{household_id}/inventory/{item_id}/restore",
            headers=_auth(),
        ).status_code
        == 404
    )


def test_consume_then_soft_remove_path(client: TestClient) -> None:
    """REQ-INV-014 decrement then remove at qty 1."""
    household_id, _ = _item(client)
    # Start at qty 2
    created = client.post(
        f"/v1/households/{household_id}/inventory",
        json={"name": "Milk", "category": "Dairy", "quantity": 2},
        headers=_auth(),
    )
    item_id = created.json()["id"]
    consumed = client.post(
        f"/v1/households/{household_id}/inventory/{item_id}/consume",
        json={"amount": 1},
        headers=_auth(),
    )
    assert consumed.status_code == 200
    assert consumed.json()["quantity"] == 1
