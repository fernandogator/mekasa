"""Firestore-backed shopping list repository."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from google.cloud import firestore

from app.config import Settings
from app.inventory_repository import InventoryRepository
from app.models import (
    ShoppingListItemCreateRequest,
    ShoppingListItemResponse,
    ShoppingListItemUpdateRequest,
)
from app.repository import HouseholdRepository

HOUSEHOLDS = "households"
SHOPPING = "shopping_list_items"


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
        self._require_owner(household_id, owner_uid)
        items = [
            _to_item(household_id, snap.id, snap.to_dict() or {})
            for snap in self._col(household_id).stream()
        ]
        return sorted(items, key=lambda item: item.updated_at, reverse=True)

    def get(
        self, household_id: str, item_id: str, owner_uid: str
    ) -> ShoppingListItemResponse | None:
        self._require_owner(household_id, owner_uid)
        snap = self._col(household_id).document(item_id).get()
        if not snap.exists:
            return None
        return _to_item(household_id, snap.id, snap.to_dict() or {})

    def create(
        self, household_id: str, owner_uid: str, payload: ShoppingListItemCreateRequest
    ) -> ShoppingListItemResponse:
        self._require_owner(household_id, owner_uid)
        if not payload.needs_approval and not payload.is_checked:
            existing = self._find_open(
                household_id, owner_uid, payload.name, payload.inventory_item_id
            )
            if existing is not None:
                updates: dict[str, Any] = {
                    "quantity": existing.quantity + payload.quantity,
                    "updated_by_uid": owner_uid,
                    "updated_at": _utcnow(),
                }
                if payload.quantity_label is not None:
                    updates["quantity_label"] = payload.quantity_label
                if payload.inventory_item_id:
                    updates["inventory_item_id"] = payload.inventory_item_id
                self._col(household_id).document(existing.id).update(updates)
                return existing.model_copy(update=updates)

        item_id = str(uuid4())
        now = _utcnow()
        data = {
            "name": payload.name.strip(),
            "quantity": payload.quantity,
            "quantity_label": payload.quantity_label,
            "is_checked": payload.is_checked,
            "needs_approval": payload.needs_approval,
            "requested_by": payload.requested_by,
            "inventory_item_id": payload.inventory_item_id,
            "kind": payload.kind,
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
        self._require_owner(household_id, owner_uid)
        item = self.get(household_id, item_id, owner_uid)
        if item is None:
            raise KeyError(item_id)
        data = payload.model_dump(exclude_unset=True)
        if "name" in data and data["name"] is not None:
            data["name"] = data["name"].strip()
        data["updated_by_uid"] = owner_uid
        data["updated_at"] = _utcnow()
        self._col(household_id).document(item_id).update(data)
        return item.model_copy(update=data)

    def delete(self, household_id: str, item_id: str, owner_uid: str) -> None:
        self._require_owner(household_id, owner_uid)
        ref = self._col(household_id).document(item_id)
        if not ref.get().exists:
            raise KeyError(item_id)
        ref.delete()

    def approve(
        self, household_id: str, item_id: str, owner_uid: str
    ) -> ShoppingListItemResponse:
        return self.update(
            household_id,
            item_id,
            owner_uid,
            ShoppingListItemUpdateRequest(needs_approval=False, kind="custom"),
        )

    def reject(self, household_id: str, item_id: str, owner_uid: str) -> None:
        self.delete(household_id, item_id, owner_uid)

    def sync_from_inventory(
        self, household_id: str, owner_uid: str, inventory: InventoryRepository
    ) -> tuple[list[ShoppingListItemResponse], list[ShoppingListItemResponse]]:
        self._require_owner(household_id, owner_uid)
        added: list[ShoppingListItemResponse] = []
        for inv in inventory.list_items(household_id, owner_uid):
            if inv.quantity > inv.low_stock_threshold:
                continue
            needed = max(1, inv.low_stock_threshold - inv.quantity + 1)
            before_ids = {item.id for item in self.list_items(household_id, owner_uid)}
            row = self.create(
                household_id,
                owner_uid,
                ShoppingListItemCreateRequest(
                    name=inv.name,
                    quantity=needed,
                    inventory_item_id=inv.id,
                    kind="auto",
                ),
            )
            if row.id not in before_ids:
                added.append(row)
        return added, self.list_items(household_id, owner_uid)

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

    def _require_owner(self, household_id: str, owner_uid: str) -> None:
        household = self._households.get(household_id)
        if household is None:
            raise KeyError(household_id)
        if household.owner_uid != owner_uid:
            raise PermissionError(household_id)
