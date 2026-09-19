"""Device token registration for FCM push (PRD §8 scaffold)."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Protocol
from uuid import uuid4

from app.config import Settings
from app.models import DeviceRegistrationRequest, DeviceRegistrationResponse


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class DevicesRepository(Protocol):
    def upsert(self, uid: str, payload: DeviceRegistrationRequest) -> DeviceRegistrationResponse:
        """Create or update a device token for the user."""

    def delete(self, uid: str, fcm_token: str) -> None:
        """Remove a device token."""

    def list_tokens_for_uids(self, uids: list[str]) -> list[str]:
        """FCM tokens for any of the given uids."""


class InMemoryDevicesRepository:
    """Process-local device tokens (tests + local)."""

    def __init__(self) -> None:
        # token -> DeviceRegistrationResponse
        self._by_token: dict[str, DeviceRegistrationResponse] = {}

    def upsert(self, uid: str, payload: DeviceRegistrationRequest) -> DeviceRegistrationResponse:
        now = _utcnow()
        existing = self._by_token.get(payload.fcm_token)
        if existing and existing.uid == uid:
            updated = existing.model_copy(
                update={"platform": payload.platform, "updated_at": now}
            )
            self._by_token[payload.fcm_token] = updated
            return updated
        row = DeviceRegistrationResponse(
            id=str(uuid4()),
            uid=uid,
            fcm_token=payload.fcm_token,
            platform=payload.platform,
            created_at=now,
            updated_at=now,
        )
        self._by_token[payload.fcm_token] = row
        return row

    def delete(self, uid: str, fcm_token: str) -> None:
        row = self._by_token.get(fcm_token)
        if row is None:
            raise KeyError(fcm_token)
        if row.uid != uid:
            raise PermissionError("Forbidden")
        del self._by_token[fcm_token]

    def list_tokens_for_uids(self, uids: list[str]) -> list[str]:
        wanted = set(uids)
        return [row.fcm_token for row in self._by_token.values() if row.uid in wanted]


class FirestoreDevicesRepository:
    """Firestore-backed device tokens: users/{uid}/devices/{tokenHash}."""

    def __init__(self, client) -> None:
        self._db = client

    @classmethod
    def from_settings(cls, settings: Settings) -> FirestoreDevicesRepository:
        from google.cloud import firestore

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

    def _col(self, uid: str):
        return self._db.collection("users").document(uid).collection("devices")

    def upsert(self, uid: str, payload: DeviceRegistrationRequest) -> DeviceRegistrationResponse:
        now = _utcnow()
        # Stable doc id from token (avoid listing by value).
        doc_id = payload.fcm_token[-64:] if len(payload.fcm_token) > 64 else payload.fcm_token
        ref = self._col(uid).document(doc_id)
        snap = ref.get()
        if snap.exists:
            data = snap.to_dict() or {}
            data.update(
                {
                    "fcm_token": payload.fcm_token,
                    "platform": payload.platform,
                    "updated_at": now,
                }
            )
            ref.set(data)
            return DeviceRegistrationResponse(
                id=doc_id,
                uid=uid,
                fcm_token=payload.fcm_token,
                platform=payload.platform,
                created_at=data.get("created_at") or now,
                updated_at=now,
            )
        data = {
            "fcm_token": payload.fcm_token,
            "platform": payload.platform,
            "created_at": now,
            "updated_at": now,
        }
        ref.set(data)
        return DeviceRegistrationResponse(
            id=doc_id,
            uid=uid,
            fcm_token=payload.fcm_token,
            platform=payload.platform,
            created_at=now,
            updated_at=now,
        )

    def delete(self, uid: str, fcm_token: str) -> None:
        doc_id = fcm_token[-64:] if len(fcm_token) > 64 else fcm_token
        ref = self._col(uid).document(doc_id)
        if not ref.get().exists:
            raise KeyError(fcm_token)
        ref.delete()

    def list_tokens_for_uids(self, uids: list[str]) -> list[str]:
        tokens: list[str] = []
        for uid in uids:
            for snap in self._col(uid).stream():
                data = snap.to_dict() or {}
                token = data.get("fcm_token")
                if isinstance(token, str) and token:
                    tokens.append(token)
        return tokens


_devices_repo: DevicesRepository | None = None
_devices_repo_mode: str | None = None


def get_devices_repository() -> DevicesRepository:
    global _devices_repo, _devices_repo_mode
    from app.config import get_settings
    from app.repository import resolve_persistence_mode

    settings = get_settings()
    mode = resolve_persistence_mode(settings)
    if _devices_repo is not None and _devices_repo_mode == mode:
        return _devices_repo
    if mode == "firestore":
        _devices_repo = FirestoreDevicesRepository.from_settings(settings)
    else:
        _devices_repo = InMemoryDevicesRepository()
    _devices_repo_mode = mode
    return _devices_repo


def reset_devices_repository() -> None:
    global _devices_repo, _devices_repo_mode
    _devices_repo = InMemoryDevicesRepository()
    _devices_repo_mode = "memory"
