"""Inventory repository protocol, in-memory impl, and factory."""

from __future__ import annotations

from datetime import datetime, timezone
from threading import Lock
from typing import Protocol
from uuid import uuid4

from app.config import Settings, get_settings
from app.models import (
    InventoryConsumeByBarcodeRequest,
    InventoryConsumeRequest,
    InventoryItemCreateRequest,
    InventoryItemResponse,
    InventoryItemUpdateRequest,
)
from app.repository import HouseholdRepository, get_household_repository, resolve_persistence_mode


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _norm(value: str) -> str:
    return value.strip().casefold()


class InventoryRepository(Protocol):
    """Persistence port for household inventory items."""

    def list_items(self, household_id: str, owner_uid: str) -> list[InventoryItemResponse]:
        """List all items for a household (owner only)."""

    def get(
        self, household_id: str, item_id: str, owner_uid: str
    ) -> InventoryItemResponse | None:
        """Get one item."""

    def create(
        self, household_id: str, owner_uid: str, payload: InventoryItemCreateRequest
    ) -> InventoryItemResponse:
        """Create or merge into an existing name+category / barcode row."""

    def update(
        self,
        household_id: str,
        item_id: str,
        owner_uid: str,
        payload: InventoryItemUpdateRequest,
    ) -> InventoryItemResponse:
        """Patch item fields."""

    def delete(self, household_id: str, item_id: str, owner_uid: str) -> None:
        """Delete item."""

    def consume(
        self,
        household_id: str,
        item_id: str,
        owner_uid: str,
        payload: InventoryConsumeRequest,
    ) -> InventoryItemResponse:
        """Decrement quantity (floor at 0)."""

    def consume_by_barcode(
        self,
        household_id: str,
        owner_uid: str,
        payload: InventoryConsumeByBarcodeRequest,
    ) -> InventoryItemResponse:
        """Decrement matching barcode; KeyError if unknown (REQ-008 AC3)."""


class InMemoryInventoryRepository:
    """
    Satisfies: REQ-004–REQ-009 (persistence slice)
    Spec version: 1.0

    Used for unit tests and local runs without Firestore credentials.
    """

    def __init__(self, households: HouseholdRepository) -> None:
        self._households = households
        self._items: dict[str, dict[str, InventoryItemResponse]] = {}
        self._lock = Lock()

    def list_items(self, household_id: str, owner_uid: str) -> list[InventoryItemResponse]:
        self._require_owner(household_id, owner_uid)
        with self._lock:
            items = list(self._items.get(household_id, {}).values())
        return sorted(items, key=lambda item: item.updated_at, reverse=True)

    def get(
        self, household_id: str, item_id: str, owner_uid: str
    ) -> InventoryItemResponse | None:
        self._require_owner(household_id, owner_uid)
        return self._items.get(household_id, {}).get(item_id)

    def create(
        self, household_id: str, owner_uid: str, payload: InventoryItemCreateRequest
    ) -> InventoryItemResponse:
        self._require_owner(household_id, owner_uid)
        with self._lock:
            bucket = self._items.setdefault(household_id, {})
            existing = self._find_merge_target(bucket, payload)
            if existing is not None:
                updates: dict = {
                    "quantity": existing.quantity + payload.quantity,
                    "updated_by_uid": owner_uid,
                    "updated_at": _utcnow(),
                    "source": payload.source,
                }
                if payload.price_paid is not None:
                    updates["price_paid"] = payload.price_paid
                if payload.barcode:
                    updates["barcode"] = payload.barcode
                merged = existing.model_copy(update=updates)
                bucket[existing.id] = merged
                return merged

            now = _utcnow()
            item = InventoryItemResponse(
                id=str(uuid4()),
                household_id=household_id,
                name=payload.name.strip(),
                category=payload.category.strip(),
                quantity=payload.quantity,
                low_stock_threshold=payload.low_stock_threshold,
                price_paid=payload.price_paid,
                barcode=payload.barcode,
                source=payload.source,
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
        payload: InventoryItemUpdateRequest,
    ) -> InventoryItemResponse:
        self._require_owner(household_id, owner_uid)
        with self._lock:
            item = self._items.get(household_id, {}).get(item_id)
            if item is None:
                raise KeyError(item_id)
            data = payload.model_dump(exclude_unset=True)
            if "name" in data and data["name"] is not None:
                data["name"] = data["name"].strip()
            if "category" in data and data["category"] is not None:
                data["category"] = data["category"].strip()
            data["updated_by_uid"] = owner_uid
            data["updated_at"] = _utcnow()
            updated = item.model_copy(update=data)
            self._items[household_id][item_id] = updated
            return updated

    def delete(self, household_id: str, item_id: str, owner_uid: str) -> None:
        self._require_owner(household_id, owner_uid)
        with self._lock:
            bucket = self._items.get(household_id, {})
            if item_id not in bucket:
                raise KeyError(item_id)
            del bucket[item_id]

    def consume(
        self,
        household_id: str,
        item_id: str,
        owner_uid: str,
        payload: InventoryConsumeRequest,
    ) -> InventoryItemResponse:
        self._require_owner(household_id, owner_uid)
        with self._lock:
            item = self._items.get(household_id, {}).get(item_id)
            if item is None:
                raise KeyError(item_id)
            updated = item.model_copy(
                update={
                    "quantity": max(0, item.quantity - payload.amount),
                    "updated_by_uid": owner_uid,
                    "updated_at": _utcnow(),
                }
            )
            self._items[household_id][item_id] = updated
            return updated

    def consume_by_barcode(
        self,
        household_id: str,
        owner_uid: str,
        payload: InventoryConsumeByBarcodeRequest,
    ) -> InventoryItemResponse:
        self._require_owner(household_id, owner_uid)
        with self._lock:
            bucket = self._items.get(household_id, {})
            match = next(
                (
                    item
                    for item in bucket.values()
                    if item.barcode and item.barcode == payload.barcode
                ),
                None,
            )
            if match is None:
                raise KeyError(payload.barcode)
            updated = match.model_copy(
                update={
                    "quantity": max(0, match.quantity - payload.amount),
                    "updated_by_uid": owner_uid,
                    "updated_at": _utcnow(),
                }
            )
            bucket[match.id] = updated
            return updated

    def _require_owner(self, household_id: str, owner_uid: str) -> None:
        household = self._households.get(household_id)
        if household is None:
            raise KeyError(household_id)
        if household.owner_uid != owner_uid:
            raise PermissionError(household_id)

    @staticmethod
    def _find_merge_target(
        bucket: dict[str, InventoryItemResponse], payload: InventoryItemCreateRequest
    ) -> InventoryItemResponse | None:
        if payload.barcode:
            for item in bucket.values():
                if item.barcode and item.barcode == payload.barcode:
                    return item
        name = _norm(payload.name)
        category = _norm(payload.category)
        for item in bucket.values():
            if _norm(item.name) == name and _norm(item.category) == category:
                return item
        return None


_inventory_repo: InventoryRepository | None = None
_inventory_repo_mode: str | None = None


def get_inventory_repository() -> InventoryRepository:
    """Process-wide inventory repository (memory or Firestore)."""
    global _inventory_repo, _inventory_repo_mode
    settings = get_settings()
    mode = resolve_persistence_mode(settings)
    if _inventory_repo is not None and _inventory_repo_mode == mode:
        return _inventory_repo

    households = get_household_repository()
    if mode == "firestore":
        from app.firestore_inventory_repository import FirestoreInventoryRepository

        _inventory_repo = FirestoreInventoryRepository.from_settings(settings, households)
    else:
        _inventory_repo = InMemoryInventoryRepository(households)
    _inventory_repo_mode = mode
    return _inventory_repo


def reset_inventory_repository() -> None:
    """Reset inventory repository for tests (forces in-memory)."""
    global _inventory_repo, _inventory_repo_mode
    _inventory_repo = InMemoryInventoryRepository(get_household_repository())
    _inventory_repo_mode = "memory"
