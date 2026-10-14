"""Shopping list per store (REQ-024)."""

import os

import pytest
from fastapi.testclient import TestClient

os.environ["ALLOW_TEST_AUTH"] = "true"
os.environ["ENVIRONMENT"] = "test"
os.environ["HOUSEHOLD_PERSISTENCE"] = "memory"

AUTH = {"Authorization": "Bearer test:owner-1"}


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ALLOW_TEST_AUTH", "true")
    monkeypatch.setenv("HOUSEHOLD_PERSISTENCE", "memory")
    from app.config import get_settings
    from app.repository import reset_household_repository
    from app.shopping_list_repository import reset_shopping_list_repository

    get_settings.cache_clear()
    reset_household_repository()
    reset_shopping_list_repository()
    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client
    get_settings.cache_clear()
    reset_household_repository()
    reset_shopping_list_repository()


@pytest.fixture()
def household(client: TestClient) -> str:
    created = client.post("/v1/households", json={"name": "Casa", "photo_url": None}, headers=AUTH)
    household_id = created.json()["id"]
    saved = client.put(
        f"/v1/households/{household_id}/stores",
        json={
            "store_ids": ["costco", "heb"],
            "stores": [
                {"id": "costco", "name": "Costco", "address": "1 Warehouse", "distance_miles": 4.2},
                {"id": "heb", "name": "H-E-B", "address": "2 Lamar", "distance_miles": 0.8},
            ],
        },
        headers=AUTH,
    )
    assert saved.status_code == 200
    return household_id


def _add(client: TestClient, household_id: str, **body):
    return client.post(f"/v1/households/{household_id}/shopping-list", json=body, headers=AUTH)


def test_rows_keep_their_store(client: TestClient, household: str) -> None:
    """
    Satisfies: REQ-024 AC1
    Spec version: 1.0
    """
    added = _add(client, household, name="Paper towels", store_id="costco")
    assert added.status_code == 201
    assert added.json()["store_id"] == "costco"
    rows = client.get(f"/v1/households/{household}/shopping-list", headers=AUTH).json()["items"]
    assert [(row["name"], row["store_id"]) for row in rows] == [("Paper towels", "costco")]


def test_unknown_store_is_rejected(client: TestClient, household: str) -> None:
    """
    Satisfies: REQ-024 AC1
    Spec version: 1.0
    """
    assert _add(client, household, name="Milk", store_id="kroger").status_code == 422
    row = _add(client, household, name="Milk").json()
    moved = client.patch(f"/v1/households/{household}/shopping-list/{row['id']}", json={"store_id": "kroger"}, headers=AUTH)
    assert moved.status_code == 422


def test_same_item_can_be_on_two_store_lists_and_merges_within_one(client: TestClient, household: str) -> None:
    """
    Satisfies: REQ-024 AC3, REQ-011
    Spec version: 1.0
    """
    costco = _add(client, household, name="Milk", quantity=2, store_id="costco").json()
    heb = _add(client, household, name="milk", quantity=1, store_id="heb").json()
    assert costco["id"] != heb["id"]

    again = _add(client, household, name="Milk", quantity=3, store_id="costco").json()
    assert again["id"] == costco["id"]
    assert again["quantity"] == 5

    anywhere = _add(client, household, name="Milk").json()
    assert anywhere["id"] not in {costco["id"], heb["id"]}
    assert anywhere["store_id"] is None


def test_rows_move_between_lists(client: TestClient, household: str) -> None:
    """
    Satisfies: REQ-024 AC2
    Spec version: 1.0
    """
    row = _add(client, household, name="Eggs").json()
    path = f"/v1/households/{household}/shopping-list/{row['id']}"

    moved = client.patch(path, json={"store_id": "heb"}, headers=AUTH)
    assert moved.status_code == 200
    assert moved.json()["store_id"] == "heb"

    renamed = client.patch(path, json={"name": "Brown eggs"}, headers=AUTH)
    assert renamed.json()["store_id"] == "heb"

    cleared = client.patch(path, json={"store_id": None}, headers=AUTH)
    assert cleared.status_code == 200
    assert cleared.json()["store_id"] is None


def test_clients_without_store_id_keep_working(client: TestClient, household: str) -> None:
    """
    Satisfies: REQ-024 AC6
    Spec version: 1.0
    """
    added = _add(client, household, name="Bananas", quantity=6)
    assert added.status_code == 201
    assert added.json()["store_id"] is None
