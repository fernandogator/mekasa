"""Spending / purchase-event repository (REQ-015–REQ-018)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from threading import Lock
from typing import Protocol
from uuid import uuid4

from app.config import Settings, get_settings
from app.household_access import assert_household_member
from app.models import (
    PurchaseEventCreateRequest,
    PurchaseEventResponse,
    PurchaseEventUpdateRequest,
    SpendingCategoryTotal,
    SpendingPeriod,
    SpendingReportResponse,
)
from app.repository import resolve_persistence_mode


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _period_start(period: SpendingPeriod, *, now: datetime | None = None) -> datetime:
    current = now or _utcnow()
    if period == "week":
        return current - timedelta(days=7)
    if period == "month":
        return current - timedelta(days=30)
    return current - timedelta(days=365)


class SpendingRepository(Protocol):
    """Persistence port for purchase events and spending reports."""

    def create(
        self, household_id: str, actor_uid: str, payload: PurchaseEventCreateRequest
    ) -> PurchaseEventResponse:
        """Record a purchase event."""

    def update(
        self,
        household_id: str,
        event_id: str,
        actor_uid: str,
        payload: PurchaseEventUpdateRequest,
    ) -> PurchaseEventResponse:
        """Patch category/name/price (REQ-017 AC3)."""

    def report(
        self,
        household_id: str,
        actor_uid: str,
        *,
        period: SpendingPeriod = "week",
        category: str | None = None,
    ) -> SpendingReportResponse:
        """Aggregate spending for a period."""


class InMemorySpendingRepository:
    """
    Satisfies: REQ-015, REQ-017, REQ-018
    Spec version: 1.0
    """

    def __init__(self) -> None:
        self._events: dict[str, dict[str, PurchaseEventResponse]] = {}
        self._lock = Lock()

    def create(
        self, household_id: str, actor_uid: str, payload: PurchaseEventCreateRequest
    ) -> PurchaseEventResponse:
        assert_household_member(household_id, actor_uid)
        now = _utcnow()
        event = PurchaseEventResponse(
            id=str(uuid4()),
            household_id=household_id,
            name=payload.name.strip(),
            category=payload.category.strip(),
            price_paid=float(payload.price_paid),
            quantity=payload.quantity,
            store_id=payload.store_id,
            inventory_item_id=payload.inventory_item_id,
            source=payload.source,
            purchased_at=payload.purchased_at or now,
            created_by_uid=actor_uid,
            created_at=now,
            updated_at=now,
        )
        with self._lock:
            self._events.setdefault(household_id, {})[event.id] = event
        return event

    def update(
        self,
        household_id: str,
        event_id: str,
        actor_uid: str,
        payload: PurchaseEventUpdateRequest,
    ) -> PurchaseEventResponse:
        assert_household_member(household_id, actor_uid)
        with self._lock:
            event = self._events.get(household_id, {}).get(event_id)
            if event is None:
                raise KeyError(event_id)
            data = payload.model_dump(exclude_unset=True)
            if "name" in data and data["name"] is not None:
                data["name"] = data["name"].strip()
            if "category" in data and data["category"] is not None:
                data["category"] = data["category"].strip()
            data["updated_at"] = _utcnow()
            updated = event.model_copy(update=data)
            self._events[household_id][event_id] = updated
            return updated

    def report(
        self,
        household_id: str,
        actor_uid: str,
        *,
        period: SpendingPeriod = "week",
        category: str | None = None,
    ) -> SpendingReportResponse:
        assert_household_member(household_id, actor_uid)
        start = _period_start(period)
        category_filter = category.strip().casefold() if category else None
        with self._lock:
            events = list(self._events.get(household_id, {}).values())
        filtered: list[PurchaseEventResponse] = []
        for event in events:
            purchased = event.purchased_at
            if purchased.tzinfo is None:
                purchased = purchased.replace(tzinfo=timezone.utc)
            if purchased < start:
                continue
            if category_filter and event.category.strip().casefold() != category_filter:
                continue
            filtered.append(event)
        filtered.sort(key=lambda item: item.purchased_at, reverse=True)
        totals: dict[str, float] = {}
        total = 0.0
        for event in filtered:
            amount = float(event.price_paid) * float(event.quantity)
            total += amount
            totals[event.category] = totals.get(event.category, 0.0) + amount
        by_category = [
            SpendingCategoryTotal(category=name, total=round(value, 2))
            for name, value in sorted(totals.items(), key=lambda pair: pair[1], reverse=True)
        ]
        return SpendingReportResponse(
            household_id=household_id,
            period=period,
            total=round(total, 2),
            by_category=by_category,
            events=filtered,
        )


_spending_repo: SpendingRepository | None = None
_spending_repo_mode: str | None = None


def get_spending_repository() -> SpendingRepository:
    """Process-wide spending repository (memory or Firestore)."""
    global _spending_repo, _spending_repo_mode
    settings = get_settings()
    mode = resolve_persistence_mode(settings)
    if _spending_repo is not None and _spending_repo_mode == mode:
        return _spending_repo
    if mode == "firestore":
        from app.firestore_spending_repository import FirestoreSpendingRepository

        _spending_repo = FirestoreSpendingRepository.from_settings(settings)
    else:
        _spending_repo = InMemorySpendingRepository()
    _spending_repo_mode = mode
    return _spending_repo


def reset_spending_repository() -> None:
    """Reset for tests (forces in-memory)."""
    global _spending_repo, _spending_repo_mode
    _spending_repo = InMemorySpendingRepository()
    _spending_repo_mode = "memory"
