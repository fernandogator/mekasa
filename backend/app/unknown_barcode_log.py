"""In-memory log of unknown trash-station barcode scans (REQ-008 AC3)."""

from __future__ import annotations

from datetime import datetime, timezone
from threading import Lock
from uuid import uuid4

from app.models import UnknownBarcodeEvent

_events: list[UnknownBarcodeEvent] = []
_lock = Lock()


def log_unknown_barcode(
    *, household_id: str, barcode: str, scanned_by_uid: str
) -> UnknownBarcodeEvent:
    """Record an unknown scan without creating inventory or negatives."""
    event = UnknownBarcodeEvent(
        id=str(uuid4()),
        household_id=household_id,
        barcode=barcode,
        scanned_by_uid=scanned_by_uid,
        created_at=datetime.now(timezone.utc),
    )
    with _lock:
        _events.append(event)
    return event


def list_unknown_barcodes(household_id: str) -> list[UnknownBarcodeEvent]:
    """Return unknown scan events for a household (newest first)."""
    with _lock:
        matched = [event for event in _events if event.household_id == household_id]
    return sorted(matched, key=lambda item: item.created_at, reverse=True)


def reset_unknown_barcode_events() -> None:
    """Reset for tests."""
    global _events
    with _lock:
        _events = []
