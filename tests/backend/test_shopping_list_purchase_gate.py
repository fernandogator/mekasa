"""REQ-014: only owners (or future buyer permission) mark shopping items purchased."""

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

    get_settings.cache_clear()
    reset_household_repository()
    reset_inventory_repository()
    reset_shopping_list_repository()
    reset_members_repository()

    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client

    get_settings.cache_clear()
    reset_household_repository()
    reset_inventory_repository()
    reset_shopping_list_repository()
    reset_members_repository()


def _auth(uid: str) -> dict[str, str]:
    return {"Authorization": f"Bearer test:{uid}"}


def _invite_member(client: TestClient, household_id: str, member_uid: str = "member-1") -> None:
    invite = client.post(
        f"/v1/households/{household_id}/invites",
        json={"name": "Leo", "email": "leo@example.com", "role": "member"},
        headers=_auth("owner-1"),
    )
    assert invite.status_code == 201
    accepted = client.post(
        "/v1/invites/accept",
        json={"token": invite.json()["token"]},
        headers=_auth(member_uid),
    )
    assert accepted.status_code == 200


def test_member_cannot_mark_purchased_but_can_request(client: TestClient) -> None:
    """
    Satisfies: REQ-014 AC1–AC2, REQ-012
    Spec version: 1.0
    """
    created = client.post(
        "/v1/households",
        json={"name": "Purchase Gate"},
        headers=_auth("owner-1"),
    )
    household_id = created.json()["id"]
    _invite_member(client, household_id)

    item = client.post(
        f"/v1/households/{household_id}/shopping-list",
        json={"name": "Milk", "quantity": 1, "kind": "custom"},
        headers=_auth("owner-1"),
    )
    assert item.status_code == 201
    item_id = item.json()["id"]

    # Member cannot check off / mark purchased
    forbidden = client.patch(
        f"/v1/households/{household_id}/shopping-list/{item_id}",
        json={"is_checked": True},
        headers=_auth("member-1"),
    )
    assert forbidden.status_code == 403

    # Owner can
    allowed = client.patch(
        f"/v1/households/{household_id}/shopping-list/{item_id}",
        json={"is_checked": True},
        headers=_auth("owner-1"),
    )
    assert allowed.status_code == 200
    assert allowed.json()["is_checked"] is True

    # Member add becomes a request needing approval
    request = client.post(
        f"/v1/households/{household_id}/shopping-list",
        json={"name": "Cookies", "quantity": 1, "kind": "custom"},
        headers=_auth("member-1"),
    )
    assert request.status_code == 201
    body = request.json()
    assert body["needs_approval"] is True
    assert body["kind"] == "request"

    # Member cannot approve
    assert (
        client.post(
            f"/v1/households/{household_id}/shopping-list/{body['id']}/approve",
            headers=_auth("member-1"),
        ).status_code
        == 403
    )

    # Owner can approve
    approved = client.post(
        f"/v1/households/{household_id}/shopping-list/{body['id']}/approve",
        headers=_auth("owner-1"),
    )
    assert approved.status_code == 200
    assert approved.json()["needs_approval"] is False
