"""Backend unit tests for inventory CRUD + consume."""

import os

import pytest
from fastapi.testclient import TestClient

os.environ["ALLOW_TEST_AUTH"] = "true"
os.environ["ENVIRONMENT"] = "test"
os.environ["HOUSEHOLD_PERSISTENCE"] = "memory"


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch):
    """Fresh app client with in-memory repositories per test."""
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
        json={"name": "Casa Inventory"},
        headers=_auth(uid),
    )
    assert created.status_code == 201
    return created.json()["id"]


def test_inventory_crud_and_consume(client: TestClient) -> None:
    """
    Satisfies: REQ-006, REQ-008, REQ-009
    Spec version: 1.0
    """
    household_id = _household(client)

    created = client.post(
        f"/v1/households/{household_id}/inventory",
        json={
            "name": "Whole Milk",
            "category": "Dairy",
            "quantity": 2,
            "low_stock_threshold": 1,
            "price_paid": 3.49,
            "barcode": "041220576037",
            "source": "manual",
        },
        headers=_auth(),
    )
    assert created.status_code == 201
    item = created.json()
    item_id = item["id"]
    assert item["name"] == "Whole Milk"
    assert item["quantity"] == 2
    assert item["household_id"] == household_id

    # Merge same name+category
    merged = client.post(
        f"/v1/households/{household_id}/inventory",
        json={"name": "whole milk", "category": "Dairy", "quantity": 1, "source": "barcode"},
        headers=_auth(),
    )
    assert merged.status_code == 201
    assert merged.json()["id"] == item_id
    assert merged.json()["quantity"] == 3

    listed = client.get(f"/v1/households/{household_id}/inventory", headers=_auth())
    assert listed.status_code == 200
    assert listed.json()["household_id"] == household_id
    assert len(listed.json()["items"]) == 1

    updated = client.patch(
        f"/v1/households/{household_id}/inventory/{item_id}",
        json={"low_stock_threshold": 2, "quantity": 2},
        headers=_auth(),
    )
    assert updated.status_code == 200
    assert updated.json()["low_stock_threshold"] == 2
    assert updated.json()["quantity"] == 2

    consumed = client.post(
        f"/v1/households/{household_id}/inventory/{item_id}/consume",
        json={"amount": 1},
        headers=_auth(),
    )
    assert consumed.status_code == 200
    assert consumed.json()["quantity"] == 1

    by_barcode = client.post(
        f"/v1/households/{household_id}/inventory/consume-by-barcode",
        json={"barcode": "041220576037", "amount": 1},
        headers=_auth(),
    )
    assert by_barcode.status_code == 200
    body = by_barcode.json()
    assert body["found"] is True
    assert body["item"]["quantity"] == 0

    unknown = client.post(
        f"/v1/households/{household_id}/inventory/consume-by-barcode",
        json={"barcode": "000000000000"},
        headers=_auth(),
    )
    assert unknown.status_code == 200
    unknown_body = unknown.json()
    assert unknown_body["found"] is False
    assert unknown_body["unknown_event"]["barcode"] == "000000000000"
    events = client.get(
        f"/v1/households/{household_id}/trash-scans/unknown",
        headers=_auth(),
    )
    assert events.status_code == 200
    assert any(event["barcode"] == "000000000000" for event in events.json())

    deleted = client.delete(
        f"/v1/households/{household_id}/inventory/{item_id}",
        headers=_auth(),
    )
    assert deleted.status_code == 204
    assert client.get(
        f"/v1/households/{household_id}/inventory/{item_id}",
        headers=_auth(),
    ).status_code == 404


def test_inventory_forbidden_for_other_user(client: TestClient) -> None:
    household_id = _household(client, "a")
    created = client.post(
        f"/v1/households/{household_id}/inventory",
        json={"name": "Eggs", "category": "Dairy", "quantity": 1},
        headers=_auth("a"),
    )
    assert created.status_code == 201
    item_id = created.json()["id"]

    listed = client.get(
        f"/v1/households/{household_id}/inventory",
        headers=_auth("b"),
    )
    assert listed.status_code == 403

    patched = client.patch(
        f"/v1/households/{household_id}/inventory/{item_id}",
        json={"quantity": 9},
        headers=_auth("b"),
    )
    assert patched.status_code == 403


def test_inventory_requires_auth(client: TestClient) -> None:
    household_id = _household(client)
    assert (
        client.get(f"/v1/households/{household_id}/inventory").status_code == 401
    )
