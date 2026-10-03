"""Shared per-store item tables: receipt lines + discovered UPCs + manual scans.

Every household's receipt scans add rows to a store's table, shared across all
users and kept in Postgres (Cloud SQL). A confirmed manual barcode scan is
compared against the household's most recent receipt: a name / code match
attaches the UPC to that receipt line, otherwise the scan becomes its own row
for that store. Writes for one store run in a transaction under a per-store lock.
"""

from __future__ import annotations

import logging
import re
from collections.abc import Iterator
from contextlib import AbstractContextManager, contextmanager
from datetime import datetime, timezone
from pathlib import Path
from threading import Lock, RLock
from typing import Protocol
from uuid import uuid4

from app.barcode_codes import candidates, digits_only, is_valid_gtin
from app.models import (
    ReceiptLineItem,
    StoreCatalogItem,
    StoreCatalogSummary,
    StoreCodeSource,
    StoreItemCode,
)
from app.receipt_ocr import is_strong_match

logger = logging.getLogger(__name__)

UNKNOWN_STORE_ID = "unknown-store"
UNKNOWN_STORE_NAME = "Unknown store"


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _slug(value: str, limit: int = 100) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.casefold()).strip("-")[:limit]


def store_id_for(store_name: str | None) -> str:
    """Stable store key from the printed store brand ("Walmart #1234" → walmart)."""
    cleaned = re.sub(r"#\s*\d+", "", store_name or "")
    return _slug(cleaned, 60) or UNKNOWN_STORE_ID


def store_item_id_for(line: ReceiptLineItem) -> str:
    """Row id of a receipt line in its store's table (from the printed text)."""
    return _slug(line.receipt_text or line.name) or _slug(line.name)


def _code_kind(code: str) -> str:
    return "upc" if is_valid_gtin(code) or len(code) in (8, 12, 13, 14) else "sku"


def _same_code(left: str, right: str) -> bool:
    if left == right:
        return True
    if _code_kind(left) != "upc" or _code_kind(right) != "upc":
        return False
    return bool(set(candidates(left)) & set(candidates(right)))


def _has_code(item: StoreCatalogItem, code: str) -> bool:
    return any(_same_code(existing.code, code) for existing in item.codes)


def _has_source(item: StoreCatalogItem, source: StoreCodeSource) -> bool:
    return any(source in code.sources for code in item.codes)


def _add_code(item: StoreCatalogItem, raw_code: str, source: StoreCodeSource, now: datetime) -> None:
    code = digits_only(raw_code)
    if not code:
        return
    for existing in item.codes:
        if _same_code(existing.code, code):
            if source not in existing.sources:
                existing.sources.append(source)
            existing.seen_count += 1
            existing.last_seen = now
            return
    item.codes.append(
        StoreItemCode(
            code=code,
            kind=_code_kind(code),
            sources=[source],
            first_seen=now,
            last_seen=now,
        )
    )


def _status(item: StoreCatalogItem) -> str:
    has_manual = _has_source(item, "manual_scan")
    has_other = any(
        "receipt" in code.sources or "catalog" in code.sources for code in item.codes
    )
    if not has_manual:
        return "receipt_only"
    if any(
        "manual_scan" in code.sources and len(code.sources) > 1 for code in item.codes
    ):
        return "confirmed"
    return "conflict" if has_other else "manual_only"


class StoreCatalogSession(Protocol):
    """Reads and writes inside one transaction."""

    def lock_store(self, store_id: str) -> None: ...

    def upsert_store(self, store_id: str, name: str, address: str | None, now: datetime) -> None: ...

    def get_item(self, store_id: str, item_id: str) -> StoreCatalogItem | None: ...

    def put_item(self, item: StoreCatalogItem) -> None: ...

    def get_latest_receipt(self, household_id: str) -> tuple[str, list[str]] | None: ...

    def set_latest_receipt(
        self, household_id: str, store_id: str, item_ids: list[str], now: datetime
    ) -> None: ...

    def add_photo(self, photo: Photo) -> None: ...


class StoreCatalogRepository(Protocol):
    def transaction(self) -> AbstractContextManager[StoreCatalogSession]: ...

    def list_stores(self) -> list[StoreCatalogSummary]: ...

    def get_store(self, store_id: str) -> StoreCatalogSummary | None: ...

    def list_items(self, store_id: str) -> list[StoreCatalogItem]: ...

    def get_photo(self, photo_id: str) -> Photo | None: ...

    def save_photo(self, photo: Photo) -> None: ...


class Photo:
    """A user photo (JPEG / PNG / HEIC bytes), optionally tied to a store row."""

    __slots__ = ("id", "store_id", "item_id", "household_id", "content_type", "data", "created_at")

    def __init__(
        self,
        *,
        id: str,
        household_id: str,
        content_type: str,
        data: bytes,
        created_at: datetime,
        store_id: str | None = None,
        item_id: str | None = None,
    ) -> None:
        self.id = id
        self.store_id = store_id
        self.item_id = item_id
        self.household_id = household_id
        self.content_type = content_type
        self.data = data
        self.created_at = created_at


class InMemoryStoreCatalogRepository:
    """Process-local store tables (tests + local runs without DATABASE_URL)."""

    def __init__(self) -> None:
        self._lock = RLock()
        self._stores: dict[str, StoreCatalogSummary] = {}
        self._items: dict[str, dict[str, StoreCatalogItem]] = {}
        self._latest: dict[str, tuple[str, list[str]]] = {}
        self._photos: dict[str, Photo] = {}

    @contextmanager
    def transaction(self) -> Iterator[InMemoryStoreCatalogRepository]:
        with self._lock:
            yield self

    def lock_store(self, store_id: str) -> None:
        """The transaction already holds the repository lock."""

    def upsert_store(self, store_id: str, name: str, address: str | None, now: datetime) -> None:
        store = self._stores.get(store_id)
        if store is None:
            self._stores[store_id] = StoreCatalogSummary(
                id=store_id, name=name, address=address, updated_at=now
            )
        else:
            store.address = store.address or address
            store.updated_at = now

    def get_item(self, store_id: str, item_id: str) -> StoreCatalogItem | None:
        item = self._items.get(store_id, {}).get(item_id)
        return item.model_copy(deep=True) if item else None

    def put_item(self, item: StoreCatalogItem) -> None:
        self._items.setdefault(item.store_id, {})[item.id] = item.model_copy(deep=True)

    def get_latest_receipt(self, household_id: str) -> tuple[str, list[str]] | None:
        return self._latest.get(household_id)

    def set_latest_receipt(
        self, household_id: str, store_id: str, item_ids: list[str], now: datetime
    ) -> None:
        self._latest[household_id] = (store_id, list(item_ids))

    def add_photo(self, photo: Photo) -> None:
        self._photos[photo.id] = photo

    def save_photo(self, photo: Photo) -> None:
        with self._lock:
            self.add_photo(photo)

    def get_photo(self, photo_id: str) -> Photo | None:
        with self._lock:
            return self._photos.get(photo_id)

    def list_stores(self) -> list[StoreCatalogSummary]:
        with self._lock:
            return [self._summary(store) for store in self._stores.values()]

    def get_store(self, store_id: str) -> StoreCatalogSummary | None:
        with self._lock:
            store = self._stores.get(store_id)
            return self._summary(store) if store else None

    def _summary(self, store: StoreCatalogSummary) -> StoreCatalogSummary:
        return store.model_copy(update={"item_count": len(self._items.get(store.id, {}))})

    def list_items(self, store_id: str) -> list[StoreCatalogItem]:
        with self._lock:
            return [item.model_copy(deep=True) for item in self._items.get(store_id, {}).values()]


_SCHEMA_PATH = Path(__file__).with_name("store_catalog.sql")
# Arbitrary constant key so concurrent instances apply the schema one at a time.
_SCHEMA_LOCK_KEY = 7_262_751


class _PostgresSession:
    def __init__(self, conn) -> None:
        self._conn = conn

    def lock_store(self, store_id: str) -> None:
        self._conn.execute("SELECT pg_advisory_xact_lock(hashtext(%s))", (store_id,))

    def upsert_store(self, store_id: str, name: str, address: str | None, now: datetime) -> None:
        self._conn.execute(
            """
            INSERT INTO stores (id, name, address, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (id) DO UPDATE SET
                address = COALESCE(stores.address, EXCLUDED.address),
                updated_at = EXCLUDED.updated_at
            """,
            (store_id, name, address, now, now),
        )

    def get_item(self, store_id: str, item_id: str) -> StoreCatalogItem | None:
        row = self._conn.execute(
            f"SELECT {_ITEM_COLUMNS} FROM store_items WHERE store_id = %s AND id = %s",
            (store_id, item_id),
        ).fetchone()
        if row is None:
            return None
        return _item_from_row(row, _codes_for(self._conn, store_id, [item_id]).get(item_id, []))

    def put_item(self, item: StoreCatalogItem) -> None:
        self._conn.execute(
            """
            INSERT INTO store_items
                (store_id, id, receipt_text, name, category, last_price, status, photo_id,
                 updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (store_id, id) DO UPDATE SET
                receipt_text = EXCLUDED.receipt_text,
                name = EXCLUDED.name,
                category = EXCLUDED.category,
                last_price = EXCLUDED.last_price,
                status = EXCLUDED.status,
                photo_id = EXCLUDED.photo_id,
                updated_at = EXCLUDED.updated_at
            """,
            (
                item.store_id,
                item.id,
                item.receipt_text,
                item.name,
                item.category,
                item.last_price,
                item.status,
                item.photo_id,
                item.updated_at,
            ),
        )
        self._conn.execute(
            "DELETE FROM store_item_codes WHERE store_id = %s AND item_id = %s",
            (item.store_id, item.id),
        )
        if item.codes:
            with self._conn.cursor() as cur:
                cur.executemany(
                    """
                    INSERT INTO store_item_codes
                        (store_id, item_id, code, kind, sources, seen_count, first_seen, last_seen)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    [
                        (
                            item.store_id,
                            item.id,
                            code.code,
                            code.kind,
                            list(code.sources),
                            code.seen_count,
                            code.first_seen,
                            code.last_seen,
                        )
                        for code in item.codes
                    ],
                )

    def get_latest_receipt(self, household_id: str) -> tuple[str, list[str]] | None:
        row = self._conn.execute(
            "SELECT store_id, item_ids FROM household_latest_receipts WHERE household_id = %s",
            (household_id,),
        ).fetchone()
        return (row[0], list(row[1])) if row else None

    def set_latest_receipt(
        self, household_id: str, store_id: str, item_ids: list[str], now: datetime
    ) -> None:
        self._conn.execute(
            """
            INSERT INTO household_latest_receipts (household_id, store_id, item_ids, scanned_at)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (household_id) DO UPDATE SET
                store_id = EXCLUDED.store_id,
                item_ids = EXCLUDED.item_ids,
                scanned_at = EXCLUDED.scanned_at
            """,
            (household_id, store_id, item_ids, now),
        )

    def add_photo(self, photo: Photo) -> None:
        self._conn.execute(
            """
            INSERT INTO photos
                (id, store_id, item_id, content_type, data, household_id, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            """,
            (
                photo.id,
                photo.store_id,
                photo.item_id,
                photo.content_type,
                photo.data,
                photo.household_id,
                photo.created_at,
            ),
        )


_ITEM_COLUMNS = (
    "id, store_id, receipt_text, name, category, last_price::float8, status, "
    "photo_id::text, updated_at"
)
_STORE_SUMMARY_SQL = """
    SELECT s.id, s.name, s.address, s.updated_at,
           (SELECT count(*) FROM store_items i WHERE i.store_id = s.id)
    FROM stores s
"""


def _item_from_row(row, codes: list[StoreItemCode]) -> StoreCatalogItem:
    item_id, store_id, receipt_text, name, category, last_price, status, photo_id, updated_at = row
    return StoreCatalogItem(
        id=item_id,
        store_id=store_id,
        receipt_text=receipt_text,
        name=name,
        category=category,
        last_price=last_price,
        status=status,
        photo_id=photo_id,
        updated_at=updated_at,
        codes=codes,
    )


def _summary_from_row(row) -> StoreCatalogSummary:
    store_id, name, address, updated_at, item_count = row
    return StoreCatalogSummary(
        id=store_id, name=name, address=address, updated_at=updated_at, item_count=item_count
    )


def _codes_for(conn, store_id: str, item_ids: list[str] | None) -> dict[str, list[StoreItemCode]]:
    sql = (
        "SELECT item_id, code, kind, sources, seen_count, first_seen, last_seen "
        "FROM store_item_codes WHERE store_id = %s"
    )
    params: tuple = (store_id,)
    if item_ids is not None:
        sql += " AND item_id = ANY(%s)"
        params = (store_id, item_ids)
    codes: dict[str, list[StoreItemCode]] = {}
    for item_id, code, kind, sources, seen_count, first_seen, last_seen in conn.execute(
        sql + " ORDER BY first_seen, code", params
    ):
        codes.setdefault(item_id, []).append(
            StoreItemCode(
                code=code,
                kind=kind,
                sources=list(sources),
                seen_count=seen_count,
                first_seen=first_seen,
                last_seen=last_seen,
            )
        )
    return codes


class PostgresStoreCatalogRepository:
    """Shared store tables in Postgres; schema in ``store_catalog.sql``."""

    def __init__(self, database_url: str, *, max_size: int = 5) -> None:
        from psycopg_pool import ConnectionPool

        self._pool = ConnectionPool(
            database_url, min_size=1, max_size=max_size, open=True, name="store-catalog"
        )
        self.apply_schema()

    def apply_schema(self) -> None:
        with self._pool.connection() as conn:
            conn.execute("SELECT pg_advisory_xact_lock(%s)", (_SCHEMA_LOCK_KEY,))
            conn.execute(_SCHEMA_PATH.read_text())

    def close(self) -> None:
        self._pool.close()

    @contextmanager
    def transaction(self) -> Iterator[_PostgresSession]:
        # pool.connection() commits on success and rolls back on error.
        with self._pool.connection() as conn:
            yield _PostgresSession(conn)

    def list_stores(self) -> list[StoreCatalogSummary]:
        with self._pool.connection() as conn:
            return [_summary_from_row(row) for row in conn.execute(_STORE_SUMMARY_SQL)]

    def get_store(self, store_id: str) -> StoreCatalogSummary | None:
        with self._pool.connection() as conn:
            row = conn.execute(_STORE_SUMMARY_SQL + " WHERE s.id = %s", (store_id,)).fetchone()
        return _summary_from_row(row) if row else None

    def list_items(self, store_id: str) -> list[StoreCatalogItem]:
        with self._pool.connection() as conn:
            codes = _codes_for(conn, store_id, None)
            rows = conn.execute(
                f"SELECT {_ITEM_COLUMNS} FROM store_items WHERE store_id = %s", (store_id,)
            ).fetchall()
        return [_item_from_row(row, codes.get(row[0], [])) for row in rows]

    def save_photo(self, photo: Photo) -> None:
        with self._pool.connection() as conn:
            _PostgresSession(conn).add_photo(photo)

    def get_photo(self, photo_id: str) -> Photo | None:
        with self._pool.connection() as conn:
            row = conn.execute(
                """
                SELECT id::text, store_id, item_id, household_id, content_type, data, created_at
                FROM photos WHERE id = %s::uuid
                """,
                (photo_id,),
            ).fetchone()
        if row is None:
            return None
        return Photo(
            id=row[0],
            store_id=row[1],
            item_id=row[2],
            household_id=row[3],
            content_type=row[4],
            data=bytes(row[5]),
            created_at=row[6],
        )


def record_receipt(
    repo: StoreCatalogRepository,
    household_id: str,
    *,
    store_name: str | None,
    store_address: str | None,
    items: list[ReceiptLineItem],
) -> str:
    """
    Satisfies: REQ-005
    Add every scanned receipt line (and its printed / catalog-matched UPCs) to
    the store's table, and remember it as the household's latest receipt.
    """
    now = _utcnow()
    store_id = store_id_for(store_name)
    item_ids: list[str] = []
    with repo.transaction() as tx:
        tx.lock_store(store_id)
        tx.upsert_store(store_id, store_name or UNKNOWN_STORE_NAME, store_address, now)
        for line in items:
            text = line.receipt_text or line.name
            item_id = store_item_id_for(line)
            if not item_id or item_id in item_ids:
                continue
            row = tx.get_item(store_id, item_id)
            if row is None:
                row = StoreCatalogItem(
                    id=item_id,
                    store_id=store_id,
                    receipt_text=text,
                    name=line.name,
                    category=line.category,
                    updated_at=now,
                )
            elif line.identified:
                row.name, row.category = line.name, line.category
            if line.price_paid is not None:
                row.last_price = line.price_paid
            if line.receipt_code:
                _add_code(row, line.receipt_code, "receipt", now)
            if line.identified and line.barcode:
                _add_code(row, line.barcode, "catalog", now)
            row.status = _status(row)
            row.updated_at = now
            tx.put_item(row)
            item_ids.append(item_id)
        tx.set_latest_receipt(household_id, store_id, item_ids, now)
    return store_id


def _match_receipt_line(
    rows: list[StoreCatalogItem], barcode: str, name: str
) -> StoreCatalogItem | None:
    for row in rows:
        if _has_code(row, barcode):
            return row
    # Lines no manual scan has claimed yet win over already-scanned ones.
    ordered = sorted(rows, key=lambda row: _has_source(row, "manual_scan"))
    for row in ordered:
        if is_strong_match(name, row.name) or (
            row.receipt_text and is_strong_match(name, row.receipt_text)
        ):
            return row
    return None


def record_manual_scan(
    repo: StoreCatalogRepository,
    household_id: str,
    *,
    barcode: str,
    name: str,
    category: str,
) -> StoreCatalogItem | None:
    """
    Satisfies: REQ-004
    Compare a confirmed manual barcode scan with the household's latest receipt
    and record it in that store's table (matched line or a new row).
    """
    code = digits_only(barcode)
    if not code:
        return None
    now = _utcnow()
    with repo.transaction() as tx:
        store_id, item_ids = tx.get_latest_receipt(household_id) or (UNKNOWN_STORE_ID, [])
        tx.lock_store(store_id)
        tx.upsert_store(store_id, UNKNOWN_STORE_NAME, None, now)
        rows = [row for row in (tx.get_item(store_id, item_id) for item_id in item_ids) if row]
        row = _match_receipt_line(rows, code, name)
        if row is None:
            row_id = f"upc-{code}"
            row = tx.get_item(store_id, row_id) or StoreCatalogItem(
                id=row_id,
                store_id=store_id,
                name=name,
                category=category,
                updated_at=now,
            )
        _add_code(row, code, "manual_scan", now)
        row.status = _status(row)
        row.updated_at = now
        tx.put_item(row)
    return row


def record_capture(
    repo: StoreCatalogRepository,
    household_id: str,
    *,
    store_id: str,
    item_id: str,
    barcode: str | None,
    photo: tuple[str, bytes] | None,
) -> StoreCatalogItem:
    """
    Satisfies: REQ-004, REQ-005
    In-store capture for a receipt line the catalog could not identify: the
    user scans the item's barcode (or types its PLU) and/or photographs it.
    Raises KeyError when the store row does not exist.
    """
    now = _utcnow()
    with repo.transaction() as tx:
        tx.lock_store(store_id)
        row = tx.get_item(store_id, item_id)
        if row is None:
            raise KeyError(item_id)
        if barcode:
            _add_code(row, barcode, "manual_scan", now)
        if photo is not None:
            content_type, data = photo
            photo_id = str(uuid4())
            tx.add_photo(
                Photo(
                    id=photo_id,
                    store_id=store_id,
                    item_id=item_id,
                    household_id=household_id,
                    content_type=content_type,
                    data=data,
                    created_at=now,
                )
            )
            row.photo_id = photo_id
        row.status = _status(row)
        row.updated_at = now
        tx.put_item(row)
    return row


_repo: StoreCatalogRepository | None = None
_repo_url: str | None = None
_repo_lock = Lock()


def get_store_catalog_repository() -> StoreCatalogRepository:
    """Postgres when DATABASE_URL is set, else process memory."""
    global _repo, _repo_url
    from app.config import get_settings

    settings = get_settings()
    url = settings.database_url or None
    with _repo_lock:
        if _repo is not None and _repo_url == url:
            return _repo
        if isinstance(_repo, PostgresStoreCatalogRepository):
            _repo.close()
        if url:
            _repo = PostgresStoreCatalogRepository(url, max_size=settings.database_pool_size)
        else:
            if settings.environment == "prod":
                logger.warning("DATABASE_URL is not set; store tables are in memory only")
            _repo = InMemoryStoreCatalogRepository()
        _repo_url = url
        return _repo


def reset_store_catalog_repository() -> None:
    global _repo, _repo_url
    with _repo_lock:
        if isinstance(_repo, PostgresStoreCatalogRepository):
            _repo.close()
        _repo = None
        _repo_url = None
