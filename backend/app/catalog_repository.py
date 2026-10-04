"""
Shared product catalog repository (ADR-008).

Satisfies: REQ-RCP-007, REQ-RCP-009, REQ-RCP-010 AC2, REQ-RCP-011,
REQ-RCP-013, REQ-RCP-014, REQ-RCP-019, REQ-RCP-020
Spec version: 1.0
Design: docs/design/gemini-receipt-parser.md §3.5, §3.11, §4.1

Two backends share one body of business logic:

* ``PostgresCatalogRepository`` — Cloud SQL Postgres over ``DATABASE_URL``
  (schema: ``backend/postgres/migrations``). Every operation is one
  transaction; receipt saves and captures take the per-chain advisory lock.
* ``InMemoryCatalogRepository`` — used when ``DATABASE_URL`` is unset (local
  dev, unit tests).

The catalog never sees a household or user id. Callers pass
``household_hash`` (see :func:`household_hash`); the shape is also enforced by
a CHECK constraint in Postgres.
"""

from __future__ import annotations

import hashlib
import re
import threading
import unicodedata
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from difflib import SequenceMatcher
from contextlib import AbstractContextManager, contextmanager
from typing import Literal, Protocol

from pydantic import BaseModel, Field

from app.categories import Category, normalize_category
from app.config import Settings, get_settings

# ---------------------------------------------------------------------------
# Pure rules (design §3.5)
# ---------------------------------------------------------------------------

ProductStatus = Literal["unverified", "pending", "verified"]
ProductSource = Literal["user_scan", "store_api", "gs1_registry", "llm_ocr"]
ImageSource = Literal["user_photo", "store_api", "openfoodfacts", "gs1_registry", "placeholder"]
ConflictField = Literal["name", "brand", "unit_size", "category", "upc", "image_url"]

SOURCE_WEIGHTS: dict[str, float] = {
    "gs1_registry": 0.9,
    "store_api": 0.8,
    "user_scan": 0.7,
    "llm_ocr": 0.4,
}
AUTHORITATIVE_SOURCES = frozenset({"gs1_registry", "store_api"})
IDENTITY_FIELDS = frozenset({"name", "brand", "category", "upc"})
CAPTURE_CONFIDENCE = 0.9  # REQ-RCP-020 AC2
FUZZY_CANDIDATE_THRESHOLD = 0.3
UPC_RE = re.compile(r"^[0-9]{8,14}$")
PLU_RE = re.compile(r"^[0-9]{4,5}$")
# PLU products are shared across chains (REQ-RCP-010 AC9) and filed under the seeded "unknown" chain.
SHARED_CHAIN_ID = "unknown"
PHOTO_URL_PREFIX = "/v1/product-photos/"

DEFAULT_DISCOVERY_CHAIN = ["store_api", "openfoodfacts", "upcitemdb", "gs1_verify", "crowdsourced_pending"]
CAPTURE_ENRICHMENT_CHAIN = ["store_api", "openfoodfacts", "gs1_verify"]


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def normalize_name(text: str) -> str:
    """Python twin of SQL ``catalog_normalize_name`` (lower, unaccent, [a-z0-9 ], collapse)."""
    decomposed = unicodedata.normalize("NFKD", text)
    ascii_only = "".join(ch for ch in decomposed if not unicodedata.combining(ch))
    cleaned = re.sub(r"[^a-z0-9 ]+", " ", ascii_only.lower())
    return re.sub(r"\s+", " ", cleaned).strip()


def llm_product_id(store_chain_id: str, normalized_name: str) -> str:
    digest = hashlib.sha1(f"{store_chain_id}|{normalized_name}".encode("utf-8")).hexdigest()
    return f"llm:{digest}"


def household_hash(household_id: str, salt: str | None = None) -> str:
    """SHA-256(household_id + server salt): the only household reference the catalog sees (NFR-002 AC1)."""
    if salt is None:
        salt = get_settings().catalog_household_salt
    return hashlib.sha256(f"{household_id}{salt}".encode("utf-8")).hexdigest()


def compute_confidence(source: str, confirmation_count: int, dispute_count: int) -> float:
    raw = SOURCE_WEIGHTS.get(source, 0.4) + 0.05 * confirmation_count - 0.1 * dispute_count
    return round(min(1.0, max(0.0, raw)), 3)


def next_status(status: str, confirmation_count: int, source: str, has_upc: bool) -> str:
    """REQ-RCP-011 AC1–AC3. Transitions chain within one evaluation; verified never downgrades."""
    authoritative = source in AUTHORITATIVE_SOURCES
    current = status
    if current == "unverified" and (confirmation_count >= 2 or authoritative):
        current = "pending"
    if current == "pending" and has_upc and (
        confirmation_count >= 3 or (authoritative and confirmation_count >= 1)
    ):
        current = "verified"
    return current


def plu_product_id(plu_code: str) -> str:
    return f"plu:{plu_code}"


def photo_image_url(photo_id: str) -> str:
    return f"{PHOTO_URL_PREFIX}{photo_id}"


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------


class CatalogProduct(BaseModel):
    """One ``products`` row. ``id`` is the UPC, ``plu:<code>`` or ``llm:<sha1>``."""

    id: str
    code_kind: Literal["upc", "plu", "llm"]
    upc: str | None = None
    plu_code: str | None = None
    store_chain_id: str
    name: str
    normalized_name: str
    brand: str | None = None
    category: Category
    unit_size: str | None = None
    image_url: str | None = None
    image_source: ImageSource | None = None
    source: ProductSource
    sources_seen: list[str] = Field(default_factory=list)
    confidence_score: float
    confirmation_count: int = 0
    dispute_count: int = 0
    status: ProductStatus = "unverified"
    status_changed_at: datetime | None = None
    origin_parse_job_id: str | None = None
    origin_prompt_version: str | None = None
    superseded_by: str | None = None
    first_seen_at: datetime = Field(default_factory=_utcnow)
    last_seen_at: datetime = Field(default_factory=_utcnow)

    def has_upc(self) -> bool:
        return self.upc is not None

    def reevaluate(self) -> bool:
        """
        Apply the §3.5 status rules in place; True when status changed.
        ``confidence_score`` is recomputed on every transition (REQ-RCP-011 AC4),
        so a fresh capture keeps its 0.9 until the first transition.
        """
        new_status = next_status(self.status, self.confirmation_count, self.source, self.has_upc())
        changed = new_status != self.status
        if changed:
            self.status = new_status  # type: ignore[assignment]
            self.status_changed_at = _utcnow()
            self.confidence_score = compute_confidence(self.source, self.confirmation_count, self.dispute_count)
        return changed


class CatalogConflict(BaseModel):
    id: str
    product_id: str
    field: ConflictField
    verified_value: str
    observed_value: str
    status: Literal["open", "dismissed", "accepted"] = "open"


class ReceiptLineSave(BaseModel):
    """What a receipt save needs per line (design §4.1 receipt-save transaction)."""

    raw_text: str
    description: str
    category: Category
    brand: str | None = None
    unit_size: str | None = None
    product_id: str | None = None
    """Already-resolved product (UPC / plu:) — only the alias is recorded. None → create an ``llm:`` row."""
    parse_job_id: str | None = None
    prompt_version: str | None = None


class ConfirmResult(BaseModel):
    product: CatalogProduct
    confirmation_counted: bool
    status_changed: bool


class CaptureResult(BaseModel):
    outcome: Literal["linked", "created", "rekeyed"]
    product: CatalogProduct
    confirmation_counted: bool
    enrichment_job_id: str | None = None
    photo_applied_as: Literal["product_image", "line_image", "correction_proposed", "none"] = "none"
    conflict: CatalogConflict | None = None


class CorrectionResult(BaseModel):
    applied: bool
    product: CatalogProduct
    conflicts: list[CatalogConflict] = Field(default_factory=list)
    status_reset: bool = False


class ProductNotFound(KeyError):
    pass


class UpcTaken(Exception):
    """Another product already owns the requested UPC."""

    def __init__(self, upc: str, owner_product_id: str) -> None:
        super().__init__(f"UPC {upc} belongs to {owner_product_id}")
        self.upc = upc
        self.owner_product_id = owner_product_id


class NoChanges(ValueError):
    pass


# ---------------------------------------------------------------------------
# Storage primitives — the only part that differs per backend
# ---------------------------------------------------------------------------


class _Session(Protocol):
    def lock_chain(self, store_chain_id: str) -> None: ...
    def get(self, product_id: str, for_update: bool = False) -> CatalogProduct | None: ...
    def get_by_upc(self, upc: str, for_update: bool = False) -> CatalogProduct | None: ...
    def insert(self, product: CatalogProduct) -> None: ...
    def update(self, product: CatalogProduct) -> None: ...
    def touch_last_seen(self, product_id: str) -> None: ...
    def add_confirmation(self, product_id: str, hh: str) -> bool: ...
    def count_confirmations(self, product_id: str) -> int: ...
    def copy_confirmations(self, from_id: str, to_id: str) -> None: ...
    def delete_confirmations(self, product_id: str) -> None: ...
    def upsert_alias(self, store_chain_id: str, alias: str, product_id: str) -> None: ...
    def repoint_aliases(self, from_id: str, to_id: str) -> None: ...
    def find_alias(self, store_chain_id: str, alias: str) -> str | None: ...
    def queue_enrichment(self, product_id: str, trigger: str, chain: list[str]) -> str | None: ...
    def add_conflict(
        self, product_id: str, hh: str, receipt_id: str, line_item_id: str,
        field_name: str, verified_value: str, observed_value: str,
    ) -> CatalogConflict: ...
    def search(self, q: str, store_chain_id: str | None, status: str | None, limit: int) -> list[CatalogProduct]: ...
    def clear_image(self, image_url: str) -> int: ...


# ---------------------------------------------------------------------------
# Business logic — written once
# ---------------------------------------------------------------------------


def _follow(session: _Session, product: CatalogProduct | None, hops: int = 5) -> CatalogProduct | None:
    while product is not None and product.superseded_by and hops > 0:
        nxt = session.get(product.superseded_by)
        if nxt is None:
            break
        product, hops = nxt, hops - 1
    return product


def _confirm(session: _Session, product: CatalogProduct, hh: str) -> ConfirmResult:
    counted = session.add_confirmation(product.id, hh)
    product.confirmation_count = session.count_confirmations(product.id)
    product.last_seen_at = _utcnow()
    changed = product.reevaluate()
    session.update(product)
    return ConfirmResult(product=product, confirmation_counted=counted, status_changed=changed)


def _rekey(
    session: _Session, old: CatalogProduct, upc: str, source: str, confidence: float,
    *, overrides: dict[str, str | None] | None = None,
) -> CatalogProduct:
    """
    Design §4.1 re-key: create (or merge into) the UPC row from ``old``,
    repoint aliases, carry confirmations once per household, stamp
    ``superseded_by``. ``old`` stays so Firestore ids still resolve.
    """
    target = session.get_by_upc(upc, for_update=True)
    now = _utcnow()
    if target is None:
        target = old.model_copy(
            update={
                "id": upc, "code_kind": "upc", "upc": upc, "plu_code": None,
                "source": source, "sources_seen": sorted(set(old.sources_seen) | {source}),
                "confidence_score": confidence, "superseded_by": None,
                "status_changed_at": None, "first_seen_at": now, "last_seen_at": now,
                **(overrides or {}),
            }
        )
        if target.name != old.name:
            target.normalized_name = normalize_name(target.name)
        session.insert(target)
    else:
        target.sources_seen = sorted(set(target.sources_seen) | set(old.sources_seen) | {source})
        target.dispute_count += old.dispute_count
        target.last_seen_at = max(target.last_seen_at, old.last_seen_at)
        for key, value in (overrides or {}).items():
            if value is not None:
                setattr(target, key, value)
        if overrides and "name" in overrides and overrides["name"]:
            target.normalized_name = normalize_name(target.name)
    session.copy_confirmations(old.id, target.id)
    session.repoint_aliases(old.id, target.id)
    target.confirmation_count = session.count_confirmations(target.id)
    target.reevaluate()
    session.update(target)
    old.superseded_by = target.id
    old.status_changed_at = now
    session.update(old)
    return target


def _save_receipt_lines(session: _Session, store_chain_id: str, lines: list[ReceiptLineSave]) -> list[str]:
    session.lock_chain(store_chain_id)
    ids: list[str] = []
    for line in lines:
        alias = normalize_name(line.raw_text) or normalize_name(line.description)
        if line.product_id:
            product_id = line.product_id
            session.touch_last_seen(product_id)
        else:
            normalized = normalize_name(line.description) or alias
            product_id = llm_product_id(store_chain_id, normalized)
            existing = session.get(product_id)
            if existing is None:
                session.insert(
                    CatalogProduct(
                        id=product_id, code_kind="llm", store_chain_id=store_chain_id,
                        name=line.description[:120], normalized_name=normalized[:120],
                        brand=line.brand, category=line.category, unit_size=line.unit_size,
                        source="llm_ocr", sources_seen=["llm_ocr"],
                        confidence_score=compute_confidence("llm_ocr", 0, 0),
                        origin_parse_job_id=line.parse_job_id, origin_prompt_version=line.prompt_version,
                    )
                )
                session.queue_enrichment(product_id, "unmatched_line", DEFAULT_DISCOVERY_CHAIN)
            else:
                session.touch_last_seen(product_id)
        if alias:
            session.upsert_alias(store_chain_id, alias[:120], product_id)
        ids.append(product_id)
    return ids


def _capture(
    session: _Session, *, store_chain_id: str, upc: str | None, plu_code: str | None, hh: str,
    fallback_name: str, fallback_category: str, alias_text: str | None,
    name: str | None, brand: str | None, category: str | None, unit_size: str | None,
    photo_id: str | None, previous_product_id: str | None,
    receipt_id: str | None, line_item_id: str | None,
) -> CaptureResult:
    """REQ-RCP-020 AC2–AC4, AC7 (design §3.11 step 2)."""
    if (upc is None) == (plu_code is None):
        raise ValueError("exactly_one_code_required")
    if upc is not None and not UPC_RE.match(upc):
        raise ValueError("invalid_upc")
    if plu_code is not None and not PLU_RE.match(plu_code):
        raise ValueError("invalid_plu")
    session.lock_chain(store_chain_id if upc else SHARED_CHAIN_ID)
    previous = session.get(previous_product_id, for_update=True) if previous_product_id and upc else None
    if previous is not None and (previous.superseded_by or previous.code_kind != "llm"):
        previous = None  # already re-keyed, or a UPC/PLU row — PLU products are never re-keyed (AC7)

    if upc:
        existing = session.get_by_upc(upc, for_update=True)
    else:
        existing = _follow(session, session.get(plu_product_id(plu_code or ""), for_update=True))
    photo_applied: str = "none"
    conflict: CatalogConflict | None = None
    enrichment_job_id: str | None = None
    category = normalize_category(category) if category else None
    fallback_category = normalize_category(fallback_category)
    overrides = {k: v for k, v in {"name": name, "brand": brand, "category": category, "unit_size": unit_size}.items() if v}

    if previous is not None:
        product = _rekey(session, previous, upc, "user_scan", CAPTURE_CONFIDENCE, overrides=overrides)
        outcome: str = "rekeyed"
        enrichment_job_id = session.queue_enrichment(product.id, "user_capture", CAPTURE_ENRICHMENT_CHAIN)
    elif existing is not None:
        product, outcome = existing, "linked"
    else:
        display_name = (name or fallback_name)[:120]
        product = CatalogProduct(
            id=upc or plu_product_id(plu_code or ""), code_kind="upc" if upc else "plu",
            upc=upc, plu_code=plu_code, store_chain_id=store_chain_id if upc else SHARED_CHAIN_ID,
            name=display_name, normalized_name=normalize_name(display_name)[:120],
            brand=brand, category=(category or fallback_category)[:60], unit_size=unit_size,
            image_url=photo_image_url(photo_id) if photo_id else None,
            image_source="user_photo" if photo_id else None,
            source="user_scan", sources_seen=["user_scan"], confidence_score=CAPTURE_CONFIDENCE,
        )
        session.insert(product)
        outcome = "created"
        if photo_id:
            photo_applied = "product_image"
        if upc:  # the enrichment adapters all look products up by UPC
            enrichment_job_id = session.queue_enrichment(product.id, "user_capture", CAPTURE_ENRICHMENT_CHAIN)

    if photo_id and photo_applied == "none":
        if product.image_url is None:
            product.image_url, product.image_source = photo_image_url(photo_id), "user_photo"
            photo_applied = "product_image"
        elif product.status == "verified":
            conflict = session.add_conflict(
                product.id, hh, receipt_id or "none", line_item_id or "none",
                "image_url", product.image_url, photo_image_url(photo_id),
            )
            photo_applied = "correction_proposed"
        else:
            photo_applied = "line_image"

    if alias_text:
        alias = normalize_name(alias_text)
        if alias:
            session.upsert_alias(store_chain_id, alias[:120], product.id)
    confirmed = _confirm(session, product, hh)
    return CaptureResult(
        outcome=outcome, product=confirmed.product, confirmation_counted=confirmed.confirmation_counted,
        enrichment_job_id=enrichment_job_id, photo_applied_as=photo_applied, conflict=conflict,
    )


def _correct(
    session: _Session, *, product_id: str, hh: str, changes: dict[str, str | None],
    photo_id: str | None, receipt_id: str | None, line_item_id: str | None,
) -> CorrectionResult:
    """REQ-RCP-019 AC3 (design §3.11 step 1, shared-product layer)."""
    if changes.get("category"):
        changes = {**changes, "category": normalize_category(changes["category"])}
    product = _follow(session, session.get(product_id, for_update=True))
    if product is None:
        raise ProductNotFound(product_id)
    product = session.get(product.id, for_update=True) or product

    diffs: dict[str, tuple[str | None, str | None]] = {}
    for key in ("name", "brand", "category", "unit_size"):
        if key in changes and changes[key] != getattr(product, key):
            diffs[key] = (getattr(product, key), changes[key])
    new_upc = changes.get("upc")
    if new_upc and new_upc != product.upc:
        if not UPC_RE.match(new_upc):
            raise ValueError("invalid_upc")
        owner = session.get_by_upc(new_upc)
        if owner is not None and owner.id != product.id:
            raise UpcTaken(new_upc, owner.id)
        diffs["upc"] = (product.upc, new_upc)
    new_image = photo_image_url(photo_id) if photo_id else None
    if new_image and new_image != product.image_url:
        diffs["image_url"] = (product.image_url, new_image)
    if not diffs:
        raise NoChanges("no_changes")

    if product.status == "verified":
        conflicts = [
            session.add_conflict(
                product.id, hh, receipt_id or "none", line_item_id or "none",
                field_name, old or "", new or "",
            )
            for field_name, (old, new) in diffs.items()
        ]
        return CorrectionResult(applied=False, product=product, conflicts=conflicts)

    overrides: dict[str, str | None] = {k: v[1] for k, v in diffs.items() if k in ("name", "brand", "category", "unit_size")}
    status_reset = any(k in IDENTITY_FIELDS for k in diffs)
    if "upc" in diffs:
        product = _rekey(session, product, diffs["upc"][1] or "", "user_scan", CAPTURE_CONFIDENCE, overrides=overrides)
    else:
        for key, value in overrides.items():
            setattr(product, key, value)
        if "name" in overrides and product.name:
            product.normalized_name = normalize_name(product.name)[:120]
    if "image_url" in diffs:
        product.image_url, product.image_source = new_image, "user_photo"
    product.sources_seen = sorted(set(product.sources_seen) | {"user_scan"})
    if status_reset:
        session.delete_confirmations(product.id)
        product.confirmation_count = 0
        product.status = "unverified"
        product.status_changed_at = _utcnow()
        product.confidence_score = compute_confidence(product.source, 0, product.dispute_count)
    product.last_seen_at = _utcnow()
    session.update(product)
    return CorrectionResult(applied=True, product=product, status_reset=status_reset)


# ---------------------------------------------------------------------------
# Public repository (backend-agnostic facade)
# ---------------------------------------------------------------------------


class CatalogRepository(Protocol):
    def get_product(self, product_id: str, follow_superseded: bool = True) -> CatalogProduct | None: ...
    def get_by_upc(self, upc: str) -> CatalogProduct | None: ...
    def lookup_alias(self, store_chain_id: str, raw_text: str) -> CatalogProduct | None: ...
    def search(self, q: str, store_chain_id: str | None = None, status: str | None = None, limit: int = 8) -> list[CatalogProduct]: ...
    def save_receipt_lines(self, store_chain_id: str, lines: list[ReceiptLineSave]) -> list[str]: ...
    def confirm(self, product_id: str, hh: str) -> ConfirmResult: ...
    def rekey_to_upc(self, product_id: str, upc: str, source: str, confidence: float) -> CatalogProduct: ...
    def capture(self, **kwargs) -> CaptureResult: ...
    def correct(self, **kwargs) -> CorrectionResult: ...
    def release_user_photo(self, photo_id: str) -> int: ...


class _BaseRepository:
    """Runs each operation inside one session/transaction."""

    def _session(self) -> AbstractContextManager[_Session]:
        raise NotImplementedError

    def get_product(self, product_id: str, follow_superseded: bool = True) -> CatalogProduct | None:
        with self._session() as s:
            product = s.get(product_id)
            return _follow(s, product) if follow_superseded else product

    def get_by_upc(self, upc: str) -> CatalogProduct | None:
        with self._session() as s:
            return s.get_by_upc(upc)

    def lookup_alias(self, store_chain_id: str, raw_text: str) -> CatalogProduct | None:
        alias = normalize_name(raw_text)
        if not alias:
            return None
        with self._session() as s:
            pid = s.find_alias(store_chain_id, alias)
            return _follow(s, s.get(pid)) if pid else None

    def search(self, q: str, store_chain_id: str | None = None, status: str | None = None, limit: int = 8) -> list[CatalogProduct]:
        with self._session() as s:
            return s.search(normalize_name(q), store_chain_id, status, limit)

    def save_receipt_lines(self, store_chain_id: str, lines: list[ReceiptLineSave]) -> list[str]:
        with self._session() as s:
            return _save_receipt_lines(s, store_chain_id, lines)

    def confirm(self, product_id: str, hh: str) -> ConfirmResult:
        with self._session() as s:
            product = _follow(s, s.get(product_id, for_update=True))
            if product is None:
                raise ProductNotFound(product_id)
            return _confirm(s, product, hh)

    def rekey_to_upc(self, product_id: str, upc: str, source: str, confidence: float) -> CatalogProduct:
        if not UPC_RE.match(upc):
            raise ValueError("invalid_upc")
        with self._session() as s:
            old = s.get(product_id, for_update=True)
            if old is None:
                raise ProductNotFound(product_id)
            if old.superseded_by:
                return _follow(s, old) or old
            s.lock_chain(old.store_chain_id)
            return _rekey(s, old, upc, source, confidence)

    def capture(
        self, *, store_chain_id: str, hh: str, fallback_name: str, fallback_category: str,
        upc: str | None = None, plu_code: str | None = None,
        alias_text: str | None = None, name: str | None = None, brand: str | None = None,
        category: str | None = None, unit_size: str | None = None, photo_id: str | None = None,
        previous_product_id: str | None = None, receipt_id: str | None = None, line_item_id: str | None = None,
    ) -> CaptureResult:
        with self._session() as s:
            return _capture(
                s, store_chain_id=store_chain_id, upc=upc, plu_code=plu_code, hh=hh, fallback_name=fallback_name,
                fallback_category=fallback_category, alias_text=alias_text, name=name, brand=brand,
                category=category, unit_size=unit_size, photo_id=photo_id,
                previous_product_id=previous_product_id, receipt_id=receipt_id, line_item_id=line_item_id,
            )

    def correct(
        self, *, product_id: str, hh: str, changes: dict[str, str | None], photo_id: str | None = None,
        receipt_id: str | None = None, line_item_id: str | None = None,
    ) -> CorrectionResult:
        with self._session() as s:
            return _correct(
                s, product_id=product_id, hh=hh, changes=changes, photo_id=photo_id,
                receipt_id=receipt_id, line_item_id=line_item_id,
            )

    def release_user_photo(self, photo_id: str) -> int:
        """
        REQ-RCP-021 AC5: products whose image is this user photo lose it, so
        clients fall back to the category placeholder until enrichment finds
        another image. Returns how many products changed.
        """
        with self._session() as s:
            return s.clear_image(photo_image_url(photo_id))


# ---------------------------------------------------------------------------
# In-memory backend
# ---------------------------------------------------------------------------


@dataclass
class _MemoryState:
    products: dict[str, CatalogProduct] = field(default_factory=dict)
    aliases: dict[tuple[str, str], tuple[str, int]] = field(default_factory=dict)  # → (product_id, seen_count)
    confirmations: dict[str, dict[str, datetime]] = field(default_factory=dict)  # product_id → {hash: at}
    jobs: dict[str, dict] = field(default_factory=dict)
    conflicts: list[CatalogConflict] = field(default_factory=list)


class _MemorySession:
    def __init__(self, state: _MemoryState) -> None:
        self._s = state

    def lock_chain(self, store_chain_id: str) -> None:  # the repository lock already serialises
        return None

    def get(self, product_id: str, for_update: bool = False) -> CatalogProduct | None:
        p = self._s.products.get(product_id)
        return p.model_copy() if p else None

    def get_by_upc(self, upc: str, for_update: bool = False) -> CatalogProduct | None:
        for p in self._s.products.values():
            if p.upc == upc:
                return p.model_copy()
        return None

    def insert(self, product: CatalogProduct) -> None:
        if product.id in self._s.products:
            raise ValueError(f"duplicate product {product.id}")
        if product.upc and self.get_by_upc(product.upc):
            raise ValueError(f"duplicate upc {product.upc}")
        self._s.products[product.id] = product.model_copy()

    def update(self, product: CatalogProduct) -> None:
        self._s.products[product.id] = product.model_copy()

    def touch_last_seen(self, product_id: str) -> None:
        if p := self._s.products.get(product_id):
            p.last_seen_at = _utcnow()

    def add_confirmation(self, product_id: str, hh: str) -> bool:
        bucket = self._s.confirmations.setdefault(product_id, {})
        if hh in bucket:
            return False
        bucket[hh] = _utcnow()
        return True

    def count_confirmations(self, product_id: str) -> int:
        return len(self._s.confirmations.get(product_id, {}))

    def copy_confirmations(self, from_id: str, to_id: str) -> None:
        target = self._s.confirmations.setdefault(to_id, {})
        for hh, at in self._s.confirmations.get(from_id, {}).items():
            target.setdefault(hh, at)

    def delete_confirmations(self, product_id: str) -> None:
        self._s.confirmations.pop(product_id, None)

    def upsert_alias(self, store_chain_id: str, alias: str, product_id: str) -> None:
        key = (store_chain_id, alias)
        current = self._s.aliases.get(key)
        if current is None:
            self._s.aliases[key] = (product_id, 1)
        elif current[0] == product_id:  # never re-point (§9.11)
            self._s.aliases[key] = (product_id, current[1] + 1)

    def repoint_aliases(self, from_id: str, to_id: str) -> None:
        for key, (pid, seen) in list(self._s.aliases.items()):
            if pid == from_id:
                self._s.aliases[key] = (to_id, seen)

    def find_alias(self, store_chain_id: str, alias: str) -> str | None:
        hit = self._s.aliases.get((store_chain_id, alias))
        return hit[0] if hit else None

    def queue_enrichment(self, product_id: str, trigger: str, chain: list[str]) -> str | None:
        for job in self._s.jobs.values():  # one live job per product (REQ-RCP-009 AC3)
            if job["product_id"] == product_id and job["status"] in ("queued", "running"):
                return None
        job_id = str(uuid.uuid4())
        self._s.jobs[job_id] = {"job_id": job_id, "product_id": product_id, "trigger": trigger, "chain": chain, "status": "queued"}
        return job_id

    def add_conflict(self, product_id, hh, receipt_id, line_item_id, field_name, verified_value, observed_value) -> CatalogConflict:
        conflict = CatalogConflict(
            id=str(uuid.uuid4()), product_id=product_id, field=field_name,
            verified_value=verified_value, observed_value=observed_value,
        )
        self._s.conflicts.append(conflict)
        return conflict

    def search(self, q: str, store_chain_id: str | None, status: str | None, limit: int) -> list[CatalogProduct]:
        scored: list[tuple[float, CatalogProduct]] = []
        q_tokens = set(q.split())
        for p in self._s.products.values():
            if p.superseded_by or (store_chain_id and p.store_chain_id not in (store_chain_id, "unknown")):
                continue
            if status and p.status != status:
                continue
            hay = p.normalized_name if not p.brand else f"{normalize_name(p.brand)} {p.normalized_name}"
            ratio = SequenceMatcher(None, q, hay).ratio()
            overlap = len(q_tokens & set(hay.split())) / max(1, len(q_tokens))
            score = max(ratio, overlap)
            if score >= FUZZY_CANDIDATE_THRESHOLD:
                scored.append((score, p.model_copy()))
        scored.sort(key=lambda t: (-t[0], t[1].id))
        return [p for _, p in scored[:limit]]

    def clear_image(self, image_url: str) -> int:
        changed = 0
        for p in self._s.products.values():
            if p.image_url == image_url and p.image_source == "user_photo":
                p.image_url, p.image_source = None, None
                changed += 1
        return changed


class InMemoryCatalogRepository(_BaseRepository):
    def __init__(self) -> None:
        self._state = _MemoryState()
        self._lock = threading.RLock()

    @contextmanager
    def _session(self):
        with self._lock:
            yield _MemorySession(self._state)

    # test/debug introspection
    def enrichment_jobs(self) -> list[dict]:
        return list(self._state.jobs.values())

    def conflicts(self) -> list[CatalogConflict]:
        return list(self._state.conflicts)

    def alias_target(self, store_chain_id: str, raw_text: str) -> str | None:
        hit = self._state.aliases.get((store_chain_id, normalize_name(raw_text)))
        return hit[0] if hit else None


# ---------------------------------------------------------------------------
# Postgres backend
# ---------------------------------------------------------------------------

_PRODUCT_COLS = (
    "product_id, code_kind, upc, plu_code, store_chain_id, name, normalized_name, brand, category, unit_size, "
    "image_url, image_source, source, sources_seen, confidence_score, confirmation_count, dispute_count, status, "
    "status_changed_at, origin_parse_job_id, origin_prompt_version, superseded_by, first_seen_at, last_seen_at"
)


def _row_to_product(row: dict) -> CatalogProduct:
    return CatalogProduct(
        id=row["product_id"], code_kind=row["code_kind"], upc=row["upc"], plu_code=row["plu_code"],
        store_chain_id=row["store_chain_id"], name=row["name"], normalized_name=row["normalized_name"],
        brand=row["brand"], category=row["category"], unit_size=row["unit_size"], image_url=row["image_url"],
        image_source=row["image_source"], source=row["source"], sources_seen=list(row["sources_seen"] or []),
        confidence_score=float(row["confidence_score"]), confirmation_count=row["confirmation_count"],
        dispute_count=row["dispute_count"], status=row["status"], status_changed_at=row["status_changed_at"],
        origin_parse_job_id=row["origin_parse_job_id"], origin_prompt_version=row["origin_prompt_version"],
        superseded_by=row["superseded_by"], first_seen_at=row["first_seen_at"], last_seen_at=row["last_seen_at"],
    )


class _PostgresSession:
    def __init__(self, conn) -> None:
        self._conn = conn

    def _one(self, sql: str, params: tuple) -> dict | None:
        return self._conn.execute(sql, params).fetchone()

    def lock_chain(self, store_chain_id: str) -> None:
        self._conn.execute("SELECT pg_advisory_xact_lock(hashtext(%s))", (store_chain_id,))

    def get(self, product_id: str, for_update: bool = False) -> CatalogProduct | None:
        row = self._one(
            f"SELECT {_PRODUCT_COLS} FROM products WHERE product_id = %s" + (" FOR UPDATE" if for_update else ""),
            (product_id,),
        )
        return _row_to_product(row) if row else None

    def get_by_upc(self, upc: str, for_update: bool = False) -> CatalogProduct | None:
        row = self._one(
            f"SELECT {_PRODUCT_COLS} FROM products WHERE upc = %s" + (" FOR UPDATE" if for_update else ""),
            (upc,),
        )
        return _row_to_product(row) if row else None

    def insert(self, p: CatalogProduct) -> None:
        self._conn.execute(
            f"INSERT INTO products ({_PRODUCT_COLS}) VALUES ({', '.join(['%s'] * 24)})",
            (
                p.id, p.code_kind, p.upc, p.plu_code, p.store_chain_id, p.name, p.normalized_name, p.brand,
                p.category, p.unit_size, p.image_url, p.image_source, p.source, p.sources_seen,
                p.confidence_score, p.confirmation_count, p.dispute_count, p.status, p.status_changed_at,
                p.origin_parse_job_id, p.origin_prompt_version, p.superseded_by, p.first_seen_at, p.last_seen_at,
            ),
        )

    def update(self, p: CatalogProduct) -> None:
        self._conn.execute(
            """
            UPDATE products SET name=%s, normalized_name=%s, brand=%s, category=%s, unit_size=%s,
                   image_url=%s, image_source=%s, source=%s, sources_seen=%s, confidence_score=%s,
                   confirmation_count=%s, dispute_count=%s, status=%s, status_changed_at=%s,
                   superseded_by=%s, last_seen_at=%s
             WHERE product_id=%s
            """,
            (
                p.name, p.normalized_name, p.brand, p.category, p.unit_size, p.image_url, p.image_source,
                p.source, p.sources_seen, p.confidence_score, p.confirmation_count, p.dispute_count, p.status,
                p.status_changed_at, p.superseded_by, p.last_seen_at, p.id,
            ),
        )

    def touch_last_seen(self, product_id: str) -> None:
        self._conn.execute("UPDATE products SET last_seen_at = now() WHERE product_id = %s", (product_id,))

    def add_confirmation(self, product_id: str, hh: str) -> bool:
        cur = self._conn.execute(
            "INSERT INTO product_confirmations (product_id, household_hash) VALUES (%s, %s) ON CONFLICT DO NOTHING",
            (product_id, hh),
        )
        return cur.rowcount == 1

    def count_confirmations(self, product_id: str) -> int:
        row = self._one("SELECT count(*) AS n FROM product_confirmations WHERE product_id = %s", (product_id,))
        return int(row["n"]) if row else 0

    def copy_confirmations(self, from_id: str, to_id: str) -> None:
        self._conn.execute(
            """
            INSERT INTO product_confirmations (product_id, household_hash, confirmed_at)
            SELECT %s, household_hash, confirmed_at FROM product_confirmations WHERE product_id = %s
            ON CONFLICT DO NOTHING
            """,
            (to_id, from_id),
        )

    def delete_confirmations(self, product_id: str) -> None:
        self._conn.execute("DELETE FROM product_confirmations WHERE product_id = %s", (product_id,))

    def upsert_alias(self, store_chain_id: str, alias: str, product_id: str) -> None:
        # Normalise in SQL too so the CHECK (alias = catalog_normalize_name(alias)) can never fail.
        self._conn.execute(
            """
            INSERT INTO product_aliases (store_chain_id, alias, product_id)
            VALUES (%s, catalog_normalize_name(%s), %s)
            ON CONFLICT (store_chain_id, alias) DO UPDATE
              SET seen_count = product_aliases.seen_count + 1, last_seen_at = now()
              WHERE product_aliases.product_id = EXCLUDED.product_id
            """,
            (store_chain_id, alias, product_id),
        )

    def repoint_aliases(self, from_id: str, to_id: str) -> None:
        self._conn.execute("UPDATE product_aliases SET product_id = %s WHERE product_id = %s", (to_id, from_id))

    def find_alias(self, store_chain_id: str, alias: str) -> str | None:
        row = self._one(
            "SELECT product_id FROM product_aliases WHERE store_chain_id = %s AND alias = catalog_normalize_name(%s)",
            (store_chain_id, alias),
        )
        return row["product_id"] if row else None

    def queue_enrichment(self, product_id: str, trigger: str, chain: list[str]) -> str | None:
        row = self._one(
            """
            INSERT INTO enrichment_jobs (product_id, trigger, chain) VALUES (%s, %s, %s)
            ON CONFLICT (product_id) WHERE status IN ('queued', 'running') DO NOTHING
            RETURNING job_id
            """,
            (product_id, trigger, chain),
        )
        return str(row["job_id"]) if row else None

    def add_conflict(self, product_id, hh, receipt_id, line_item_id, field_name, verified_value, observed_value) -> CatalogConflict:
        row = self._one(
            """
            INSERT INTO product_conflicts (product_id, household_hash, receipt_id, line_item_id, field, verified_value, observed_value)
            VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING conflict_id, status
            """,
            (product_id, hh, receipt_id, line_item_id, field_name, verified_value[:2048], observed_value[:2048]),
        )
        assert row is not None
        return CatalogConflict(
            id=str(row["conflict_id"]), product_id=product_id, field=field_name,
            verified_value=verified_value, observed_value=observed_value, status=row["status"],
        )

    def search(self, q: str, store_chain_id: str | None, status: str | None, limit: int) -> list[CatalogProduct]:
        rows = self._conn.execute(
            f"""
            SELECT {_PRODUCT_COLS},
                   greatest(similarity(normalized_name, %(q)s),
                            similarity(coalesce(brand, '') || ' ' || normalized_name, %(q)s),
                            word_similarity(%(q)s, normalized_name)) AS score
              FROM products
             WHERE superseded_by IS NULL
               AND (%(chain)s::text IS NULL OR store_chain_id IN (%(chain)s, 'unknown'))
               AND (%(status)s::text IS NULL OR status = %(status)s)
               AND greatest(similarity(normalized_name, %(q)s),
                            similarity(coalesce(brand, '') || ' ' || normalized_name, %(q)s),
                            word_similarity(%(q)s, normalized_name)) >= %(threshold)s
             ORDER BY score DESC, product_id
             LIMIT %(limit)s
            """,
            {"q": q, "chain": store_chain_id, "status": status, "threshold": FUZZY_CANDIDATE_THRESHOLD, "limit": limit},
        ).fetchall()
        return [_row_to_product(r) for r in rows]

    def clear_image(self, image_url: str) -> int:
        cur = self._conn.execute(
            "UPDATE products SET image_url = NULL, image_source = NULL WHERE image_url = %s AND image_source = 'user_photo'",
            (image_url,),
        )
        return cur.rowcount


class PostgresCatalogRepository(_BaseRepository):
    """Cloud SQL Postgres over the ``/cloudsql`` Unix socket (``DATABASE_URL``)."""

    def __init__(self, database_url: str, pool_size: int = 5) -> None:
        from psycopg.rows import dict_row
        from psycopg_pool import ConnectionPool

        self._pool = ConnectionPool(
            conninfo=database_url, min_size=1, max_size=max(1, pool_size), open=True,
            kwargs={"row_factory": dict_row, "autocommit": False},
        )

    @classmethod
    def from_settings(cls, settings: Settings) -> "PostgresCatalogRepository":
        assert settings.database_url, "DATABASE_URL is required for the Postgres catalog"
        return cls(settings.database_url, settings.database_pool_size)

    @contextmanager
    def _session(self):
        with self._pool.connection() as conn:
            with conn.transaction():
                yield _PostgresSession(conn)

    def close(self) -> None:
        self._pool.close()


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

_repo: CatalogRepository | None = None
_repo_key: str | None = None


def get_catalog_repository() -> CatalogRepository:
    """Process-wide catalog: Postgres when ``DATABASE_URL`` is set, else in-memory."""
    global _repo, _repo_key
    settings = get_settings()
    key = settings.database_url or "memory"
    if _repo is not None and _repo_key == key:
        return _repo
    if settings.database_url:
        _repo = PostgresCatalogRepository.from_settings(settings)
    else:
        _repo = InMemoryCatalogRepository()
    _repo_key = key
    return _repo


def reset_catalog_repository() -> None:
    """Tests: drop state, force in-memory."""
    global _repo, _repo_key
    if isinstance(_repo, PostgresCatalogRepository):
        _repo.close()
    _repo = InMemoryCatalogRepository()
    _repo_key = "memory"
