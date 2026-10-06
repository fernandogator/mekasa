"""
Find and merge duplicate inventory items.

Satisfies: REQ-INV-021 (Find and Merge Duplicate Items)
Acceptance criteria: AC1, AC2, AC3, AC4
Spec version: 1.0
"""

import io
import os
from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient
from PIL import Image

os.environ["ALLOW_TEST_AUTH"] = "true"
os.environ["ENVIRONMENT"] = "test"
os.environ["HOUSEHOLD_PERSISTENCE"] = "memory"

from app.category_icons import category_placeholder_url  # noqa: E402
from app.inventory_dedupe import dedupe_name, find_groups, merge_updates, pick_survivor  # noqa: E402
from app.models import InventoryItemResponse, ProductHealth  # noqa: E402

T0 = datetime(2026, 10, 1, 12, 0, tzinfo=timezone.utc)


def _row(item_id: str, name: str, *, minutes: int = 0, **kw) -> InventoryItemResponse:
    fields = {
        "id": item_id,
        "household_id": "hh",
        "name": name,
        "category": "Produce",
        "quantity": 1,
        "low_stock_threshold": 1,
        "source": "manual",
        "created_by_uid": "u",
        "updated_by_uid": "u",
        "created_at": T0,
        "updated_at": T0 + timedelta(minutes=minutes),
    }
    fields.update(kw)
    return InventoryItemResponse(**fields)


# ----------------------------------------------------------------- pure rules


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("Bananas", "banana"),
        ("  ORGANIC   Bananas! ", "organic banana"),
        ("Berries", "berry"),
        ("Boxes", "box"),
        ("Peaches", "peach"),
        ("Tomatoes", "tomato"),
        ("Jalapeño Chips", "jalapeno chip"),
        ("Hummus", "hummus"),
        ("Swiss Cheese", "swiss cheese"),
        ("Gas", "gas"),
    ],
)
def test_dedupe_name_ignores_case_accents_punctuation_and_simple_plurals(raw: str, expected: str) -> None:
    """AC1."""
    assert dedupe_name(raw) == expected


def test_groups_by_barcode_product_and_name_within_category() -> None:
    """AC1: each rule groups; a different category with the same name does not."""
    items = [
        _row("a", "Oat Milk", category="Dairy", barcode="0123"),
        _row("b", "Oatly Oat Drink", category="Dairy", barcode="0123"),
        _row("c", "Mango salsa", category="Pantry", product_id="llm:x"),
        _row("d", "Salsa mango", category="Pantry", product_id="llm:x"),
        _row("e", "Banana"),
        _row("f", "Bananas"),
        _row("g", "Bananas", category="Frozen"),
        _row("h", "Apples"),
    ]
    groups = {group.reason: sorted(i.id for i in group.items) for group in find_groups(items)}
    assert groups == {"same_barcode": ["a", "b"], "same_product": ["c", "d"], "same_name": ["e", "f"]}


def test_chained_links_form_one_group_with_the_strongest_reason() -> None:
    """AC1: a–b share a barcode, b–c share a name, so a, b, c are one group (same_barcode)."""
    items = [
        _row("a", "Diet Coke 12pk", category="Beverages", barcode="049000028911"),
        _row("b", "Diet Coke", category="Beverages", barcode="049000028911"),
        _row("c", "Diet Cokes", category="Beverages"),
    ]
    [group] = find_groups(items)
    assert group.reason == "same_barcode"
    assert sorted(i.id for i in group.items) == ["a", "b", "c"]


def test_deleted_items_are_ignored() -> None:
    """AC1: soft-deleted rows are not candidates."""
    items = [_row("a", "Banana"), _row("b", "Bananas", deleted=True)]
    assert find_groups(items) == []


def test_survivor_is_the_newest_real_picture() -> None:
    """AC2: newest picture wins even when another row was updated later."""
    old_photo = _row("a", "Banana", minutes=50, image_url="https://cdn/a.jpg", image_updated_at=T0)
    new_photo = _row("b", "Bananas", minutes=5, image_url="https://cdn/b.jpg", image_updated_at=T0 + timedelta(minutes=5))
    assert pick_survivor([old_photo, new_photo]).id == "b"


def test_real_picture_beats_placeholder_and_missing() -> None:
    """AC2: a placeholder or no picture never wins over a real one."""
    placeholder = _row(
        "a", "Banana", minutes=90, image_url=category_placeholder_url("Produce"), image_updated_at=T0 + timedelta(minutes=90)
    )
    none = _row("b", "Bananas", minutes=80)
    real = _row("c", "Banana", minutes=1, image_url="https://cdn/c.jpg")
    assert pick_survivor([placeholder, none, real]).id == "c"


def test_without_pictures_the_most_recently_updated_survives() -> None:
    """AC2."""
    assert pick_survivor([_row("a", "Banana", minutes=1), _row("b", "Bananas", minutes=9)]).id == "b"


def test_missing_image_time_falls_back_to_updated_at() -> None:
    """AC2: rows saved before image_updated_at existed use updated_at."""
    legacy = _row("a", "Banana", minutes=30, image_url="https://cdn/a.jpg")
    tracked = _row("b", "Bananas", minutes=40, image_url="https://cdn/b.jpg", image_updated_at=T0 + timedelta(minutes=10))
    assert pick_survivor([legacy, tracked]).id == "a"


def test_merge_keeps_higher_values_and_fills_gaps() -> None:
    """AC3: max quantity and threshold (no sum); empty fields filled from the newest other row."""
    health = ProductHealth(nutriscore="B")
    survivor = _row("a", "Banana", quantity=2, low_stock_threshold=1, image_url="https://cdn/a.jpg")
    older = _row("b", "Bananas", minutes=1, quantity=3, low_stock_threshold=1, barcode="111", price_paid=0.5)
    newer = _row("c", "Banana", minutes=9, quantity=1, low_stock_threshold=4, price_paid=0.79, health=health)
    updates = merge_updates(survivor, [older, newer])
    assert updates == {
        "quantity": 3,
        "low_stock_threshold": 4,
        "barcode": "111",
        "price_paid": 0.79,
        "health": health,
    }


def test_merge_does_not_overwrite_survivor_fields() -> None:
    """AC3: survivor keeps its own barcode / product / price."""
    survivor = _row("a", "Banana", barcode="222", product_id="plu:4011", price_paid=1.0)
    other = _row("b", "Bananas", minutes=5, barcode="111", product_id="plu:4011", price_paid=2.0)
    assert merge_updates(survivor, [other]) == {"quantity": 1, "low_stock_threshold": 1}


# ----------------------------------------------------------------------- API


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ALLOW_TEST_AUTH", "true")
    monkeypatch.setenv("HOUSEHOLD_PERSISTENCE", "memory")
    monkeypatch.delenv("ITEM_PHOTO_BUCKET", raising=False)
    from app.config import get_settings
    from app.inventory_repository import reset_inventory_repository
    from app.item_photos import reset_item_photo_service
    from app.repository import reset_household_repository
    from app.shopping_list_repository import reset_shopping_list_repository

    def reset() -> None:
        get_settings.cache_clear()
        reset_household_repository()
        reset_inventory_repository()
        reset_shopping_list_repository()
        reset_item_photo_service()

    reset()
    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client
    reset()


def _auth(uid: str = "owner-1") -> dict[str, str]:
    return {"Authorization": f"Bearer test:{uid}"}


def _household(client: TestClient) -> str:
    created = client.post("/v1/households", json={"name": "Casa Dupes"}, headers=_auth())
    assert created.status_code == 201
    return created.json()["id"]


def _create(client: TestClient, hh: str, name: str, **kw) -> dict:
    body = {"name": name, "category": "Produce", "quantity": 1, **kw}
    response = client.post(f"/v1/households/{hh}/inventory", json=body, headers=_auth())
    assert response.status_code == 201, response.text
    return response.json()


def _patch(client: TestClient, hh: str, item_id: str, **body) -> dict:
    response = client.patch(f"/v1/households/{hh}/inventory/{item_id}", json=body, headers=_auth())
    assert response.status_code == 200, response.text
    return response.json()


def _photo(client: TestClient, hh: str) -> str:
    out = io.BytesIO()
    Image.new("RGB", (64, 64), (10, 120, 40)).save(out, format="JPEG")
    response = client.post(
        f"/v1/households/{hh}/item-photos",
        files={"file": ("item.jpg", out.getvalue(), "image/jpeg")},
        headers=_auth(),
    )
    assert response.status_code == 201, response.text
    return response.json()["url"]


def test_image_updated_at_is_set_when_the_picture_changes(client: TestClient) -> None:
    """AC2: create with a picture and PATCH image_url both stamp image_updated_at."""
    hh = _household(client)
    plain = _create(client, hh, "Kale")
    assert plain["image_updated_at"] is None
    with_image = _create(client, hh, "Leeks", image_url="https://cdn/leeks.jpg")
    assert with_image["image_updated_at"] is not None

    patched = _patch(client, hh, plain["id"], image_url="https://cdn/kale.jpg")
    assert patched["image_updated_at"] is not None
    unchanged = _patch(client, hh, plain["id"], quantity=4)
    assert unchanged["image_updated_at"] == patched["image_updated_at"]


def test_duplicates_lists_groups_with_the_survivor(client: TestClient) -> None:
    """AC1, AC2: Banana / Bananas group; the newer picture is kept. The route is not shadowed by /{item_id}."""
    hh = _household(client)
    banana = _create(client, hh, "Banana", quantity=3)
    bananas = _create(client, hh, "Bananas")
    _create(client, hh, "Apples")
    _patch(client, hh, bananas["id"], image_url="https://cdn/bananas.jpg")

    response = client.get(f"/v1/households/{hh}/inventory/duplicates", headers=_auth())
    assert response.status_code == 200, response.text
    [group] = response.json()["groups"]
    assert group["reason"] == "same_name"
    assert group["keep_id"] == bananas["id"]
    assert {item["id"] for item in group["items"]} == {banana["id"], bananas["id"]}


def test_duplicates_requires_membership(client: TestClient) -> None:
    hh = _household(client)
    response = client.get(f"/v1/households/{hh}/inventory/duplicates", headers=_auth("stranger"))
    assert response.status_code in (403, 404)


def test_merge_keeps_newest_photo_higher_values_and_relinks_the_list(client: TestClient) -> None:
    """AC3: survivor keeps its id and photo; qty and threshold are the max; the list row follows."""
    hh = _household(client)
    milk = _create(client, hh, "Oat Milk", category="Dairy", quantity=3, low_stock_threshold=1, price_paid=4.29)
    drink = _create(client, hh, "Oatly Oat Drink", category="Dairy", quantity=1, low_stock_threshold=2)
    _patch(client, hh, milk["id"], barcode="7394376616037")
    _patch(client, hh, drink["id"], barcode="7394376616037", image_url="https://cdn/oatly.jpg")
    row = client.post(
        f"/v1/households/{hh}/shopping-list",
        json={"name": "Oat Milk", "inventory_item_id": milk["id"]},
        headers=_auth(),
    ).json()

    response = client.post(
        f"/v1/households/{hh}/inventory/merge", json={"item_ids": [milk["id"], drink["id"]]}, headers=_auth()
    )
    assert response.status_code == 200, response.text
    body = response.json()
    merged = body["item"]
    assert merged["id"] == drink["id"]
    assert merged["name"] == "Oatly Oat Drink"
    assert merged["image_url"] == "https://cdn/oatly.jpg"
    assert merged["quantity"] == 3
    assert merged["low_stock_threshold"] == 2
    assert merged["price_paid"] == 4.29
    assert body["removed_ids"] == [milk["id"]]
    assert [r["id"] for r in body["shopping_list_items"]] == [row["id"]]
    assert body["shopping_list_items"][0]["inventory_item_id"] == drink["id"]

    listed = client.get(f"/v1/households/{hh}/inventory", headers=_auth()).json()["items"]
    assert [item["id"] for item in listed] == [drink["id"]]
    restore = client.post(f"/v1/households/{hh}/inventory/{milk['id']}/restore", headers=_auth())
    assert restore.status_code == 404
    assert client.get(f"/v1/households/{hh}/inventory/duplicates", headers=_auth()).json()["groups"] == []


def test_merge_deletes_a_private_photo_only_the_removed_item_used(client: TestClient) -> None:
    """AC3: the loser's household photo is deleted; the survivor's stays."""
    hh = _household(client)
    first = _create(client, hh, "Banana")
    old_url = _photo(client, hh)
    _patch(client, hh, first["id"], image_url=old_url)
    second = _create(client, hh, "Bananas")
    new_url = _photo(client, hh)
    _patch(client, hh, second["id"], image_url=new_url)

    response = client.post(
        f"/v1/households/{hh}/inventory/merge", json={"item_ids": [first["id"], second["id"]]}, headers=_auth()
    )
    assert response.status_code == 200, response.text
    assert response.json()["item"]["image_url"] == new_url
    assert client.get(old_url, headers=_auth()).status_code == 404
    assert client.get(new_url, headers=_auth()).status_code == 200


def test_merge_rejects_items_that_are_not_one_group(client: TestClient) -> None:
    """AC4: 409 not_duplicates and nothing changes."""
    hh = _household(client)
    banana = _create(client, hh, "Banana", quantity=2)
    apples = _create(client, hh, "Apples", quantity=5)

    response = client.post(
        f"/v1/households/{hh}/inventory/merge", json={"item_ids": [banana["id"], apples["id"]]}, headers=_auth()
    )
    assert response.status_code == 409
    assert response.json()["detail"] == "not_duplicates"
    listed = client.get(f"/v1/households/{hh}/inventory", headers=_auth()).json()["items"]
    assert sorted((i["name"], i["quantity"]) for i in listed) == [("Apples", 5), ("Banana", 2)]


def test_merge_rejects_unknown_or_deleted_ids(client: TestClient) -> None:
    """AC4: 404 not_found for unknown and soft-deleted ids; one id alone is 409."""
    hh = _household(client)
    banana = _create(client, hh, "Banana")
    bananas = _create(client, hh, "Bananas")
    url = f"/v1/households/{hh}/inventory/merge"

    unknown = client.post(url, json={"item_ids": [banana["id"], "nope"]}, headers=_auth())
    assert unknown.status_code == 404
    assert unknown.json()["detail"] == "not_found"

    client.delete(f"/v1/households/{hh}/inventory/{bananas['id']}", headers=_auth())
    deleted = client.post(url, json={"item_ids": [banana["id"], bananas["id"]]}, headers=_auth())
    assert deleted.status_code == 404

    same = client.post(url, json={"item_ids": [banana["id"], banana["id"]]}, headers=_auth())
    assert same.status_code == 409
    too_few = client.post(url, json={"item_ids": [banana["id"]]}, headers=_auth())
    assert too_few.status_code == 422


# ------------------------------------------------------- Firestore repositories


def _snap(item_id: str, data: dict | None):
    from unittest.mock import MagicMock

    snap = MagicMock()
    snap.id = item_id
    snap.exists = data is not None
    snap.to_dict.return_value = data
    return snap


def _doc(name: str, **kw) -> dict:
    return {
        "name": name,
        "category": "Produce",
        "quantity": 1,
        "low_stock_threshold": 1,
        "created_by_uid": "u",
        "updated_by_uid": "u",
        "created_at": T0,
        "updated_at": T0,
        **kw,
    }


def test_firestore_merge_is_one_batch() -> None:
    """AC3: one batch updates the survivor and deletes the others."""
    from unittest.mock import MagicMock, patch

    from app.firestore_inventory_repository import FirestoreInventoryRepository

    client = MagicMock()
    client.get_all.return_value = [
        _snap("keep", _doc("Bananas", image_url="https://cdn/b.jpg")),
        _snap("gone", _doc("Banana", quantity=4)),
    ]
    repo = FirestoreInventoryRepository(client, MagicMock())
    health = ProductHealth(nutriscore="A")
    with patch("app.household_access.assert_household_member"):
        merged = repo.merge("h1", "u2", keep_id="keep", remove_ids=["gone"], updates={"quantity": 4, "health": health})

    batch = client.batch.return_value
    batch.update.assert_called_once()
    written = batch.update.call_args.args[1]
    assert written["quantity"] == 4
    assert written["health"]["nutriscore"] == "A"
    assert written["updated_by_uid"] == "u2"
    batch.delete.assert_called_once()
    batch.commit.assert_called_once()
    assert merged.id == "keep" and merged.quantity == 4 and merged.image_url == "https://cdn/b.jpg"
    assert merged.health == health


def test_firestore_merge_rejects_a_deleted_item_without_writing() -> None:
    """AC4."""
    from unittest.mock import MagicMock, patch

    from app.firestore_inventory_repository import FirestoreInventoryRepository

    client = MagicMock()
    client.get_all.return_value = [_snap("keep", _doc("Bananas")), _snap("gone", _doc("Banana", deleted=True))]
    repo = FirestoreInventoryRepository(client, MagicMock())
    with patch("app.household_access.assert_household_member"), pytest.raises(KeyError):
        repo.merge("h1", "u", keep_id="keep", remove_ids=["gone"], updates={})
    client.batch.assert_not_called()


def test_firestore_relink_reads_once_and_batches() -> None:
    """AC3: list rows of removed items point at the survivor."""
    from unittest.mock import MagicMock, patch

    from app.firestore_shopping_list_repository import FirestoreShoppingListRepository

    client = MagicMock()
    collection = client.collection.return_value.document.return_value.collection.return_value
    row = {
        "name": "Banana",
        "quantity": 1,
        "kind": "custom",
        "inventory_item_id": "gone",
        "created_by_uid": "u",
        "updated_by_uid": "u",
        "created_at": T0,
        "updated_at": T0,
    }
    collection.stream.return_value = [_snap("r1", row), _snap("r2", {**row, "inventory_item_id": "other"})]
    repo = FirestoreShoppingListRepository(client, MagicMock())
    with patch("app.household_access.assert_household_member"):
        changed = repo.relink_inventory("h1", "u", ["gone"], "keep")

    assert [(r.id, r.inventory_item_id) for r in changed] == [("r1", "keep")]
    batch = client.batch.return_value
    batch.update.assert_called_once()
    batch.commit.assert_called_once()
