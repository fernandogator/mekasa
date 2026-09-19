"""Device registration + invite push hooks (PRD §8 scaffold)."""

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
    from app.devices_repository import reset_devices_repository
    from app.inventory_repository import reset_inventory_repository
    from app.members_repository import reset_members_repository
    from app.repository import reset_household_repository
    from app.shopping_list_repository import reset_shopping_list_repository

    get_settings.cache_clear()
    reset_household_repository()
    reset_inventory_repository()
    reset_shopping_list_repository()
    reset_members_repository()
    reset_devices_repository()

    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client

    get_settings.cache_clear()
    reset_household_repository()
    reset_inventory_repository()
    reset_shopping_list_repository()
    reset_members_repository()
    reset_devices_repository()


def _auth(uid: str = "owner-1") -> dict[str, str]:
    return {"Authorization": f"Bearer test:{uid}"}


def test_register_and_delete_device(client: TestClient) -> None:
    """PRD §8 — device token upsert + delete."""
    created = client.post(
        "/v1/devices",
        json={"fcm_token": "fcm-token-abc-12345678", "platform": "ios"},
        headers=_auth(),
    )
    assert created.status_code == 201
    body = created.json()
    assert body["uid"] == "owner-1"
    assert body["fcm_token"] == "fcm-token-abc-12345678"
    assert body["platform"] == "ios"

    again = client.post(
        "/v1/devices",
        json={"fcm_token": "fcm-token-abc-12345678", "platform": "ios"},
        headers=_auth(),
    )
    assert again.status_code == 201
    assert again.json()["id"] == body["id"]

    deleted = client.delete(
        "/v1/devices",
        params={"fcm_token": "fcm-token-abc-12345678"},
        headers=_auth(),
    )
    assert deleted.status_code == 204


def test_invite_create_with_device_does_not_fail(client: TestClient, monkeypatch) -> None:
    """Invite create still succeeds when FCM is unavailable / no-op."""
    import app.routers as routers

    calls: list[dict] = []

    def _fake(**kwargs):
        calls.append(kwargs)
        return {"sent": 0, "skipped": "test"}

    monkeypatch.setattr(routers, "notify_invite_created", _fake)

    hh = client.post("/v1/households", json={"name": "Push House"}, headers=_auth())
    assert hh.status_code == 201
    household_id = hh.json()["id"]

    client.post(
        "/v1/devices",
        json={"fcm_token": "owner-device-token-9999", "platform": "ios"},
        headers=_auth(),
    )

    invite = client.post(
        f"/v1/households/{household_id}/invites",
        json={"name": "Maya", "email": "maya@example.com", "role": "member"},
        headers=_auth(),
    )
    assert invite.status_code == 201
    assert calls, "expected notify_invite_created to be called"
    assert calls[0]["invitee_name"] == "Maya"


def test_send_push_no_tokens_skips() -> None:
    from app.push_notify import send_push_to_tokens

    result = send_push_to_tokens([], title="t", body="b")
    assert result["sent"] == 0
    assert result["skipped"] == "no_tokens"
