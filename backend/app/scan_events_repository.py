"""
Household scan events (`households/{hid}/scan_events/{id}`).

Satisfies: REQ-RCP-020 AC4, AC7 (capture writes a scan event)
Spec version: 1.0
Design: docs/design/gemini-receipt-parser.md §3.8

Only the capture contexts write here so far; add-items lookups and the
trash station still use the in-memory unknown-barcode log.
"""

from __future__ import annotations

from datetime import datetime, timezone
from threading import Lock
from typing import Literal, Protocol
from uuid import uuid4

from pydantic import BaseModel

from app.config import Settings, get_settings
from app.firestore_retry import STREAM_RETRY
from app.repository import resolve_persistence_mode

ScanContext = Literal["add_items", "trash_station", "manual_entry", "receipt_capture", "inventory_capture"]
ScanOutcome = Literal["found", "unknown", "consumed", "created"]


class ScanEvent(BaseModel):
    id: str
    household_id: str
    upc: str | None = None
    plu_code: str | None = None
    product_id: str | None = None
    scanned_by_uid: str
    scanned_at: datetime
    context: ScanContext
    outcome: ScanOutcome
    inventory_item_id: str | None = None
    correlated_receipt_id: str | None = None
    correlated_line_item_id: str | None = None


class ScanEventsRepository(Protocol):
    def record(self, event: ScanEvent) -> ScanEvent: ...

    def list_events(self, household_id: str) -> list[ScanEvent]: ...


def new_scan_event(household_id: str, uid: str, context: ScanContext, outcome: ScanOutcome, **fields) -> ScanEvent:
    return ScanEvent(
        id=str(uuid4()),
        household_id=household_id,
        scanned_by_uid=uid,
        scanned_at=datetime.now(timezone.utc),
        context=context,
        outcome=outcome,
        **fields,
    )


class InMemoryScanEventsRepository:
    def __init__(self) -> None:
        self._events: dict[str, list[ScanEvent]] = {}
        self._lock = Lock()

    def record(self, event: ScanEvent) -> ScanEvent:
        with self._lock:
            self._events.setdefault(event.household_id, []).append(event)
        return event

    def list_events(self, household_id: str) -> list[ScanEvent]:
        with self._lock:
            return list(self._events.get(household_id, []))


class FirestoreScanEventsRepository:
    def __init__(self, client) -> None:
        self._db = client

    @classmethod
    def from_settings(cls, settings: Settings) -> "FirestoreScanEventsRepository":
        from google.cloud import firestore

        project_id = settings.firebase_project_id or settings.gcp_project_id
        if not project_id:
            raise RuntimeError("GCP_PROJECT_ID or FIREBASE_PROJECT_ID is required for Firestore")
        return cls(firestore.Client(project=project_id, database=settings.firestore_database_id))

    def _col(self, household_id: str):
        return self._db.collection("households").document(household_id).collection("scan_events")

    def record(self, event: ScanEvent) -> ScanEvent:
        self._col(event.household_id).document(event.id).set(event.model_dump(exclude={"id", "household_id"}))
        return event

    def list_events(self, household_id: str) -> list[ScanEvent]:
        return [
            ScanEvent(id=snap.id, household_id=household_id, **(snap.to_dict() or {}))
            for snap in self._col(household_id).order_by("scanned_at").stream(retry=STREAM_RETRY)
        ]


_repo: ScanEventsRepository | None = None
_repo_mode: str | None = None


def get_scan_events_repository() -> ScanEventsRepository:
    """Process-wide repository; follows `HOUSEHOLD_PERSISTENCE` like inventory."""
    global _repo, _repo_mode
    settings = get_settings()
    mode = resolve_persistence_mode(settings)
    if _repo is not None and _repo_mode == mode:
        return _repo
    _repo = FirestoreScanEventsRepository.from_settings(settings) if mode == "firestore" else InMemoryScanEventsRepository()
    _repo_mode = mode
    return _repo


def reset_scan_events_repository() -> None:
    global _repo, _repo_mode
    _repo = InMemoryScanEventsRepository()
    _repo_mode = "memory"
