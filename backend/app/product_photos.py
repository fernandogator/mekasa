"""
Shared product photos taken in the product capture flow (REQ-RCP-021).

The capture is the explicit sharing action: a photo uploaded here is shown
with the scanned product to every signed-in household. Bytes live in their
own bucket at `product-photos/{photo_id}.jpg`, so the object name carries no
household or user id; the uploading household and uid are recorded only in
Firestore `households/{hid}/product_photos/{photo_id}`.

Item-detail pictures stay household-private and use `item_photos` instead
(REQ-INV-019).

Satisfies: REQ-RCP-021 (Product Photo Upload and Storage)
Acceptance criteria: AC1, AC2, AC3, AC5, AC6
Spec version: 1.0
"""

from __future__ import annotations

import io
from dataclasses import dataclass, replace
from datetime import datetime, timedelta, timezone
from threading import Lock
from typing import Protocol
from uuid import UUID, uuid4

from app.catalog_repository import photo_image_url
from app.config import Settings, get_settings
from app.item_photos import ImageTooLarge, UnsupportedImage, process_upload  # noqa: F401 - re-exported for the router

UNREFERENCED_TTL = timedelta(hours=24)
SIGNED_URL_TTL = timedelta(minutes=15)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def parse_photo_id(value: str | None) -> str | None:
    """Return the canonical (lowercase) UUID v4 string, or None when `value` is not one."""
    if not value:
        return None
    try:
        parsed = UUID(value)
    except ValueError:
        return None
    return str(parsed) if parsed.version == 4 else None


def _object_name(photo_id: str) -> str:
    return f"product-photos/{photo_id}.jpg"


@dataclass(frozen=True)
class ProductPhotoRecord:
    """Ownership record; lives under the uploading household only (AC2)."""

    photo_id: str
    household_id: str
    uploaded_by_uid: str
    width: int
    height: int
    bytes: int
    created_at: datetime
    expires_at: datetime | None

    @property
    def image_url(self) -> str:
        return photo_image_url(self.photo_id)


@dataclass(frozen=True)
class PhotoRedirect:
    url: str


@dataclass(frozen=True)
class PhotoBytes:
    jpeg: bytes


# ---------------------------------------------------------------------------
# Bytes
# ---------------------------------------------------------------------------


class ProductPhotoStore(Protocol):
    def put(self, photo_id: str, jpeg: bytes) -> None: ...

    def resolve(self, photo_id: str) -> PhotoRedirect | PhotoBytes | None: ...

    def delete(self, photo_id: str) -> bool: ...


class InMemoryProductPhotoStore:
    """Local / test backend: serves the bytes directly instead of a signed URL."""

    def __init__(self) -> None:
        self._objects: dict[str, bytes] = {}
        self._lock = Lock()

    def put(self, photo_id: str, jpeg: bytes) -> None:
        with self._lock:
            self._objects[_object_name(photo_id)] = jpeg

    def resolve(self, photo_id: str) -> PhotoBytes | None:
        with self._lock:
            jpeg = self._objects.get(_object_name(photo_id))
        return PhotoBytes(jpeg) if jpeg is not None else None

    def delete(self, photo_id: str) -> bool:
        with self._lock:
            return self._objects.pop(_object_name(photo_id), None) is not None

    def object_names(self) -> list[str]:
        with self._lock:
            return sorted(self._objects)


class GcsProductPhotoStore:
    """
    Cloud Storage backend. The bucket has uniform access and no public ACLs;
    reads go through short-lived V4 signed URLs (AC3). On Cloud Run the
    runtime credentials hold no private key, so signing uses the IAM
    signBlob API: the service account needs `roles/iam.serviceAccountTokenCreator`
    on itself.
    """

    def __init__(self, bucket_name: str, project_id: str | None = None) -> None:
        from google.cloud import storage

        client = storage.Client(project=project_id) if project_id else storage.Client()
        self._bucket = client.bucket(bucket_name)
        self._credentials = None
        self._cred_lock = Lock()

    def put(self, photo_id: str, jpeg: bytes) -> None:
        blob = self._bucket.blob(_object_name(photo_id))
        blob.cache_control = "private, max-age=86400"
        blob.upload_from_string(jpeg, content_type="image/jpeg")

    def resolve(self, photo_id: str) -> PhotoRedirect | None:
        blob = self._bucket.blob(_object_name(photo_id))
        if not blob.exists():
            return None
        email, token = self._signer()
        url = blob.generate_signed_url(
            version="v4",
            expiration=SIGNED_URL_TTL,
            method="GET",
            service_account_email=email,
            access_token=token,
        )
        return PhotoRedirect(url)

    def delete(self, photo_id: str) -> bool:
        from google.api_core.exceptions import NotFound

        try:
            self._bucket.blob(_object_name(photo_id)).delete()
            return True
        except NotFound:
            return False

    def _signer(self) -> tuple[str, str]:
        import google.auth
        from google.auth.transport.requests import Request

        with self._cred_lock:
            if self._credentials is None:
                self._credentials, _ = google.auth.default(
                    scopes=["https://www.googleapis.com/auth/cloud-platform"]
                )
            if not self._credentials.valid:
                self._credentials.refresh(Request())
            return self._credentials.service_account_email, self._credentials.token


# ---------------------------------------------------------------------------
# Ownership records
# ---------------------------------------------------------------------------


class ProductPhotoRecords(Protocol):
    def add(self, record: ProductPhotoRecord) -> None: ...

    def get(self, household_id: str, photo_id: str) -> ProductPhotoRecord | None: ...

    def mark_referenced(self, household_id: str, photo_id: str) -> None: ...

    def delete(self, household_id: str, photo_id: str) -> bool: ...


class InMemoryProductPhotoRecords:
    def __init__(self) -> None:
        self._records: dict[tuple[str, str], ProductPhotoRecord] = {}
        self._lock = Lock()

    def add(self, record: ProductPhotoRecord) -> None:
        with self._lock:
            self._records[(record.household_id, record.photo_id)] = record

    def get(self, household_id: str, photo_id: str) -> ProductPhotoRecord | None:
        with self._lock:
            return self._records.get((household_id, photo_id))

    def mark_referenced(self, household_id: str, photo_id: str) -> None:
        with self._lock:
            key = (household_id, photo_id)
            if key in self._records:
                self._records[key] = replace(self._records[key], expires_at=None)

    def delete(self, household_id: str, photo_id: str) -> bool:
        with self._lock:
            return self._records.pop((household_id, photo_id), None) is not None


class FirestoreProductPhotoRecords:
    """`households/{hid}/product_photos/{photo_id}` (AC2)."""

    def __init__(self, client) -> None:
        self._db = client

    @classmethod
    def from_settings(cls, settings: Settings) -> "FirestoreProductPhotoRecords":
        from google.cloud import firestore

        project_id = settings.firebase_project_id or settings.gcp_project_id
        if not project_id:
            raise RuntimeError("GCP_PROJECT_ID or FIREBASE_PROJECT_ID is required for Firestore")
        return cls(firestore.Client(project=project_id, database=settings.firestore_database_id))

    def _doc(self, household_id: str, photo_id: str):
        return (
            self._db.collection("households").document(household_id)
            .collection("product_photos").document(photo_id)
        )

    def add(self, record: ProductPhotoRecord) -> None:
        self._doc(record.household_id, record.photo_id).set(
            {
                "uploaded_by_uid": record.uploaded_by_uid,
                "width": record.width,
                "height": record.height,
                "bytes": record.bytes,
                "created_at": record.created_at,
                "expires_at": record.expires_at,
            }
        )

    def get(self, household_id: str, photo_id: str) -> ProductPhotoRecord | None:
        snap = self._doc(household_id, photo_id).get()
        if not snap.exists:
            return None
        data = snap.to_dict() or {}
        return ProductPhotoRecord(
            photo_id=photo_id,
            household_id=household_id,
            uploaded_by_uid=data.get("uploaded_by_uid", ""),
            width=int(data.get("width", 0)),
            height=int(data.get("height", 0)),
            bytes=int(data.get("bytes", 0)),
            created_at=data.get("created_at") or _utcnow(),
            expires_at=data.get("expires_at"),
        )

    def mark_referenced(self, household_id: str, photo_id: str) -> None:
        doc = self._doc(household_id, photo_id)
        if doc.get().exists:
            doc.update({"expires_at": None, "referenced_at": _utcnow()})

    def delete(self, household_id: str, photo_id: str) -> bool:
        doc = self._doc(household_id, photo_id)
        if not doc.get().exists:
            return False
        doc.delete()
        return True


# ---------------------------------------------------------------------------
# Service
# ---------------------------------------------------------------------------


class ProductPhotoService:
    """Upload / resolve / delete; household membership is checked by the router."""

    def __init__(self, store: ProductPhotoStore, records: ProductPhotoRecords) -> None:
        self.store = store
        self.records = records

    def upload(self, household_id: str, uid: str, data: bytes) -> ProductPhotoRecord:
        jpeg = process_upload(data)
        width, height = _dimensions(jpeg)
        now = _utcnow()
        record = ProductPhotoRecord(
            photo_id=str(uuid4()),
            household_id=household_id,
            uploaded_by_uid=uid,
            width=width,
            height=height,
            bytes=len(jpeg),
            created_at=now,
            expires_at=now + UNREFERENCED_TTL,
        )
        self.store.put(record.photo_id, jpeg)
        self.records.add(record)
        return record

    def owned_by(self, household_id: str, photo_id: str) -> ProductPhotoRecord | None:
        """The record when `photo_id` was uploaded by this household (capture uses this)."""
        canonical = parse_photo_id(photo_id)
        return self.records.get(household_id, canonical) if canonical else None

    def mark_referenced(self, household_id: str, photo_id: str) -> None:
        canonical = parse_photo_id(photo_id)
        if canonical:
            self.records.mark_referenced(household_id, canonical)

    def resolve(self, photo_id: str) -> PhotoRedirect | PhotoBytes | None:
        canonical = parse_photo_id(photo_id)
        return self.store.resolve(canonical) if canonical else None

    def delete(self, household_id: str, photo_id: str) -> bool:
        """Remove the object and the ownership record (AC5); False when not this household's."""
        canonical = parse_photo_id(photo_id)
        if canonical is None or self.records.get(household_id, canonical) is None:
            return False
        self.store.delete(canonical)
        self.records.delete(household_id, canonical)
        return True


def _dimensions(jpeg: bytes) -> tuple[int, int]:
    from PIL import Image

    with Image.open(io.BytesIO(jpeg)) as image:
        return image.size


_service: ProductPhotoService | None = None
_service_lock = Lock()


def get_product_photo_service() -> ProductPhotoService:
    """
    Process-wide service: GCS + Firestore when `PRODUCT_PHOTO_BUCKET` is set,
    otherwise everything in memory (local, tests).
    """
    global _service
    with _service_lock:
        if _service is None:
            cfg = get_settings()
            if cfg.product_photo_bucket:
                _service = ProductPhotoService(
                    GcsProductPhotoStore(cfg.product_photo_bucket, cfg.gcp_project_id),
                    FirestoreProductPhotoRecords.from_settings(cfg),
                )
            else:
                _service = ProductPhotoService(InMemoryProductPhotoStore(), InMemoryProductPhotoRecords())
        return _service


def reset_product_photo_service() -> None:
    global _service
    with _service_lock:
        _service = None
