"""
Household-private item photos (REQ-INV-019).

A member replaces an item's picture with their own photo. The bytes live in a
Cloud Storage bucket under `households/{hid}/item-photos/{photo_id}.jpg` and
are served only through the API to signed-in members of that household. They
are never shared with other households or with the shared product catalog.

Satisfies: REQ-INV-019 (Replace an Item Picture With a Private Photo)
Acceptance criteria: AC1, AC2, AC3, AC4, AC5, AC7
Spec version: 1.0
"""

from __future__ import annotations

import io
import re
from dataclasses import dataclass
from threading import Lock
from typing import Protocol
from urllib.parse import urlsplit
from uuid import UUID, uuid4

from app.config import Settings, get_settings

MAX_UPLOAD_BYTES = 8 * 1024 * 1024
MAX_LONG_EDGE = 1600
JPEG_QUALITY = 82
_ACCEPTED_FORMATS = {"JPEG", "PNG", "WEBP", "MPO"}

_PATH_RE = re.compile(r"^/v1/households/(?P<hid>[^/]+)/item-photos/(?P<photo_id>[0-9a-fA-F-]{36})$")


class UnsupportedImage(ValueError):
    """The upload is not an image we can decode (→ 415)."""


class ImageTooLarge(ValueError):
    """The upload exceeds MAX_UPLOAD_BYTES (→ 413)."""


@dataclass(frozen=True)
class ItemPhotoRef:
    """Where a private photo lives; derived from its URL, never guessed."""

    household_id: str
    photo_id: str

    @property
    def object_name(self) -> str:
        return f"households/{self.household_id}/item-photos/{self.photo_id}.jpg"

    def url_path(self) -> str:
        return f"/v1/households/{self.household_id}/item-photos/{self.photo_id}"


def parse_item_photo_url(url: str | None) -> ItemPhotoRef | None:
    """Return the ref when `url` is one of our private photo URLs, else None.

    Accepts absolute (`https://host/v1/...`) and path-only forms.
    """
    if not url:
        return None
    value = url.strip()
    value = urlsplit(value).path if "://" in value else value.split("?", 1)[0]
    match = _PATH_RE.match(value)
    if not match:
        return None
    try:
        UUID(match.group("photo_id"))
    except ValueError:
        return None
    return ItemPhotoRef(household_id=match.group("hid"), photo_id=match.group("photo_id").lower())


def process_upload(data: bytes) -> bytes:
    """Re-encode as JPEG with metadata stripped and the long edge capped (AC1).

    Pillow writes a fresh file without EXIF/GPS unless asked to carry it over,
    so saving through a new image object is what strips the metadata.
    """
    if len(data) > MAX_UPLOAD_BYTES:
        raise ImageTooLarge(len(data))
    if not data:
        raise UnsupportedImage("empty")
    try:
        from PIL import Image, ImageOps, UnidentifiedImageError
    except ImportError as exc:  # pragma: no cover - dependency is pinned
        raise RuntimeError("Pillow is required for item photos") from exc

    try:
        image = Image.open(io.BytesIO(data))
        image.load()
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        raise UnsupportedImage(str(exc)) from exc
    if (image.format or "").upper() not in _ACCEPTED_FORMATS:
        raise UnsupportedImage(image.format or "unknown")

    # Apply the EXIF orientation before dropping it, so the picture is not rotated.
    image = ImageOps.exif_transpose(image) or image
    if max(image.size) > MAX_LONG_EDGE:
        image.thumbnail((MAX_LONG_EDGE, MAX_LONG_EDGE))
    if image.mode not in ("RGB", "L"):
        background = Image.new("RGB", image.size, (255, 255, 255))
        rgba = image.convert("RGBA")
        background.paste(rgba, mask=rgba.getchannel("A"))
        image = background
    elif image.mode == "L":
        image = image.convert("RGB")

    # A fresh image carries none of the source's `info` (EXIF, GPS, XMP, comments).
    clean = Image.new("RGB", image.size)
    clean.paste(image)
    out = io.BytesIO()
    clean.save(out, format="JPEG", quality=JPEG_QUALITY, optimize=True)
    return out.getvalue()


class ItemPhotoStore(Protocol):
    """Byte storage for private photos; keyed by (household, photo_id)."""

    def put(self, ref: ItemPhotoRef, jpeg: bytes) -> None: ...

    def get(self, ref: ItemPhotoRef) -> bytes | None: ...

    def delete(self, ref: ItemPhotoRef) -> bool: ...


class InMemoryItemPhotoStore:
    """Local / test backend (AC7)."""

    def __init__(self) -> None:
        self._objects: dict[str, bytes] = {}
        self._lock = Lock()

    def put(self, ref: ItemPhotoRef, jpeg: bytes) -> None:
        with self._lock:
            self._objects[ref.object_name] = jpeg

    def get(self, ref: ItemPhotoRef) -> bytes | None:
        with self._lock:
            return self._objects.get(ref.object_name)

    def delete(self, ref: ItemPhotoRef) -> bool:
        with self._lock:
            return self._objects.pop(ref.object_name, None) is not None

    def object_names(self) -> list[str]:
        with self._lock:
            return sorted(self._objects)


class GcsItemPhotoStore:
    """Cloud Storage backend (AC2). The bucket has uniform access and no public ACLs."""

    def __init__(self, bucket_name: str, project_id: str | None = None) -> None:
        from google.cloud import storage

        client = storage.Client(project=project_id) if project_id else storage.Client()
        self._bucket = client.bucket(bucket_name)

    def put(self, ref: ItemPhotoRef, jpeg: bytes) -> None:
        blob = self._bucket.blob(ref.object_name)
        blob.cache_control = "private, max-age=0"
        blob.upload_from_string(jpeg, content_type="image/jpeg")

    def get(self, ref: ItemPhotoRef) -> bytes | None:
        from google.api_core.exceptions import NotFound

        blob = self._bucket.blob(ref.object_name)
        try:
            return blob.download_as_bytes()
        except NotFound:
            return None

    def delete(self, ref: ItemPhotoRef) -> bool:
        from google.api_core.exceptions import NotFound

        try:
            self._bucket.blob(ref.object_name).delete()
            return True
        except NotFound:
            return False


class ItemPhotoService:
    """Upload / fetch / delete with the household checks done by the router."""

    def __init__(self, store: ItemPhotoStore) -> None:
        self.store = store

    def upload(self, household_id: str, data: bytes) -> ItemPhotoRef:
        jpeg = process_upload(data)
        ref = ItemPhotoRef(household_id=household_id, photo_id=str(uuid4()))
        self.store.put(ref, jpeg)
        return ref

    def fetch(self, household_id: str, photo_id: str) -> bytes | None:
        ref = _ref_or_none(household_id, photo_id)
        return self.store.get(ref) if ref else None

    def delete(self, household_id: str, photo_id: str) -> bool:
        ref = _ref_or_none(household_id, photo_id)
        return self.store.delete(ref) if ref else False

    def delete_if_owned(self, household_id: str, url: str | None) -> bool:
        """Best-effort cleanup of a photo URL that belongs to `household_id` (AC4)."""
        ref = parse_item_photo_url(url)
        if ref is None or ref.household_id != household_id:
            return False
        try:
            return self.store.delete(ref)
        except Exception:  # noqa: BLE001 - cleanup must never fail the request
            return False


def _ref_or_none(household_id: str, photo_id: str) -> ItemPhotoRef | None:
    try:
        UUID(photo_id)
    except ValueError:
        return None
    return ItemPhotoRef(household_id=household_id, photo_id=photo_id.lower())


_service: ItemPhotoService | None = None
_service_lock = Lock()


def get_item_photo_service() -> ItemPhotoService:
    """Process-wide service: GCS when `ITEM_PHOTO_BUCKET` is set, else in memory (AC7).

    Takes no arguments so FastAPI can use it directly as a dependency.
    """
    global _service
    with _service_lock:
        if _service is None:
            cfg: Settings = get_settings()
            store: ItemPhotoStore
            if cfg.item_photo_bucket:
                store = GcsItemPhotoStore(cfg.item_photo_bucket, cfg.gcp_project_id)
            else:
                store = InMemoryItemPhotoStore()
            _service = ItemPhotoService(store)
        return _service


def reset_item_photo_service() -> None:
    global _service
    with _service_lock:
        _service = None
