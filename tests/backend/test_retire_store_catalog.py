"""
Retirement of the prototype per-store Postgres tables (PR #106).

Satisfies: NFR-002 AC1, REQ-005 AC2, REQ-RCP-020 AC1
Spec version: 1.0

The API no longer creates tables at startup, the prototype routes are gone,
and the receipt-scan response keeps only the printed ``store_name`` for the
in-store capture guidance. The migration round-trip runs only when
``TEST_DATABASE_URL`` points at a scratch database.
"""

from __future__ import annotations

import base64
import os
from pathlib import Path
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

os.environ["ALLOW_TEST_AUTH"] = "true"
os.environ["ENVIRONMENT"] = "test"
os.environ["HOUSEHOLD_PERSISTENCE"] = "memory"

REPO_ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS = REPO_ROOT / "backend" / "postgres" / "migrations"
TEST_DATABASE_URL = os.environ.get("TEST_DATABASE_URL")
PROTOTYPE_TABLES = ("stores", "store_items", "store_item_codes", "photos", "household_latest_receipts")


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ALLOW_TEST_AUTH", "true")
    monkeypatch.setenv("HOUSEHOLD_PERSISTENCE", "memory")
    monkeypatch.setenv("RECEIPT_LLM_ENABLED", "true")
    monkeypatch.setenv("GCP_PROJECT_ID", "test-project")
    monkeypatch.delenv("DATABASE_URL", raising=False)
    from app.config import get_settings
    from app.repository import reset_household_repository

    get_settings.cache_clear()
    reset_household_repository()

    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client

    get_settings.cache_clear()
    reset_household_repository()


def _auth(uid: str = "owner-1") -> dict[str, str]:
    return {"Authorization": f"Bearer test:{uid}"}


def _household(client: TestClient) -> str:
    created = client.post("/v1/households", json={"name": "Casa Retire"}, headers=_auth())
    assert created.status_code == 201
    return created.json()["id"]


def _extraction():
    from app.receipt_llm import _Extraction, _ExtractedItem

    return _Extraction(
        store_name="Walmart #1234",
        store_address="100 Main St",
        items=[
            _ExtractedItem(
                name="Great Value Chocolate Chip Cookies",
                receipt_text="GV CHOC CHP CKY",
                category="Pantry",
                price_paid=2.18,
            )
        ],
    )


def test_receipt_scan_keeps_store_name_but_no_prototype_ids(client: TestClient) -> None:
    """
    Satisfies: REQ-005 AC2, REQ-RCP-020 AC1
    Spec version: 1.0
    """
    from app.models import ProductSearchResponse

    household_id = _household(client)
    with patch("app.receipt_llm._generate", new=AsyncMock(return_value=_extraction())), patch(
        "app.receipt_ocr.search_products",
        new=AsyncMock(return_value=ProductSearchResponse(query="x", results=[])),
    ):
        scanned = client.post(
            f"/v1/households/{household_id}/receipts/scan",
            json={"image_base64": base64.b64encode(b"\x89PNGfake").decode()},
            headers=_auth(),
        )
    assert scanned.status_code == 200
    body = scanned.json()
    assert body["store_name"] == "Walmart #1234"
    assert "store_id" not in body
    assert body["items"][0]["identified"] is False
    assert "store_item_id" not in body["items"][0]


def test_prototype_routes_are_gone(client: TestClient) -> None:
    """
    Satisfies: NFR-002 AC1
    Spec version: 1.0

    The public-by-id photo route and the per-store tables are not served;
    household photos are only reachable through the private item-photo GET.
    """
    household_id = _household(client)
    assert client.get("/v1/store-catalogs", headers=_auth()).status_code == 404
    assert client.get("/v1/store-catalogs/walmart/items", headers=_auth()).status_code == 404
    assert (
        client.get("/v1/photos/6f1c2d4e-8a3b-4c5d-9e7f-0a1b2c3d4e5f").status_code == 404
    )
    legacy_upload = client.post(
        f"/v1/households/{household_id}/photos",
        files={"file": ("x.jpg", b"\xff\xd8\xff", "image/jpeg")},
        headers=_auth(),
    )
    assert legacy_upload.status_code == 404
    capture = client.post(
        f"/v1/households/{household_id}/store-catalogs/walmart/items/gv-choc/capture",
        data={"barcode": "012345678905"},
        headers=_auth(),
    )
    assert capture.status_code == 404


def test_app_has_no_store_catalog_module() -> None:
    """
    Satisfies: NFR-002 AC1
    Spec version: 1.0
    """
    assert not (REPO_ROOT / "backend" / "app" / "store_catalog.py").exists()
    assert not (REPO_ROOT / "backend" / "app" / "store_catalog.sql").exists()
    with pytest.raises(ModuleNotFoundError):
        __import__("app.store_catalog")


def _table_names(conn) -> set[str]:
    rows = conn.execute(
        "SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename = ANY(%s)",
        (list(PROTOTYPE_TABLES),),
    ).fetchall()
    return {row[0] for row in rows}


@pytest.mark.skipif(not TEST_DATABASE_URL, reason="TEST_DATABASE_URL not set")
def test_migration_0003_drops_prototype_tables_and_rolls_back() -> None:
    """
    Satisfies: NFR-002 AC1
    Spec version: 1.0

    down → tables exist (empty); up → gone; up again → still idempotent.
    """
    import psycopg

    up = (MIGRATIONS / "0003_retire_store_catalog_prototype.sql").read_text()
    down = (MIGRATIONS / "0003_retire_store_catalog_prototype.down.sql").read_text()
    with psycopg.connect(TEST_DATABASE_URL, autocommit=True) as conn:
        conn.execute(down)
        assert _table_names(conn) == set(PROTOTYPE_TABLES)
        conn.execute(
            "INSERT INTO stores (id, name, created_at, updated_at) VALUES ('walmart', 'Walmart', now(), now())"
        )
        conn.execute(up)
        assert _table_names(conn) == set()
        conn.execute(up)
        assert _table_names(conn) == set()
        conn.execute(down)
        assert _table_names(conn) == set(PROTOTYPE_TABLES)
        assert conn.execute("SELECT count(*) FROM stores").fetchone()[0] == 0
        conn.execute(up)
        assert _table_names(conn) == set()
