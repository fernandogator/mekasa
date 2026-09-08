"""Firestore-backed inventory repository (subcollection under households)."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from google.cloud import firestore

from app.config import Settings
from app.models import (
    InventoryConsumeByBarcodeRequest,
    InventoryConsumeRequest,
    InventoryItemCreateRequest,
    InventoryItemResponse,
    InventoryItemUpdateRequest,
)
from app.repository import HouseholdRepository

HOUSEHOLDS = "households"
INVENTORY = "inventory_items"


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _norm(value: str) -> str:
    return value.strip().casefold()


def _to_item(household_id: str, doc_id: str, data: dict[str, Any]) -> InventoryItemResponse:
    return InventoryItemResponse(
        id=doc_id,
        household_id=household_id,
        name=str(data["name"]),
        category=str(data.get("category") or "Other"),
        quantity=int(data.get("quantity") or 0),
        low_stock_threshold=int(data.get("low_stock_threshold") or 1),
        price_paid=data.get("price_paid"),
        barcode=data.get("barcode"),
        source=data.get("source") or "manual",
        created_by_uid=str(data["created_by_uid"]),
        updated_by_uid=str(data["updated_by_uid"]),
        created_at=data["created_at"],
        updated_at=data["updated_at"],
    )


class FirestoreInventoryRepository:
    """
    Satisfies: REQ-004–REQ-009 (persistence slice)
    Spec version: 1.0

    Path: households/{household_id}/inventory_items/{item_id}
    """

    def __init__(self, client: firestore.Client, households: HouseholdRepository) -> None:
        self._db = client
        self._households = households

    @classmethod
    def from_settings(
        cls, settings: Settings, households: HouseholdRepository
    ) -> FirestoreInventoryRepository:
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
        return self._db.collection(HOUSEHOLDS).document(household_id).collection(INVENTORY)

    def list_items(self, household_id: str, owner_uid: str) -> list[InventoryItemResponse]:
        self._require_owner(household_id, owner_uid)
        items = [
            _to_item(household_id, snap.id, snap.to_dict() or {})
            for snap in self._col(household_id).stream()
        ]
        return sorted(items, key=lambda item: item.updated_at, reverse=True)

    def get(
        self, household_id: str, item_id: str, owner_uid: str
    ) -> InventoryItemResponse | None:
        self._require_owner(household_id, owner_uid)
        snap = self._col(household_id).document(item_id).get()
        if not snap.exists:
            return None
        return _to_item(household_id, snap.id, snap.to_dict() or {})

    def create(
        self, household_id: str, owner_uid: str, payload: InventoryItemCreateRequest
    ) -> InventoryItemResponse:
        self._require_owner(household_id, owner_uid)
        existing = self._find_merge_target(household_id, payload)
        if existing is not None:
            updates: dict[str, Any] = {
                "quantity": existing.quantity + payload.quantity,
                "updated_by_uid": owner_uid,
                "updated_at": _utcnow(),
                "source": payload.source,
            }
            if payload.price_paid is not None:
                updates["price_paid"] = payload.price_paid
            if payload.barcode:
                updates["barcode"] = payload.barcode
            self._col(household_id).document(existing.id).update(updates)
            return existing.model_copy(update=updates)

        item_id = str(uuid4())
        now = _utcnow()
        data = {
            "name": payload.name.strip(),
            "category": payload.category.strip(),
            "quantity": payload.quantity,
            "low_stock_threshold": payload.low_stock_threshold,
            "price_paid": payload.price_paid,
            "barcode": payload.barcode,
            "source": payload.source,
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
        payload: InventoryItemUpdateRequest,
    ) -> InventoryItemResponse:
        self._require_owner(household_id, owner_uid)
        item = self.get(household_id, item_id, owner_uid)
        if item is None:
            raise KeyError(item_id)
        data = payload.model_dump(exclude_unset=True)
        if "name" in data and data["name"] is not None:
            data["name"] = data["name"].strip()
        if "category" in data and data["category"] is not None:
            data["category"] = data["category"].strip()
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

    def consume(
        self,
        household_id: str,
        item_id: str,
        owner_uid: str,
        payload: InventoryConsumeRequest,
    ) -> InventoryItemResponse:
        self._require_owner(household_id, owner_uid)
        item = self.get(household_id, item_id, owner_uid)
        if item is None:
            raise KeyError(item_id)
        updates = {
            "quantity": max(0, item.quantity - payload.amount),
            "updated_by_uid": owner_uid,
            "updated_at": _utcnow(),
        }
        self._col(household_id).document(item_id).update(updates)
        return item.model_copy(update=updates)

    def consume_by_barcode(
        self,
        household_id: str,
        owner_uid: str,
        payload: InventoryConsumeByBarcodeRequest,
    ) -> InventoryItemResponse:
        self._require_owner(household_id, owner_uid)
        query = (
            self._col(household_id)
            .where("barcode", "==", payload.barcode)
            .limit(1)
            .stream()
        )
        match = None
        for snap in query:
            match = _to_item(household_id, snap.id, snap.to_dict() or {})
            break
        if match is None:
            raise KeyError(payload.barcode)
        updates = {
            "quantity": max(0, match.quantity - payload.amount),
            "updated_by_uid": owner_uid,
            "updated_at": _utcnow(),
        }
        self._col(household_id).document(match.id).update(updates)
        return match.model_copy(update=updates)

    def _find_merge_target(
        self, household_id: str, payload: InventoryItemCreateRequest
    ) -> InventoryItemResponse | None:
        col = self._col(household_id)
        if payload.barcode:
            for snap in col.where("barcode", "==", payload.barcode).limit(1).stream():
                return _to_item(household_id, snap.id, snap.to_dict() or {})
        # Name+category merge scanned in-process (avoid composite index for v1).
        name = _norm(payload.name)
        category = _norm(payload.category)
        for snap in col.stream():
            data = snap.to_dict() or {}
            if _norm(str(data.get("name") or "")) == name and _norm(
                str(data.get("category") or "")
            ) == category:
                return _to_item(household_id, snap.id, data)
        return None

    def _require_owner(self, household_id: str, owner_uid: str) -> None:
        household = self._households.get(household_id)
        if household is None:
            raise KeyError(household_id)
        if household.owner_uid != owner_uid:
            raise PermissionError(household_id)
