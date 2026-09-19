"""Firestore-backed purchase events / spending reports."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from google.cloud import firestore

from app.config import Settings
from app.household_access import assert_household_member
from app.models import (
    PurchaseEventCreateRequest,
    PurchaseEventResponse,
    PurchaseEventUpdateRequest,
    SpendingCategoryTotal,
    SpendingPeriod,
    SpendingReportResponse,
)
from app.spending_repository import _period_start

HOUSEHOLDS = "households"
PURCHASES = "purchase_events"


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _to_event(household_id: str, doc_id: str, data: dict[str, Any]) -> PurchaseEventResponse:
    return PurchaseEventResponse(
        id=doc_id,
        household_id=household_id,
        name=str(data["name"]),
        category=str(data["category"]),
        price_paid=float(data.get("price_paid") or 0),
        quantity=int(data.get("quantity") or 1),
        store_id=data.get("store_id"),
        inventory_item_id=data.get("inventory_item_id"),
        source=data.get("source") or "manual",
        purchased_at=data["purchased_at"],
        created_by_uid=str(data["created_by_uid"]),
        created_at=data["created_at"],
        updated_at=data["updated_at"],
    )


class FirestoreSpendingRepository:
    """
    Satisfies: REQ-015, REQ-017, REQ-018
    Spec version: 1.0

    Path: households/{household_id}/purchase_events/{event_id}
    """

    def __init__(self, client: firestore.Client) -> None:
        self._db = client

    @classmethod
    def from_settings(cls, settings: Settings) -> FirestoreSpendingRepository:
        client = firestore.Client(
            project=settings.gcp_project_id or settings.firebase_project_id,
            database=settings.firestore_database_id,
        )
        return cls(client)

    def _col(self, household_id: str):
        return self._db.collection(HOUSEHOLDS).document(household_id).collection(PURCHASES)

    def create(
        self, household_id: str, actor_uid: str, payload: PurchaseEventCreateRequest
    ) -> PurchaseEventResponse:
        assert_household_member(household_id, actor_uid)
        now = _utcnow()
        event_id = str(uuid4())
        data = {
            "name": payload.name.strip(),
            "category": payload.category.strip(),
            "price_paid": float(payload.price_paid),
            "quantity": payload.quantity,
            "store_id": payload.store_id,
            "inventory_item_id": payload.inventory_item_id,
            "source": payload.source,
            "purchased_at": payload.purchased_at or now,
            "created_by_uid": actor_uid,
            "created_at": now,
            "updated_at": now,
        }
        self._col(household_id).document(event_id).set(data)
        return _to_event(household_id, event_id, data)

    def update(
        self,
        household_id: str,
        event_id: str,
        actor_uid: str,
        payload: PurchaseEventUpdateRequest,
    ) -> PurchaseEventResponse:
        assert_household_member(household_id, actor_uid)
        ref = self._col(household_id).document(event_id)
        snap = ref.get()
        if not snap.exists:
            raise KeyError(event_id)
        data = dict(snap.to_dict() or {})
        updates = payload.model_dump(exclude_unset=True)
        if "name" in updates and updates["name"] is not None:
            updates["name"] = updates["name"].strip()
        if "category" in updates and updates["category"] is not None:
            updates["category"] = updates["category"].strip()
        updates["updated_at"] = _utcnow()
        data.update(updates)
        ref.update(updates)
        return _to_event(household_id, event_id, data)

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
        query = self._col(household_id).where("purchased_at", ">=", start)
        filtered: list[PurchaseEventResponse] = []
        for snap in query.stream():
            event = _to_event(household_id, snap.id, dict(snap.to_dict() or {}))
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
