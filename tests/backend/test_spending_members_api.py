"""Backend unit tests for spending / purchase events and member ACL."""

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
    from app.members_repository import reset_members_repository
    from app.repository import reset_household_repository
    from app.shopping_list_repository import reset_shopping_list_repository
    from app.spending_repository import reset_spending_repository

    get_settings.cache_clear()
    reset_household_repository()
    reset_inventory_repository()
    reset_shopping_list_repository()
    reset_members_repository()
    reset_spending_repository()

    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client

    get_settings.cache_clear()
    reset_household_repository()
    reset_inventory_repository()
    reset_shopping_list_repository()
    reset_members_repository()
    reset_spending_repository()


def _auth(uid: str = "owner-1") -> dict[str, str]:
    return {"Authorization": f"Bearer test:{uid}"}


def _household(client: TestClient, uid: str = "owner-1") -> str:
    created = client.post(
        "/v1/households",
        json={"name": "Spend House"},
        headers=_auth(uid),
    )
    assert created.status_code == 201
    return created.json()["id"]


def test_purchase_and_spending_report(client: TestClient) -> None:
    """
    Satisfies: REQ-015 AC1, REQ-017 AC2, REQ-018 AC1
    Spec version: 1.0
    """
    household_id = _household(client)
    created = client.post(
        f"/v1/households/{household_id}/purchases",
        json={
            "name": "Milk",
            "category": "Dairy",
            "price_paid": 3.49,
            "quantity": 2,
            "source": "manual",
        },
        headers=_auth(),
    )
    assert created.status_code == 201
    event_id = created.json()["id"]

    report = client.get(
        f"/v1/households/{household_id}/spending?period=week",
        headers=_auth(),
    )
    assert report.status_code == 200
    body = report.json()
    assert body["total"] == 6.98
    assert body["by_category"][0]["category"] == "Dairy"
    assert len(body["events"]) == 1

    patched = client.patch(
        f"/v1/households/{household_id}/purchases/{event_id}",
        json={"category": "Produce"},
        headers=_auth(),
    )
    assert patched.status_code == 200
    assert patched.json()["category"] == "Produce"

    filtered = client.get(
        f"/v1/households/{household_id}/spending?period=week&category=Produce",
        headers=_auth(),
    )
    assert filtered.status_code == 200
    assert filtered.json()["total"] == 6.98


def test_inventory_create_records_purchase_event(client: TestClient) -> None:
    """
    Satisfies: REQ-015 AC1
    Spec version: 1.0
    """
    household_id = _household(client)
    item = client.post(
        f"/v1/households/{household_id}/inventory",
        json={
            "name": "Eggs",
            "category": "Dairy",
            "quantity": 1,
            "price_paid": 4.25,
            "source": "manual",
        },
        headers=_auth(),
    )
    assert item.status_code == 201
    report = client.get(
        f"/v1/households/{household_id}/spending?period=week",
        headers=_auth(),
    )
    assert report.status_code == 200
    assert report.json()["total"] == 4.25


def test_invited_member_can_access_inventory_and_current(client: TestClient) -> None:
    """
    Satisfies: REQ-019 AC2 + shared inventory ACL
    Spec version: 1.0
    """
    household_id = _household(client, uid="owner-1")
    invite = client.post(
        f"/v1/households/{household_id}/invites",
        json={"name": "Sam", "email": "sam@example.com", "role": "member"},
        headers=_auth("owner-1"),
    )
    assert invite.status_code == 201
    token = invite.json()["token"]

    accepted = client.post(
        "/v1/invites/accept",
        json={"token": token},
        headers=_auth("member-2"),
    )
    assert accepted.status_code == 200

    current = client.get("/v1/households/current", headers=_auth("member-2"))
    assert current.status_code == 200
    assert current.json()["id"] == household_id

    listed = client.get(
        f"/v1/households/{household_id}/inventory",
        headers=_auth("member-2"),
    )
    assert listed.status_code == 200

    stranger = client.get(
        f"/v1/households/{household_id}/inventory",
        headers=_auth("stranger-9"),
    )
    assert stranger.status_code == 403
