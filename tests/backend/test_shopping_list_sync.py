"""
Low-stock sync reads the list once, writes once, and is idempotent.

Satisfies: REQ-011 (Automatic Shopping List Addition) AC1, AC2; NFR-003
Spec version: 1.0
"""

import os
import re
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

os.environ["ALLOW_TEST_AUTH"] = "true"
os.environ["ENVIRONMENT"] = "test"
os.environ["HOUSEHOLD_PERSISTENCE"] = "memory"

APP = Path(__file__).resolve().parents[2] / "backend" / "app"
NOW = datetime(2026, 10, 6, tzinfo=timezone.utc)


def _inv(item_id: str, name: str, quantity: int = 1, threshold: int = 1):
    from app.models import InventoryItemResponse

    return InventoryItemResponse(
        id=item_id, household_id="h1", name=name, category="Dairy", quantity=quantity,
        low_stock_threshold=threshold, source="manual", created_by_uid="u", updated_by_uid="u",
        created_at=NOW, updated_at=NOW,
    )


def _row(row_id: str, name: str, inventory_item_id: str | None = None, **fields):
    from app.models import ShoppingListItemResponse

    return ShoppingListItemResponse(
        id=row_id, household_id="h1", name=name, quantity=fields.pop("quantity", 1),
        inventory_item_id=inventory_item_id, kind=fields.pop("kind", "custom"), created_by_uid="u",
        updated_by_uid="u", created_at=NOW, updated_at=NOW, **fields,
    )


# --- planning -------------------------------------------------------------------


def test_plan_creates_one_row_per_low_item() -> None:
    from app.shopping_list_repository import plan_low_stock_rows

    creates, links = plan_low_stock_rows(
        [_inv("i1", "Milk"), _inv("i2", "Eggs", quantity=5), _inv("i3", "Bread", quantity=0, threshold=2)],
        [],
        actor_is_owner=True,
    )
    assert [(c.name, c.quantity, c.inventory_item_id, c.kind, c.needs_approval) for c in creates] == [
        ("Milk", 1, "i1", "auto", False),
        ("Bread", 3, "i3", "auto", False),
    ]
    assert links == []


def test_plan_skips_items_already_on_the_list() -> None:
    from app.shopping_list_repository import plan_low_stock_rows

    current = [
        _row("r1", "Milk", "i1", quantity=4),
        _row("r2", "bread"),
        _row("r3", "Eggs", "i9", needs_approval=True, kind="request"),
        _row("r4", "Butter", "i4", is_checked=True),
    ]
    creates, links = plan_low_stock_rows(
        [_inv("i1", "Milk"), _inv("i2", "Bread"), _inv("i9", "Eggs"), _inv("i4", "Butter")],
        current,
        actor_is_owner=True,
    )
    assert [c.name for c in creates] == ["Butter"]
    assert links == [("r2", "i2")]


def test_plan_dedupes_same_name_within_one_sync() -> None:
    from app.shopping_list_repository import plan_low_stock_rows

    creates, _ = plan_low_stock_rows([_inv("i1", "Milk"), _inv("i2", " milk ")], [], actor_is_owner=True)
    assert len(creates) == 1


def test_plan_member_rows_need_approval() -> None:
    from app.shopping_list_repository import plan_low_stock_rows

    [create], _ = plan_low_stock_rows([_inv("i1", "Milk")], [], actor_is_owner=False)
    assert (create.needs_approval, create.kind, create.requested_by) == (True, "request", "Member")


# --- Firestore repository: one read, one batch ------------------------------------


def test_firestore_sync_reads_once_and_batches_writes() -> None:
    from app.firestore_retry import STREAM_RETRY
    from app.firestore_shopping_list_repository import FirestoreShoppingListRepository

    client = MagicMock()
    collection = client.collection.return_value.document.return_value.collection.return_value
    collection.stream.return_value = []
    inventory = MagicMock()
    inventory.list_items.return_value = [_inv(f"i{n}", f"Item {n}") for n in range(40)]

    repo = FirestoreShoppingListRepository(client, MagicMock())
    with patch("app.household_access.assert_household_member"), patch(
        "app.firestore_shopping_list_repository.actor_is_owner", return_value=True
    ):
        added, items = repo.sync_from_inventory("h1", "u", inventory)

    assert len(added) == 40 and len(items) == 40
    collection.stream.assert_called_once_with(retry=STREAM_RETRY)
    batch = client.batch.return_value
    assert batch.set.call_count == 40
    batch.commit.assert_called_once()


def test_firestore_sync_without_changes_writes_nothing() -> None:
    from app.firestore_shopping_list_repository import FirestoreShoppingListRepository

    client = MagicMock()
    inventory = MagicMock()
    inventory.list_items.return_value = [_inv("i1", "Milk", quantity=9)]
    repo = FirestoreShoppingListRepository(client, MagicMock())
    with patch("app.household_access.assert_household_member"), patch(
        "app.firestore_shopping_list_repository.actor_is_owner", return_value=True
    ):
        added, _ = repo.sync_from_inventory("h1", "u", inventory)
    assert added == []
    client.batch.assert_not_called()


# --- Firestore stream retry workaround ------------------------------------------


def test_every_firestore_stream_passes_an_explicit_retry() -> None:
    bare = [
        f"{path.name}:{n}"
        for path in APP.glob("*.py")
        if path.name != "firestore_retry.py"
        for n, line in enumerate(path.read_text().splitlines(), 1)
        if re.search(r"\.stream\(\s*\)", line)
    ]
    assert bare == []


def test_explicit_retry_avoids_the_library_crash() -> None:
    """The library's DEFAULT path reads `transport.run_query._retry`, which raw gRPC callables lack."""
    from google.api_core import exceptions
    from google.auth.credentials import AnonymousCredentials
    from google.cloud import firestore

    from app.firestore_retry import STREAM_RETRY

    query = firestore.Client(project="test", credentials=AnonymousCredentials()).collection("x")._query()
    assert query._retry_query_after_exception(exceptions.ServiceUnavailable("x"), STREAM_RETRY, None) is True
    assert query._retry_query_after_exception(exceptions.PermissionDenied("x"), STREAM_RETRY, None) is False


# --- API (in-memory) ---------------------------------------------------------------


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ALLOW_TEST_AUTH", "true")
    monkeypatch.setenv("HOUSEHOLD_PERSISTENCE", "memory")
    from app.config import get_settings
    from app.inventory_repository import reset_inventory_repository
    from app.repository import reset_household_repository
    from app.shopping_list_repository import reset_shopping_list_repository

    get_settings.cache_clear()
    reset_household_repository()
    reset_inventory_repository()
    reset_shopping_list_repository()
    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client
    reset_shopping_list_repository()


def test_repeated_sync_does_not_grow_quantities(client: TestClient) -> None:
    auth = {"Authorization": "Bearer test:owner-1"}
    hid = client.post("/v1/households", json={"name": "Casa"}, headers=auth).json()["id"]
    for n in range(40):
        created = client.post(
            f"/v1/households/{hid}/inventory",
            json={"name": f"Item {n}", "category": "Dairy", "quantity": 1, "low_stock_threshold": 1, "source": "manual"},
            headers=auth,
        )
        assert created.status_code == 201

    first = client.post(f"/v1/households/{hid}/shopping-list/sync-from-inventory", headers=auth).json()
    second = client.post(f"/v1/households/{hid}/shopping-list/sync-from-inventory", headers=auth).json()

    assert len(first["added"]) == 40
    assert second["added"] == []
    assert len(second["items"]) == 40
    assert {item["quantity"] for item in second["items"]} == {1}
