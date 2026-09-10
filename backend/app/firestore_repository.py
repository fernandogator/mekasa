"""Firestore-backed household repository (database: mekasa-db)."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from google.cloud import firestore

from app.config import Settings
from app.models import (
    AddressUpdateRequest,
    HouseholdCreateRequest,
    HouseholdResponse,
)

COLLECTION = "households"


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _to_household(doc_id: str, data: dict[str, Any]) -> HouseholdResponse:
    return HouseholdResponse(
        id=doc_id,
        name=data.get("name"),
        photo_url=data.get("photo_url"),
        owner_uid=str(data["owner_uid"]),
        address=data.get("address"),
        latitude=data.get("latitude"),
        longitude=data.get("longitude"),
        store_ids=list(data.get("store_ids") or []),
        created_at=data["created_at"],
        updated_at=data["updated_at"],
    )


class FirestoreHouseholdRepository:
    """
    Satisfies: REQ-001, REQ-002, REQ-003
    Acceptance criteria: AC1–AC5
    Spec version: 1.0

    Persists households in Firestore Native database ``mekasa-db``.
    """

    def __init__(self, client: firestore.Client) -> None:
        self._db = client
        self._col = client.collection(COLLECTION)

    @classmethod
    def from_settings(cls, settings: Settings) -> FirestoreHouseholdRepository:
        """Build a client for the configured project + named database."""
        project_id = settings.firebase_project_id or settings.gcp_project_id
        if not project_id:
            raise RuntimeError(
                "GCP_PROJECT_ID or FIREBASE_PROJECT_ID is required for Firestore"
            )
        client = firestore.Client(
            project=project_id,
            database=settings.firestore_database_id,
        )
        return cls(client)

    def create(self, owner_uid: str, payload: HouseholdCreateRequest) -> HouseholdResponse:
        existing = self.get_for_owner(owner_uid)
        if existing is not None:
            return existing

        household_id = str(uuid4())
        now = _utcnow()
        data = {
            "name": payload.name,
            "photo_url": payload.photo_url,
            "owner_uid": owner_uid,
            "address": None,
            "latitude": None,
            "longitude": None,
            "store_ids": [],
            "created_at": now,
            "updated_at": now,
        }
        self._col.document(household_id).set(data)
        return _to_household(household_id, data)

    def get(self, household_id: str) -> HouseholdResponse | None:
        snap = self._col.document(household_id).get()
        if not snap.exists:
            return None
        return _to_household(snap.id, snap.to_dict() or {})

    def get_for_owner(self, owner_uid: str) -> HouseholdResponse | None:
        query = self._col.where("owner_uid", "==", owner_uid).limit(1).stream()
        for snap in query:
            return _to_household(snap.id, snap.to_dict() or {})
        return None

    def update_address(
        self, household_id: str, owner_uid: str, payload: AddressUpdateRequest
    ) -> HouseholdResponse:
        household = self._require_owner(household_id, owner_uid)
        updates = {
            "address": payload.address,
            "latitude": payload.latitude,
            "longitude": payload.longitude,
            "updated_at": _utcnow(),
        }
        self._col.document(household_id).update(updates)
        return household.model_copy(update=updates)

    def set_stores(
        self, household_id: str, owner_uid: str, store_ids: list[str]
    ) -> HouseholdResponse:
        household = self._require_owner(household_id, owner_uid)
        updates = {
            "store_ids": list(store_ids),
            "updated_at": _utcnow(),
        }
        self._col.document(household_id).update(updates)
        return household.model_copy(update=updates)

    def update_photo_url(
        self, household_id: str, owner_uid: str, photo_url: str
    ) -> HouseholdResponse:
        household = self._require_owner(household_id, owner_uid)
        updates = {
            "photo_url": photo_url,
            "updated_at": _utcnow(),
        }
        self._col.document(household_id).update(updates)
        return household.model_copy(update=updates)

    def _require_owner(self, household_id: str, owner_uid: str) -> HouseholdResponse:
        household = self.get(household_id)
        if household is None:
            raise KeyError(household_id)
        if household.owner_uid != owner_uid:
            raise PermissionError(household_id)
        return household
