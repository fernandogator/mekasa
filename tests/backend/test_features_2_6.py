"""Tests for Places nearby, receipt OCR, invites, and household photo."""

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
    monkeypatch.delenv("GOOGLE_PLACES_API_KEY", raising=False)
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
        json={"name": "Casa Test", "photo_url": None},
        headers=_auth(uid),
    )
    assert created.status_code == 201
    household_id = created.json()["id"]
    addressed = client.put(
        f"/v1/households/{household_id}/address",
        json={"address": "123 Peachtree St", "latitude": 33.75, "longitude": -84.39},
        headers=_auth(uid),
    )
    assert addressed.status_code == 200
    return household_id


def test_nearby_stores_uses_stub_without_api_key(client: TestClient) -> None:
    """
    Satisfies: REQ-003 AC4
    Spec version: 1.0
    """
    household_id = _household(client)
    nearby = client.get(
        f"/v1/households/{household_id}/stores/nearby",
        headers=_auth(),
    )
    assert nearby.status_code == 200
    stores = nearby.json()["stores"]
    assert len(stores) >= 3
    assert all(store["provider"] == "stub" for store in stores)


def test_nearby_stores_uses_places_when_key_set(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """
    Satisfies: REQ-003 AC4
    Spec version: 1.0
    """
    import app.routers as routers
    from app.models import Store

    async def fake_fetch(**kwargs):
        return [
            Store(
                id="places-1",
                name="Publix Midtown",
                address="1 Peachtree",
                latitude=33.75,
                longitude=-84.39,
                distance_miles=0.8,
                provider="places",
            )
        ]

    monkeypatch.setattr(routers, "fetch_nearby_stores", fake_fetch)
    monkeypatch.setenv("GOOGLE_PLACES_API_KEY", "test-key")
    from app.config import get_settings

    get_settings.cache_clear()

    household_id = _household(client)
    nearby = client.get(
        f"/v1/households/{household_id}/stores/nearby",
        headers=_auth(),
    )
    assert nearby.status_code == 200
    stores = nearby.json()["stores"]
    assert stores[0]["provider"] == "places"
    assert stores[0]["name"] == "Publix Midtown"
    get_settings.cache_clear()


def test_receipt_scan_parses_raw_text(client: TestClient) -> None:
    """
    Satisfies: REQ-005 AC1
    Spec version: 1.0
    """
    household_id = _household(client)
    scanned = client.post(
        f"/v1/households/{household_id}/receipts/scan",
        json={
            "raw_text": "BANANAS 1.29\nWHOLE MILK 3.49\nSUBTOTAL 4.78\nTOTAL 4.78\n"
        },
        headers=_auth(),
    )
    assert scanned.status_code == 200
    body = scanned.json()
    assert body["engine"] == "text"
    assert len(body["items"]) == 2
    assert body["items"][0]["price_paid"] == 1.29


def test_household_photo_upload(client: TestClient) -> None:
    """
    Satisfies: REQ-002 AC2
    Spec version: 1.0
    """
    household_id = _household(client)
    response = client.post(
        f"/v1/households/{household_id}/photo",
        headers=_auth(),
        files={"file": ("home.jpg", b"\xff\xd8\xfffakejpeg", "image/jpeg")},
    )
    assert response.status_code == 200
    photo_url = response.json()["photo_url"]
    assert photo_url.startswith("data:image/jpeg;base64,")


def test_invite_flow_and_role_update(client: TestClient) -> None:
    """
    Satisfies: REQ-019 AC1–AC3
    Spec version: 1.0
    """
    household_id = _household(client)
    created = client.post(
        f"/v1/households/{household_id}/invites",
        json={"name": "Alex", "email": "alex@example.com", "role": "member"},
        headers=_auth(),
    )
    assert created.status_code == 201
    invite = created.json()
    assert invite["invite_link"]
    assert invite["token"]

    listed = client.get(f"/v1/households/{household_id}/invites", headers=_auth())
    assert listed.status_code == 200
    assert len(listed.json()["invites"]) == 1

    accepted = client.post(
        "/v1/invites/accept",
        json={"token": invite["token"]},
        headers=_auth("member-2"),
    )
    assert accepted.status_code == 200
    assert accepted.json()["role"] == "member"
    assert accepted.json()["uid"] == "member-2"

    members = client.get(f"/v1/households/{household_id}/members", headers=_auth())
    assert members.status_code == 200
    uids = {row["uid"] for row in members.json()["members"]}
    assert "owner-1" in uids
    assert "member-2" in uids

    promoted = client.patch(
        f"/v1/households/{household_id}/members/member-2",
        json={"role": "owner"},
        headers=_auth(),
    )
    assert promoted.status_code == 200
    assert promoted.json()["role"] == "owner"
