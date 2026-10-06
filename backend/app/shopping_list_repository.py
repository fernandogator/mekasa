"""Shopping list repository protocol, in-memory impl, and factory."""

from __future__ import annotations

from datetime import datetime, timezone
from threading import Lock
from typing import Protocol
from uuid import uuid4

from app.config import Settings, get_settings
from app.inventory_repository import InventoryRepository
from app.models import (
    InventoryItemResponse,
    ShoppingListItemCreateRequest,
    ShoppingListItemResponse,
    ShoppingListItemUpdateRequest,
)
from app.repository import HouseholdRepository, get_household_repository, resolve_persistence_mode


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _norm(value: str) -> str:
    return value.strip().casefold()


def as_member_request(payload: ShoppingListItemCreateRequest) -> ShoppingListItemCreateRequest:
    """Non-owners may only add requests (REQ-012 / REQ-014)."""
    if payload.needs_approval and payload.kind == "request":
        return payload
    return payload.model_copy(
        update={
            "needs_approval": True,
            "kind": "request",
            "requested_by": payload.requested_by or "Member",
            "is_checked": False,
        }
    )


def plan_low_stock_rows(
    inventory_items: list[InventoryItemResponse],
    current: list[ShoppingListItemResponse],
    *,
    actor_is_owner: bool,
) -> tuple[list[ShoppingListItemCreateRequest], list[tuple[str, str]]]:
    """
    Satisfies: REQ-011 AC1, AC2
    Spec version: 1.0

    Rows to create for low-stock items, and `(row_id, inventory_item_id)`
    links for unchecked rows that already cover an item by name. An item that
    is already on the list (open or awaiting approval) is left as it is, so
    repeated syncs never grow quantities or duplicate rows.
    """
    unchecked = [row for row in current if not row.is_checked]
    by_item = {row.inventory_item_id: row for row in unchecked if row.inventory_item_id}
    by_name = {_norm(row.name): row for row in unchecked}
    creates: list[ShoppingListItemCreateRequest] = []
    links: list[tuple[str, str]] = []
    planned: set[str] = set()
    for inv in inventory_items:
        if inv.quantity > inv.low_stock_threshold:
            continue
        name = _norm(inv.name)
        if inv.id in by_item or name in planned:
            continue
        existing = by_name.get(name)
        if existing is not None:
            if not existing.inventory_item_id:
                links.append((existing.id, inv.id))
            continue
        payload = ShoppingListItemCreateRequest(
            name=inv.name,
            quantity=max(1, inv.low_stock_threshold - inv.quantity + 1),
            inventory_item_id=inv.id,
            kind="auto",
        )
        creates.append(payload if actor_is_owner else as_member_request(payload))
        planned.add(name)
    return creates, links


def actor_is_owner(household_id: str, actor_uid: str) -> bool:
    from app.household_access import get_household_or_404, is_household_owner

    return is_household_owner(get_household_or_404(household_id), actor_uid)


class ShoppingListRepository(Protocol):
    """Persistence port for household shopping list rows."""

    def list_items(self, household_id: str, owner_uid: str) -> list[ShoppingListItemResponse]:
        """List all shopping list rows."""

    def get(
        self, household_id: str, item_id: str, owner_uid: str
    ) -> ShoppingListItemResponse | None:
        """Get one row."""

    def create(
        self, household_id: str, owner_uid: str, payload: ShoppingListItemCreateRequest
    ) -> ShoppingListItemResponse:
        """Create or merge into an open (unchecked) row with the same name."""

    def update(
        self,
        household_id: str,
        item_id: str,
        owner_uid: str,
        payload: ShoppingListItemUpdateRequest,
    ) -> ShoppingListItemResponse:
        """Patch row fields."""

    def delete(self, household_id: str, item_id: str, owner_uid: str) -> None:
        """Delete row."""

    def approve(
        self, household_id: str, item_id: str, owner_uid: str
    ) -> ShoppingListItemResponse:
        """Clear needs_approval (REQ-013)."""

    def reject(self, household_id: str, item_id: str, owner_uid: str) -> None:
        """Remove a pending request (REQ-013)."""

    def sync_from_inventory(
        self, household_id: str, owner_uid: str, inventory: InventoryRepository
    ) -> tuple[list[ShoppingListItemResponse], list[ShoppingListItemResponse]]:
        """Auto-add low-stock inventory items (REQ-011). Returns (added, all)."""

    def relink_inventory(
        self, household_id: str, actor_uid: str, from_ids: list[str], to_id: str
    ) -> list[ShoppingListItemResponse]:
        """Point rows linked to `from_ids` at `to_id` (REQ-INV-021 AC3). Returns the changed rows."""


class InMemoryShoppingListRepository:
    """
    Satisfies: REQ-011–REQ-014 (persistence slice)
    Spec version: 1.0
    """

    def __init__(self, households: HouseholdRepository) -> None:
        self._households = households
        self._items: dict[str, dict[str, ShoppingListItemResponse]] = {}
        self._lock = Lock()

    def list_items(self, household_id: str, owner_uid: str) -> list[ShoppingListItemResponse]:
        self._require_member(household_id, owner_uid)
        with self._lock:
            items = list(self._items.get(household_id, {}).values())
        return sorted(items, key=lambda item: item.updated_at, reverse=True)

    def get(
        self, household_id: str, item_id: str, owner_uid: str
    ) -> ShoppingListItemResponse | None:
        self._require_member(household_id, owner_uid)
        return self._items.get(household_id, {}).get(item_id)

    def create(
        self, household_id: str, owner_uid: str, payload: ShoppingListItemCreateRequest
    ) -> ShoppingListItemResponse:
        self._require_member(household_id, owner_uid)
        create_payload = self._member_create_payload(household_id, owner_uid, payload)
        with self._lock:
            bucket = self._items.setdefault(household_id, {})
            if not create_payload.needs_approval and not create_payload.is_checked:
                existing = self._find_open(bucket, create_payload.name, create_payload.inventory_item_id)
                if existing is not None:
                    updates = {
                        "quantity": existing.quantity + create_payload.quantity,
                        "updated_by_uid": owner_uid,
                        "updated_at": _utcnow(),
                    }
                    if create_payload.quantity_label is not None:
                        updates["quantity_label"] = create_payload.quantity_label
                    if create_payload.inventory_item_id:
                        updates["inventory_item_id"] = create_payload.inventory_item_id
                    merged = existing.model_copy(update=updates)
                    bucket[existing.id] = merged
                    return merged

            now = _utcnow()
            item = ShoppingListItemResponse(
                id=str(uuid4()),
                household_id=household_id,
                name=create_payload.name.strip(),
                quantity=create_payload.quantity,
                quantity_label=create_payload.quantity_label,
                is_checked=create_payload.is_checked,
                needs_approval=create_payload.needs_approval,
                requested_by=create_payload.requested_by,
                inventory_item_id=create_payload.inventory_item_id,
                kind=create_payload.kind,
                created_by_uid=owner_uid,
                updated_by_uid=owner_uid,
                created_at=now,
                updated_at=now,
            )
            bucket[item.id] = item
            return item

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
        with self._lock:
            item = self._items.get(household_id, {}).get(item_id)
            if item is None:
                raise KeyError(item_id)
            if "name" in data and data["name"] is not None:
                data["name"] = data["name"].strip()
            data["updated_by_uid"] = owner_uid
            data["updated_at"] = _utcnow()
            updated = item.model_copy(update=data)
            self._items[household_id][item_id] = updated
            return updated

    def delete(self, household_id: str, item_id: str, owner_uid: str) -> None:
        self._require_member(household_id, owner_uid)
        with self._lock:
            bucket = self._items.get(household_id, {})
            if item_id not in bucket:
                raise KeyError(item_id)
            del bucket[item_id]

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
        self._require_member(household_id, owner_uid)
        inventory_items = inventory.list_items(household_id, owner_uid)
        is_owner = actor_is_owner(household_id, owner_uid)
        added: list[ShoppingListItemResponse] = []
        with self._lock:
            bucket = self._items.setdefault(household_id, {})
            creates, links = plan_low_stock_rows(inventory_items, list(bucket.values()), actor_is_owner=is_owner)
            now = _utcnow()
            for row_id, inventory_item_id in links:
                bucket[row_id] = bucket[row_id].model_copy(
                    update={"inventory_item_id": inventory_item_id, "updated_by_uid": owner_uid, "updated_at": now}
                )
            for payload in creates:
                item = ShoppingListItemResponse(
                    id=str(uuid4()),
                    household_id=household_id,
                    name=payload.name.strip(),
                    quantity=payload.quantity,
                    quantity_label=payload.quantity_label,
                    is_checked=False,
                    needs_approval=payload.needs_approval,
                    requested_by=payload.requested_by,
                    inventory_item_id=payload.inventory_item_id,
                    kind=payload.kind,
                    created_by_uid=owner_uid,
                    updated_by_uid=owner_uid,
                    created_at=now,
                    updated_at=now,
                )
                bucket[item.id] = item
                added.append(item)
        return added, self.list_items(household_id, owner_uid)

    def relink_inventory(
        self, household_id: str, actor_uid: str, from_ids: list[str], to_id: str
    ) -> list[ShoppingListItemResponse]:
        self._require_member(household_id, actor_uid)
        sources = set(from_ids)
        changed: list[ShoppingListItemResponse] = []
        with self._lock:
            bucket = self._items.get(household_id, {})
            now = _utcnow()
            for row_id, row in list(bucket.items()):
                if row.inventory_item_id in sources:
                    bucket[row_id] = row.model_copy(
                        update={"inventory_item_id": to_id, "updated_by_uid": actor_uid, "updated_at": now}
                    )
                    changed.append(bucket[row_id])
        return changed

    def _require_member(self, household_id: str, owner_uid: str) -> None:
        from app.household_access import assert_household_member

        assert_household_member(household_id, owner_uid)

    @staticmethod
    def _member_create_payload(
        household_id: str,
        actor_uid: str,
        payload: ShoppingListItemCreateRequest,
    ) -> ShoppingListItemCreateRequest:
        """Non-owners may only add requests (REQ-012 / REQ-014)."""
        return payload if actor_is_owner(household_id, actor_uid) else as_member_request(payload)

    @staticmethod
    def _find_open(
        bucket: dict[str, ShoppingListItemResponse],
        name: str,
        inventory_item_id: str | None,
    ) -> ShoppingListItemResponse | None:
        target = _norm(name)
        for item in bucket.values():
            if item.is_checked or item.needs_approval:
                continue
            if inventory_item_id and item.inventory_item_id == inventory_item_id:
                return item
            if _norm(item.name) == target:
                return item
        return None


_shopping_repo: ShoppingListRepository | None = None
_shopping_repo_mode: str | None = None


def get_shopping_list_repository() -> ShoppingListRepository:
    """Process-wide shopping list repository (memory or Firestore)."""
    global _shopping_repo, _shopping_repo_mode
    settings = get_settings()
    mode = resolve_persistence_mode(settings)
    if _shopping_repo is not None and _shopping_repo_mode == mode:
        return _shopping_repo

    households = get_household_repository()
    if mode == "firestore":
        from app.firestore_shopping_list_repository import FirestoreShoppingListRepository

        _shopping_repo = FirestoreShoppingListRepository.from_settings(settings, households)
    else:
        _shopping_repo = InMemoryShoppingListRepository(households)
    _shopping_repo_mode = mode
    return _shopping_repo


def reset_shopping_list_repository() -> None:
    """Reset shopping list repository for tests (forces in-memory)."""
    global _shopping_repo, _shopping_repo_mode
    _shopping_repo = InMemoryShoppingListRepository(get_household_repository())
    _shopping_repo_mode = "memory"
