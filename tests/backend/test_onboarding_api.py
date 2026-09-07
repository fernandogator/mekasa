"""Backend unit tests for the thin onboarding API."""

import os

import pytest
from fastapi.testclient import TestClient

os.environ["ALLOW_TEST_AUTH"] = "true"
os.environ["ENVIRONMENT"] = "test"


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch):
    """Fresh app client with in-memory repository per test."""
    monkeypatch.setenv("ALLOW_TEST_AUTH", "true")
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


def test_health(client: TestClient) -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_me_requires_auth(client: TestClient) -> None:
    assert client.get("/v1/me").status_code == 401


def test_onboarding_happy_path(client: TestClient) -> None:
    """
    Satisfies: REQ-001, REQ-002, REQ-003
    Acceptance criteria: AC1–AC5
    Spec version: 1.0
    """
    created = client.post(
        "/v1/households",
        json={"name": "Casa Test", "photo_url": None},
        headers=_auth(),
    )
    assert created.status_code == 201
    household = created.json()
    household_id = household["id"]
    assert household["name"] == "Casa Test"
    assert household["owner_uid"] == "owner-1"

    addressed = client.put(
        f"/v1/households/{household_id}/address",
        json={
            "address": "123 Peachtree St, Atlanta, GA",
            "latitude": 33.75,
            "longitude": -84.39,
        },
        headers=_auth(),
    )
    assert addressed.status_code == 200
    assert addressed.json()["address"].startswith("123 Peachtree")

    nearby = client.get(
        f"/v1/households/{household_id}/stores/nearby",
        headers=_auth(),
    )
    assert nearby.status_code == 200
    stores = nearby.json()["stores"]
    assert len(stores) >= 3
    store_ids = [store["id"] for store in stores[:2]]

    selected = client.put(
        f"/v1/households/{household_id}/stores",
        json={"store_ids": store_ids},
        headers=_auth(),
    )
    assert selected.status_code == 200
    assert selected.json()["store_ids"] == store_ids

    current = client.get("/v1/households/current", headers=_auth())
    assert current.status_code == 200
    assert current.json()["id"] == household_id


def test_household_forbidden_for_other_user(client: TestClient) -> None:
    created = client.post("/v1/households", json={"name": "Mine"}, headers=_auth("a"))
    household_id = created.json()["id"]
    response = client.put(
        f"/v1/households/{household_id}/address",
        json={"address": "Nope"},
        headers=_auth("b"),
    )
    assert response.status_code == 403
