"""In-memory household repository for the thin onboarding API."""

from __future__ import annotations

from datetime import datetime, timezone
from threading import Lock
from typing import Protocol
from uuid import uuid4

from app.models import (
    AddressUpdateRequest,
    HouseholdCreateRequest,
    HouseholdResponse,
    Store,
)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class HouseholdRepository(Protocol):
    """Persistence port for households."""

    def create(self, owner_uid: str, payload: HouseholdCreateRequest) -> HouseholdResponse:
        """Create household for owner."""

    def get(self, household_id: str) -> HouseholdResponse | None:
        """Get by id."""

    def get_for_owner(self, owner_uid: str) -> HouseholdResponse | None:
        """Get first household for owner."""

    def update_address(
        self, household_id: str, owner_uid: str, payload: AddressUpdateRequest
    ) -> HouseholdResponse:
        """Update address fields."""

    def set_stores(
        self, household_id: str, owner_uid: str, store_ids: list[str]
    ) -> HouseholdResponse:
        """Persist selected store ids."""


class InMemoryHouseholdRepository:
    """
    Satisfies: REQ-001, REQ-002, REQ-003
    Acceptance criteria: AC1–AC5
    Spec version: 1.0
    """

    def __init__(self) -> None:
        self._items: dict[str, HouseholdResponse] = {}
        self._lock = Lock()

    def create(self, owner_uid: str, payload: HouseholdCreateRequest) -> HouseholdResponse:
        existing = self.get_for_owner(owner_uid)
        if existing is not None:
            return existing
        now = _utcnow()
        household = HouseholdResponse(
            id=str(uuid4()),
            name=payload.name,
            photo_url=payload.photo_url,
            owner_uid=owner_uid,
            created_at=now,
            updated_at=now,
        )
        with self._lock:
            self._items[household.id] = household
        return household

    def get(self, household_id: str) -> HouseholdResponse | None:
        return self._items.get(household_id)

    def get_for_owner(self, owner_uid: str) -> HouseholdResponse | None:
        for item in self._items.values():
            if item.owner_uid == owner_uid:
                return item
        return None

    def update_address(
        self, household_id: str, owner_uid: str, payload: AddressUpdateRequest
    ) -> HouseholdResponse:
        household = self._require_owner(household_id, owner_uid)
        updated = household.model_copy(
            update={
                "address": payload.address,
                "latitude": payload.latitude,
                "longitude": payload.longitude,
                "updated_at": _utcnow(),
            }
        )
        with self._lock:
            self._items[household_id] = updated
        return updated

    def set_stores(
        self, household_id: str, owner_uid: str, store_ids: list[str]
    ) -> HouseholdResponse:
        household = self._require_owner(household_id, owner_uid)
        updated = household.model_copy(
            update={"store_ids": list(store_ids), "updated_at": _utcnow()}
        )
        with self._lock:
            self._items[household_id] = updated
        return updated

    def _require_owner(self, household_id: str, owner_uid: str) -> HouseholdResponse:
        household = self.get(household_id)
        if household is None:
            raise KeyError(household_id)
        if household.owner_uid != owner_uid:
            raise PermissionError(household_id)
        return household


def stub_nearby_stores(
    *,
    latitude: float | None,
    longitude: float | None,
    radius_miles: float,
) -> list[Store]:
    """
    Satisfies: REQ-003
    Acceptance criteria: AC4
    Spec version: 1.0
    """
    base_lat = latitude if latitude is not None else 33.7490
    base_lng = longitude if longitude is not None else -84.3880
    samples = [
        ("walmart-stub", "Walmart", "100 Stub Retail Way", 2.1),
        ("costco-stub", "Costco", "200 Warehouse Blvd", 4.8),
        ("publix-stub", "Publix", "300 Grocery Lane", 1.4),
        ("kroger-stub", "Kroger", "400 Market Street", 3.2),
        ("local-stub", "Corner Market", "12 Neighborhood Ave", 0.7),
    ]
    return [
        Store(
            id=store_id,
            name=name,
            address=address,
            latitude=base_lat + (index * 0.01),
            longitude=base_lng + (index * 0.01),
            distance_miles=distance,
            provider="stub",
        )
        for index, (store_id, name, address, distance) in enumerate(samples)
        if distance <= radius_miles
    ]


_repo: HouseholdRepository | None = None


def get_household_repository() -> HouseholdRepository:
    """Process-wide repository (in-memory until Firestore is wired)."""
    global _repo
    if _repo is None:
        _repo = InMemoryHouseholdRepository()
    return _repo


def reset_household_repository() -> None:
    """Reset in-memory state for tests."""
    global _repo
    _repo = InMemoryHouseholdRepository()
