"""Firestore-backed shopping list repository."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from google.cloud import firestore

from app.config import Settings
from app.firestore_retry import STREAM_RETRY
from app.inventory_repository import InventoryRepository
from app.models import (
    ShoppingListItemCreateRequest,
    ShoppingListItemResponse,
    ShoppingListItemUpdateRequest,
)
from app.repository import HouseholdRepository
from app.shopping_list_repository import actor_is_owner, as_member_request, plan_low_stock_rows

HOUSEHOLDS = "households"
SHOPPING = "shopping_list_items"
# Firestore allows at most 500 writes per batch.
_BATCH_LIMIT = 400


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _norm(value: str) -> str:
    return value.strip().casefold()


def _to_item(household_id: str, doc_id: str, data: dict[str, Any]) -> ShoppingListItemResponse:
    return ShoppingListItemResponse(
        id=doc_id,
        household_id=household_id,
        name=str(data["name"]),
        quantity=int(data.get("quantity") or 1),
        quantity_label=data.get("quantity_label"),
        is_checked=bool(data.get("is_checked") or False),
        needs_approval=bool(data.get("needs_approval") or False),
        requested_by=data.get("requested_by"),
        inventory_item_id=data.get("inventory_item_id"),
        kind=data.get("kind") or "custom",
        created_by_uid=str(data["created_by_uid"]),
        updated_by_uid=str(data["updated_by_uid"]),
        created_at=data["created_at"],
        updated_at=data["updated_at"],
    )


class FirestoreShoppingListRepository:
    """
    Satisfies: REQ-011–REQ-014 (persistence slice)
    Spec version: 1.0

    Path: households/{household_id}/shopping_list_items/{item_id}
    """

    def __init__(self, client: firestore.Client, households: HouseholdRepository) -> None:
        self._db = client
        self._households = households

    @classmethod
    def from_settings(
        cls, settings: Settings, households: HouseholdRepository
    ) -> FirestoreShoppingListRepository:
        project_id = settings.firebase_project_id or settings.gcp_project_id
        if not project_id:
            raise RuntimeError(
                "GCP_PROJECT_ID or FIREBASE_PROJECT_ID is required for Firestore"
            )
        client = firestore.Client(
            project=project_id,
            database=settings.firestore_database_id,
        )
        return cls(client, households)

    def _col(self, household_id: str):
        return self._db.collection(HOUSEHOLDS).document(household_id).collection(SHOPPING)

    def list_items(self, household_id: str, owner_uid: str) -> list[ShoppingListItemResponse]:
        self._require_member(household_id, owner_uid)
        items = [
            _to_item(household_id, snap.id, snap.to_dict() or {})
            for snap in self._col(household_id).stream(retry=STREAM_RETRY)
        ]
        return sorted(items, key=lambda item: item.updated_at, reverse=True)

    def get(
        self, household_id: str, item_id: str, owner_uid: str
    ) -> ShoppingListItemResponse | None:
        self._require_member(household_id, owner_uid)
        snap = self._col(household_id).document(item_id).get()
        if not snap.exists:
            return None
        return _to_item(household_id, snap.id, snap.to_dict() or {})

    def create(
        self, household_id: str, owner_uid: str, payload: ShoppingListItemCreateRequest
    ) -> ShoppingListItemResponse:
        self._require_member(household_id, owner_uid)
        create_payload = self._member_create_payload(household_id, owner_uid, payload)
        if not create_payload.needs_approval and not create_payload.is_checked:
            existing = self._find_open(
                household_id, owner_uid, create_payload.name, create_payload.inventory_item_id
            )
            if existing is not None:
                updates: dict[str, Any] = {
                    "quantity": existing.quantity + create_payload.quantity,
                    "updated_by_uid": owner_uid,
                    "updated_at": _utcnow(),
                }
                if create_payload.quantity_label is not None:
                    updates["quantity_label"] = create_payload.quantity_label
                if create_payload.inventory_item_id:
                    updates["inventory_item_id"] = create_payload.inventory_item_id
                self._col(household_id).document(existing.id).update(updates)
                return existing.model_copy(update=updates)

        item_id = str(uuid4())
        now = _utcnow()
        data = {
            "name": create_payload.name.strip(),
            "quantity": create_payload.quantity,
            "quantity_label": create_payload.quantity_label,
            "is_checked": create_payload.is_checked,
            "needs_approval": create_payload.needs_approval,
            "requested_by": create_payload.requested_by,
            "inventory_item_id": create_payload.inventory_item_id,
            "kind": create_payload.kind,
            "created_by_uid": owner_uid,
            "updated_by_uid": owner_uid,
            "created_at": now,
            "updated_at": now,
        }
        self._col(household_id).document(item_id).set(data)
        return _to_item(household_id, item_id, data)

    def update(
        self,
        household_id: str,
        item_id: str,
        owner_uid: str,
        payload: ShoppingListItemUpdateRequest,
    ) -> ShoppingListItemResponse:
        self._require_member(household_id, owner_uid)
        data = payload.model_dump(exclude_unset=True)
        if "is_checked" in data:
            from app.household_access import assert_can_mark_purchased

            assert_can_mark_purchased(household_id, owner_uid)
        item = self.get(household_id, item_id, owner_uid)
        if item is None:
            raise KeyError(item_id)
        if "name" in data and data["name"] is not None:
            data["name"] = data["name"].strip()
        data["updated_by_uid"] = owner_uid
        data["updated_at"] = _utcnow()
        self._col(household_id).document(item_id).update(data)
        return item.model_copy(update=data)

    def delete(self, household_id: str, item_id: str, owner_uid: str) -> None:
        self._require_member(household_id, owner_uid)
        ref = self._col(household_id).document(item_id)
        if not ref.get().exists:
            raise KeyError(item_id)
        ref.delete()

    def approve(
        self, household_id: str, item_id: str, owner_uid: str
    ) -> ShoppingListItemResponse:
        from app.household_access import assert_household_owner

        assert_household_owner(household_id, owner_uid)
        return self.update(
            household_id,
            item_id,
            owner_uid,
            ShoppingListItemUpdateRequest(needs_approval=False, kind="custom"),
        )

    def reject(self, household_id: str, item_id: str, owner_uid: str) -> None:
        from app.household_access import assert_household_owner

        assert_household_owner(household_id, owner_uid)
        self.delete(household_id, item_id, owner_uid)

    def sync_from_inventory(
        self, household_id: str, owner_uid: str, inventory: InventoryRepository
    ) -> tuple[list[ShoppingListItemResponse], list[ShoppingListItemResponse]]:
        """
        Satisfies: REQ-011 AC1, AC2
        Spec version: 1.0

        One read of the inventory and of the list, one batched write: the old
        per-item create re-read the whole list twice per low-stock item, which
        on a 40-item haul ran past Firestore's deadline mid-stream.
        """
        self._require_member(household_id, owner_uid)
        inventory_items = inventory.list_items(household_id, owner_uid)
        current = self.list_items(household_id, owner_uid)
        creates, links = plan_low_stock_rows(
            inventory_items, current, actor_is_owner=actor_is_owner(household_id, owner_uid)
        )
        if not creates and not links:
            return [], current

        now = _utcnow()
        writes: list[tuple[Any, dict[str, Any], bool]] = []
        updated = {row.id: row for row in current}
        for row_id, inventory_item_id in links:
            patch = {"inventory_item_id": inventory_item_id, "updated_by_uid": owner_uid, "updated_at": now}
            writes.append((self._col(household_id).document(row_id), patch, False))
            updated[row_id] = updated[row_id].model_copy(update=patch)
        added: list[ShoppingListItemResponse] = []
        for payload in creates:
            item_id = str(uuid4())
            data = {
                "name": payload.name.strip(),
                "quantity": payload.quantity,
                "quantity_label": payload.quantity_label,
                "is_checked": False,
                "needs_approval": payload.needs_approval,
                "requested_by": payload.requested_by,
                "inventory_item_id": payload.inventory_item_id,
                "kind": payload.kind,
                "created_by_uid": owner_uid,
                "updated_by_uid": owner_uid,
                "created_at": now,
                "updated_at": now,
            }
            writes.append((self._col(household_id).document(item_id), data, True))
            added.append(_to_item(household_id, item_id, data))

        for start in range(0, len(writes), _BATCH_LIMIT):
            batch = self._db.batch()
            for ref, data, is_new in writes[start : start + _BATCH_LIMIT]:
                if is_new:
                    batch.set(ref, data)
                else:
                    batch.update(ref, data)
            batch.commit()
        items = sorted([*updated.values(), *added], key=lambda item: item.updated_at, reverse=True)
        return added, items

    def relink_inventory(
        self, household_id: str, actor_uid: str, from_ids: list[str], to_id: str
    ) -> list[ShoppingListItemResponse]:
        """REQ-INV-021 AC3: one read of the list, one batched write."""
        self._require_member(household_id, actor_uid)
        sources = set(from_ids)
        rows = [row for row in self.list_items(household_id, actor_uid) if row.inventory_item_id in sources]
        if not rows:
            return []
        patch = {"inventory_item_id": to_id, "updated_by_uid": actor_uid, "updated_at": _utcnow()}
        for start in range(0, len(rows), _BATCH_LIMIT):
            batch = self._db.batch()
            for row in rows[start : start + _BATCH_LIMIT]:
                batch.update(self._col(household_id).document(row.id), patch)
            batch.commit()
        return [row.model_copy(update=patch) for row in rows]

    def _find_open(
        self,
        household_id: str,
        owner_uid: str,
        name: str,
        inventory_item_id: str | None,
    ) -> ShoppingListItemResponse | None:
        target = _norm(name)
        for item in self.list_items(household_id, owner_uid):
            if item.is_checked or item.needs_approval:
                continue
            if inventory_item_id and item.inventory_item_id == inventory_item_id:
                return item
            if _norm(item.name) == target:
                return item
        return None

    def _require_member(self, household_id: str, owner_uid: str) -> None:
        from app.household_access import assert_household_member

        assert_household_member(household_id, owner_uid)

    @staticmethod
    def _member_create_payload(
        household_id: str,
        actor_uid: str,
        payload: ShoppingListItemCreateRequest,
    ) -> ShoppingListItemCreateRequest:
        return payload if actor_is_owner(household_id, actor_uid) else as_member_request(payload)
