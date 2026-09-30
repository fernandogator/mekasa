"""Tests for the shared per-store item / UPC table (REQ-004, REQ-005)."""

import os
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

os.environ["ALLOW_TEST_AUTH"] = "true"
os.environ["ENVIRONMENT"] = "test"
os.environ["HOUSEHOLD_PERSISTENCE"] = "memory"

MILK_UPC = "041220576037"
BREAD_PRINTED = "007874237003"


def _reset_schema(database_url: str) -> None:
    import psycopg

    with psycopg.connect(database_url) as conn:
        conn.execute(
            "DROP TABLE IF EXISTS household_latest_receipts, photos, store_item_codes, "
            "store_items, stores CASCADE"
        )


@pytest.fixture(params=["memory", "postgres"])
def client(request: pytest.FixtureRequest, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ALLOW_TEST_AUTH", "true")
    monkeypatch.setenv("HOUSEHOLD_PERSISTENCE", "memory")
    monkeypatch.setenv("RECEIPT_LLM_ENABLED", "true")
    monkeypatch.setenv("GCP_PROJECT_ID", "test-project")
    if request.param == "postgres":
        # Scratch database only (tables are dropped): TEST_DATABASE_URL=postgresql://…
        database_url = os.environ.get("TEST_DATABASE_URL")
        if not database_url:
            pytest.skip("TEST_DATABASE_URL not set")
        _reset_schema(database_url)
        monkeypatch.setenv("DATABASE_URL", database_url)
    else:
        monkeypatch.delenv("DATABASE_URL", raising=False)
    from app.config import get_settings
    from app.repository import reset_household_repository
    from app.store_catalog import reset_store_catalog_repository

    get_settings.cache_clear()
    reset_household_repository()
    reset_store_catalog_repository()

    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client

    get_settings.cache_clear()
    reset_household_repository()
    reset_store_catalog_repository()


def _auth(uid: str = "owner-1") -> dict[str, str]:
    return {"Authorization": f"Bearer test:{uid}"}


def _household(client: TestClient) -> str:
    created = client.post("/v1/households", json={"name": "Casa Store"}, headers=_auth())
    assert created.status_code == 201
    return created.json()["id"]


def _extraction():
    from app.receipt_llm import _Extraction, _ExtractedItem

    return _Extraction(
        store_name="Walmart #1234",
        store_address="100 Main St",
        items=[
            _ExtractedItem(
                name="Great Value Whole Milk 1 Gallon",
                receipt_text="GV WHL MLK 1GAL",
                receipt_code=MILK_UPC,
                category="Dairy",
                price_paid=3.49,
            ),
            _ExtractedItem(
                name="Great Value Chocolate Chip Cookies",
                receipt_text="GV CHOC CHP CKY",
                category="Pantry",
                price_paid=2.18,
            ),
            _ExtractedItem(
                name="Great Value White Bread",
                receipt_text="GV WHT BRD",
                receipt_code=BREAD_PRINTED,
                category="Pantry",
                price_paid=1.42,
            ),
        ],
    )


async def _fake_search(query: str, *, limit: int = 8, client=None):
    from app.models import ProductSearchHit, ProductSearchResponse

    if "milk" in query.casefold():
        return ProductSearchResponse(
            query=query,
            results=[
                ProductSearchHit(
                    barcode=MILK_UPC,
                    name="Great Value Whole Milk 1 Gallon",
                    brand="Great Value",
                    category="Dairy",
                    image_url="https://images.openfoodfacts.org/milk.jpg",
                    source="openfoodfacts",
                )
            ],
        )
    return ProductSearchResponse(query=query, results=[])


def _scan_receipt(client: TestClient, household_id: str) -> dict:
    with patch("app.receipt_llm._generate", new=AsyncMock(return_value=_extraction())), patch(
        "app.receipt_ocr.search_products", new=AsyncMock(side_effect=_fake_search)
    ):
        scanned = client.post(
            f"/v1/households/{household_id}/receipts/scan",
            json={"image_base64": "aGVsbG8="},
            headers=_auth(),
        )
    assert scanned.status_code == 200
    return scanned.json()


def _manual_scan(client: TestClient, household_id: str, name: str, barcode: str) -> None:
    created = client.post(
        f"/v1/households/{household_id}/inventory",
        json={"name": name, "category": "Pantry", "barcode": barcode, "source": "barcode"},
        headers=_auth(),
    )
    assert created.status_code == 201


def _rows(client: TestClient, store_id: str) -> dict[str, dict]:
    listed = client.get(f"/v1/store-catalogs/{store_id}/items", headers=_auth())
    assert listed.status_code == 200
    return {row["id"]: row for row in listed.json()["items"]}


def test_receipt_scan_fills_store_table_with_upcs(client: TestClient) -> None:
    """
    Satisfies: REQ-005
    Spec version: 1.0
    """
    household_id = _household(client)
    body = _scan_receipt(client, household_id)
    assert body["store_id"] == "walmart"
    assert body["store_name"] == "Walmart #1234"

    stores = client.get("/v1/store-catalogs", headers=_auth()).json()["stores"]
    assert [(store["id"], store["item_count"]) for store in stores] == [("walmart", 3)]
    assert stores[0]["address"] == "100 Main St"

    rows = _rows(client, "walmart")
    milk = rows["gv-whl-mlk-1gal"]
    assert milk["receipt_text"] == "GV WHL MLK 1GAL"
    assert milk["status"] == "receipt_only"
    assert milk["last_price"] == 3.49
    assert [(code["code"], code["kind"], sorted(code["sources"])) for code in milk["codes"]] == [
        (MILK_UPC, "upc", ["catalog", "receipt"])
    ]
    assert rows["gv-choc-chp-cky"]["codes"] == []


def test_manual_scans_are_compared_with_latest_receipt(client: TestClient) -> None:
    """
    Satisfies: REQ-004, REQ-005
    Spec version: 1.0
    """
    household_id = _household(client)
    _scan_receipt(client, household_id)

    # Same UPC as printed / catalog → confirmed.
    _manual_scan(client, household_id, "Whole Milk", MILK_UPC)
    # No code on the receipt line → attached by name.
    _manual_scan(client, household_id, "Great Value Chocolate Chip Cookies 13 oz", "078742370545")
    # Name matches but the printed code differs → conflict.
    _manual_scan(client, household_id, "Great Value White Bread", "078742012345")
    # Not on the receipt → its own row for the store.
    _manual_scan(client, household_id, "Tide Pods", "037000930389")

    rows = _rows(client, "walmart")
    assert rows["gv-whl-mlk-1gal"]["status"] == "confirmed"
    assert sorted(rows["gv-whl-mlk-1gal"]["codes"][0]["sources"]) == [
        "catalog",
        "manual_scan",
        "receipt",
    ]

    cookies = rows["gv-choc-chp-cky"]
    assert cookies["status"] == "manual_only"
    assert [code["code"] for code in cookies["codes"]] == ["078742370545"]

    bread = rows["gv-wht-brd"]
    assert bread["status"] == "conflict"
    assert {code["code"] for code in bread["codes"]} == {BREAD_PRINTED, "078742012345"}

    tide = rows["upc-037000930389"]
    assert tide["status"] == "manual_only"
    assert tide["receipt_text"] is None
    assert tide["name"] == "Tide Pods"

    store = client.get("/v1/store-catalogs", headers=_auth()).json()["stores"][0]
    assert store["item_count"] == 4


def test_manual_scan_without_receipt_goes_to_unknown_store(client: TestClient) -> None:
    household_id = _household(client)
    _manual_scan(client, household_id, "Tide Pods", "037000930389")
    rows = _rows(client, "unknown-store")
    assert rows["upc-037000930389"]["status"] == "manual_only"


def test_store_table_is_shared_across_households(client: TestClient) -> None:
    household_id = _household(client)
    _scan_receipt(client, household_id)
    other = client.get("/v1/store-catalogs/walmart/items", headers=_auth("someone-else"))
    assert other.status_code == 200
    assert len(other.json()["items"]) == 3
    missing = client.get("/v1/store-catalogs/nope/items", headers=_auth())
    assert missing.status_code == 404


def test_receipt_lines_carry_store_item_ids(client: TestClient) -> None:
    household_id = _household(client)
    body = _scan_receipt(client, household_id)
    assert [item["store_item_id"] for item in body["items"]] == [
        "gv-whl-mlk-1gal",
        "gv-choc-chp-cky",
        "gv-wht-brd",
    ]
    assert [item["identified"] for item in body["items"]] == [True, False, False]


def test_capture_adds_scan_and_photo_to_unidentified_line(client: TestClient) -> None:
    """
    Satisfies: REQ-004, REQ-005
    Spec version: 1.0
    """
    household_id = _household(client)
    _scan_receipt(client, household_id)
    jpeg = b"\xff\xd8\xff\xe0fake-jpeg"

    captured = client.post(
        f"/v1/households/{household_id}/store-catalogs/walmart/items/gv-choc-chp-cky/capture",
        data={"barcode": "078742370545"},
        files={"photo": ("item.jpg", jpeg, "image/jpeg")},
        headers=_auth(),
    )
    assert captured.status_code == 200, captured.text
    item = captured.json()
    assert item["status"] == "manual_only"
    assert [code["code"] for code in item["codes"]] == ["078742370545"]
    assert item["photo_url"].startswith("http://testserver/v1/photos/")

    photo = client.get(item["photo_url"].removeprefix("http://testserver"))
    assert photo.status_code == 200
    assert photo.content == jpeg
    assert photo.headers["content-type"] == "image/jpeg"

    listed = _rows(client, "walmart")["gv-choc-chp-cky"]
    assert listed["photo_url"] == item["photo_url"]


def test_capture_photo_only_for_produce_without_barcode(client: TestClient) -> None:
    household_id = _household(client)
    _scan_receipt(client, household_id)
    captured = client.post(
        f"/v1/households/{household_id}/store-catalogs/walmart/items/gv-wht-brd/capture",
        files={"photo": ("item.png", b"\x89PNGfake", "image/png")},
        headers=_auth(),
    )
    assert captured.status_code == 200
    assert captured.json()["photo_url"]
    assert captured.json()["status"] == "receipt_only"


def test_capture_validation(client: TestClient) -> None:
    household_id = _household(client)
    _scan_receipt(client, household_id)
    base = f"/v1/households/{household_id}/store-catalogs/walmart/items"
    empty = client.post(f"{base}/gv-wht-brd/capture", data={}, headers=_auth())
    assert empty.status_code == 400
    missing = client.post(f"{base}/nope/capture", data={"barcode": "123"}, headers=_auth())
    assert missing.status_code == 404
    outsider = client.post(
        f"{base}/gv-wht-brd/capture", data={"barcode": "123"}, headers=_auth("stranger")
    )
    assert outsider.status_code == 403
    not_image = client.post(
        f"{base}/gv-wht-brd/capture",
        files={"photo": ("x.txt", b"hello", "text/plain")},
        headers=_auth(),
    )
    assert not_image.status_code == 400


def test_upload_own_item_photo(client: TestClient) -> None:
    household_id = _household(client)
    uploaded = client.post(
        f"/v1/households/{household_id}/photos",
        files={"file": ("mine.jpg", b"\xff\xd8\xffmine", "image/jpeg")},
        headers=_auth(),
    )
    assert uploaded.status_code == 201
    url = uploaded.json()["url"]
    assert client.get(url.removeprefix("http://testserver")).content == b"\xff\xd8\xffmine"

    outsider = client.post(
        f"/v1/households/{household_id}/photos",
        files={"file": ("mine.jpg", b"\xff\xd8\xff", "image/jpeg")},
        headers=_auth("stranger"),
    )
    assert outsider.status_code == 403
    assert client.get("/v1/photos/not-a-uuid").status_code == 404
