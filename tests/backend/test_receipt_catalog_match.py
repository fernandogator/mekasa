"""
Receipt scan matches the shared catalog before Open Food Facts, and inventory
capture writes the receipt text as an alias.

Satisfies: REQ-RCP-007 (Match Lines Against the Product Database) AC2, AC5;
REQ-RCP-020 (Scan and Photograph a Product When the UPC Is Not Discovered) AC6
Spec version: 1.0
"""

import io
import os
import re
from pathlib import Path
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient
from PIL import Image

os.environ["ALLOW_TEST_AUTH"] = "true"
os.environ["ENVIRONMENT"] = "test"
os.environ["HOUSEHOLD_PERSISTENCE"] = "memory"

SEED = Path(__file__).resolve().parents[2] / "backend" / "postgres" / "seed" / "store_chains.sql"


def _reset() -> None:
    from app.catalog_repository import reset_catalog_repository
    from app.config import get_settings
    from app.inventory_repository import reset_inventory_repository
    from app.item_photos import reset_item_photo_service
    from app.product_photos import reset_product_photo_service
    from app.repository import reset_household_repository
    from app.scan_events_repository import reset_scan_events_repository

    get_settings.cache_clear()
    reset_household_repository()
    reset_inventory_repository()
    reset_catalog_repository()
    reset_product_photo_service()
    reset_item_photo_service()
    reset_scan_events_repository()


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ALLOW_TEST_AUTH", "true")
    monkeypatch.setenv("HOUSEHOLD_PERSISTENCE", "memory")
    monkeypatch.setenv("RECEIPT_LLM_ENABLED", "true")
    monkeypatch.setenv("GCP_PROJECT_ID", "test-project")
    for name in ("DATABASE_URL", "PRODUCT_PHOTO_BUCKET", "ITEM_PHOTO_BUCKET"):
        monkeypatch.delenv(name, raising=False)
    _reset()
    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client
    _reset()


def _auth(uid: str = "owner-1") -> dict[str, str]:
    return {"Authorization": f"Bearer test:{uid}"}


def _household(client: TestClient, uid: str = "owner-1") -> str:
    created = client.post("/v1/households", json={"name": f"Casa {uid}"}, headers=_auth(uid))
    assert created.status_code == 201
    return created.json()["id"]


def _item(client: TestClient, hid: str, uid: str = "owner-1", **fields) -> dict:
    body = {"name": "A2 Milk Whole", "category": "Dairy", **fields}
    created = client.post(f"/v1/households/{hid}/inventory", json=body, headers=_auth(uid))
    assert created.status_code == 201
    return created.json()


def _product_photo(client: TestClient, hid: str, uid: str = "owner-1") -> str:
    out = io.BytesIO()
    Image.new("RGB", (320, 240), (20, 160, 60)).save(out, format="JPEG")
    uploaded = client.post(
        f"/v1/households/{hid}/product-photos",
        files={"file": ("p.jpg", out.getvalue(), "image/jpeg")},
        headers=_auth(uid),
    )
    assert uploaded.status_code == 201
    return uploaded.json()["photo_id"]


def _extraction(store_name: str | None, *lines: tuple[str, str, str | None]):
    from app.receipt_llm import _Extraction, _ExtractedItem

    return _Extraction(
        store_name=store_name,
        items=[
            _ExtractedItem(name=name, receipt_text=text, receipt_code=code, category="Dairy", price_paid=4.99)
            for name, text, code in lines
        ],
    )


def _scan(client: TestClient, hid: str, extraction, uid: str = "owner-1", off: AsyncMock | None = None):
    from app.models import ProductSearchResponse

    off = off or AsyncMock(return_value=ProductSearchResponse(query="x", results=[]))
    with patch("app.receipt_llm._generate", new=AsyncMock(return_value=extraction)), patch(
        "app.receipt_ocr.search_products", new=off
    ):
        scanned = client.post(
            f"/v1/households/{hid}/receipts/scan", json={"raw_text": "ignored"}, headers=_auth(uid)
        )
    assert scanned.status_code == 200, scanned.text
    return scanned.json()


def _capture(client: TestClient, hid: str, item_id: str, uid: str = "owner-1", **body):
    return client.post(f"/v1/households/{hid}/inventory/{item_id}/capture", json=body, headers=_auth(uid))


# --- store chain resolution --------------------------------------------------


@pytest.mark.parametrize(
    ("printed", "chain"),
    [
        ("H-E-B", "heb"),
        ("HEB #412", "heb"),
        ("Central Market", "heb"),
        ("WAL-MART SUPERCENTER", "walmart"),
        ("Walmart Neighborhood Market", "walmart"),
        ("Fry's Food Stores", "kroger"),
        ("COSTCO WHOLESALE #1001", "costco"),
        ("Trader Joe's", "unknown"),
        ("Targeted Deals", "unknown"),
        ("", "unknown"),
        (None, "unknown"),
    ],
)
def test_resolve_store_chain(printed: str | None, chain: str) -> None:
    from app.store_chains import resolve_store_chain

    assert resolve_store_chain(printed) == chain


def test_store_chains_mirror_seed() -> None:
    from app.store_chains import STORE_CHAINS

    seeded = set(re.findall(r"^\s*\('([a-z_]+)',", SEED.read_text(), flags=re.MULTILINE)) - {"unknown"}
    assert seeded == set(STORE_CHAINS)


def test_known_chain_falls_back_to_unknown() -> None:
    from app.store_chains import known_chain

    assert known_chain("heb") == "heb"
    assert known_chain(" HEB ") == "heb"
    assert known_chain("trader-joes") == "unknown"
    assert known_chain(None) == "unknown"


# --- capture → rescan (the user's flow) -------------------------------------


def test_capture_with_receipt_text_and_photo_matches_next_scan(client: TestClient) -> None:
    """
    Satisfies: REQ-RCP-007 AC5; REQ-RCP-020 AC6
    Spec version: 1.0

    First scan: the line is not identified. The user scans the barcode and
    takes a photo; the capture carries the receipt text and the scan's chain.
    Rescanning the same receipt then matches the product with the user photo
    without asking Open Food Facts.
    """
    hid = _household(client)
    receipt = _extraction("H-E-B #412", ("A2 Milk Whole", "A2 MLK WHL 59OZ", None))

    first = _scan(client, hid, receipt)
    assert first["store_chain_id"] == "heb"
    [line] = first["items"]
    assert line["identified"] is False and line["matched_product_id"] is None
    assert line["receipt_text"] == "A2 MLK WHL 59OZ"

    item = _item(client, hid)
    photo_id = _product_photo(client, hid)
    captured = _capture(
        client, hid, item["id"], upc="0070852993188", photo_id=photo_id,
        receipt_text=line["receipt_text"], store_chain_id=first["store_chain_id"],
    )
    assert captured.status_code == 200, captured.text
    assert captured.json()["photo_applied_as"] == "product_image"

    off = AsyncMock()
    second = _scan(client, hid, receipt, off=off)
    [matched] = second["items"]
    assert matched["identified"] is True
    assert matched["match_method"] == "alias"
    assert matched["matched_product_id"] == "0070852993188"
    assert matched["barcode"] == "0070852993188"
    assert matched["image_url"] == f"/v1/product-photos/{photo_id}"
    assert matched["name"] == "A2 Milk Whole"
    off.assert_not_awaited()


def test_alias_is_shared_with_other_households(client: TestClient) -> None:
    """
    Satisfies: REQ-RCP-007 AC5
    Spec version: 1.0
    """
    hid = _household(client)
    item = _item(client, hid)
    _capture(client, hid, item["id"], upc="0070852993188", receipt_text="A2 MLK WHL 59OZ", store_chain_id="heb")

    other = _household(client, "owner-2")
    body = _scan(client, other, _extraction("HEB", ("A2 Milk", "a2  mlk whl 59oz", None)), uid="owner-2")
    assert body["items"][0]["matched_product_id"] == "0070852993188"


def test_chain_alias_does_not_match_other_chain(client: TestClient) -> None:
    """
    Satisfies: REQ-RCP-007 AC2
    Spec version: 1.0
    """
    hid = _household(client)
    item = _item(client, hid)
    _capture(client, hid, item["id"], upc="0070852993188", receipt_text="A2 MLK WHL 59OZ", store_chain_id="heb")

    body = _scan(client, hid, _extraction("Walmart", ("A2 Milk", "A2 MLK WHL 59OZ", None)))
    assert body["store_chain_id"] == "walmart"
    assert body["items"][0]["identified"] is False


def test_unknown_chain_alias_matches_any_store(client: TestClient) -> None:
    """
    Satisfies: REQ-RCP-007 AC2, AC5; REQ-RCP-020 AC6
    Spec version: 1.0

    A capture from a receipt whose store was not recognised stores the alias
    under `unknown`, which every chain's scan also consults.
    """
    hid = _household(client)
    item = _item(client, hid)
    captured = _capture(
        client, hid, item["id"], plu_code="4011", receipt_text="BANANAS", store_chain_id="trader-joes",
    )
    assert captured.status_code == 200, captured.text

    body = _scan(client, hid, _extraction("Kroger", ("Bananas", "BANANAS", None)))
    [line] = body["items"]
    assert line["matched_product_id"] == "plu:4011"
    assert line["match_method"] == "alias"
    assert line["barcode"] is None


def test_printed_codes_match_catalog(client: TestClient) -> None:
    """
    Satisfies: REQ-RCP-007 AC5
    Spec version: 1.0
    """
    hid = _household(client)
    first = _item(client, hid)
    _capture(client, hid, first["id"], upc="0070852993188")
    second = _item(client, hid, name="Bananas", category="Produce")
    _capture(client, hid, second["id"], plu_code="4011")

    body = _scan(
        client, hid,
        _extraction(None, ("Milk", "SOMETHING ELSE", "0070852993188"), ("Bananas", "BNNS", "4011")),
    )
    assert body["store_chain_id"] == "unknown"
    assert [(i["match_method"], i["matched_product_id"]) for i in body["items"]] == [
        ("upc", "0070852993188"),
        ("plu", "plu:4011"),
    ]
    assert body["items"][1]["category"] == "Produce"


def test_capture_without_receipt_text_writes_no_alias(client: TestClient) -> None:
    """
    Satisfies: REQ-RCP-020 AC6
    Spec version: 1.0
    """
    hid = _household(client)
    item = _item(client, hid)
    _capture(client, hid, item["id"], upc="0070852993188", store_chain_id="heb")

    body = _scan(client, hid, _extraction("HEB", ("A2 Milk Whole", "A2 MLK WHL 59OZ", None)))
    assert body["items"][0]["identified"] is False


def test_off_hit_reports_method(client: TestClient) -> None:
    """
    Satisfies: REQ-RCP-007 AC5
    Spec version: 1.0
    """
    from app.models import ProductSearchHit, ProductSearchResponse

    hid = _household(client)
    off = AsyncMock(
        return_value=ProductSearchResponse(
            query="x",
            results=[ProductSearchHit(barcode="012345678905", name="A2 Milk Whole", category="Dairy")],
        )
    )
    body = _scan(client, hid, _extraction(None, ("A2 Milk Whole", "A2 MLK WHL", None)), off=off)
    assert body["items"][0]["match_method"] == "open_food_facts"
    assert body["items"][0]["matched_product_id"] is None


def test_catalog_failure_falls_back_to_off(client: TestClient) -> None:
    """
    Satisfies: REQ-RCP-007 AC5
    Spec version: 1.0
    """
    hid = _household(client)
    with patch("app.receipt_ocr.match_catalog", side_effect=RuntimeError("db down")):
        body = _scan(client, hid, _extraction("HEB", ("A2 Milk Whole", "A2 MLK WHL", None)))
    assert body["items"][0]["identified"] is False
    assert body["items"][0]["image_url"]
