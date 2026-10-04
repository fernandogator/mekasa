"""
Product capture from an inventory item.

Satisfies: REQ-RCP-020 (Scan and Photograph a Product When the UPC Is Not Discovered)
Acceptance criteria: AC2, AC4, AC5, AC6, AC7
Spec version: 1.0
"""

import io
import os

import pytest
from fastapi.testclient import TestClient
from PIL import Image

os.environ["ALLOW_TEST_AUTH"] = "true"
os.environ["ENVIRONMENT"] = "test"
os.environ["HOUSEHOLD_PERSISTENCE"] = "memory"


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
    body = {"name": "Cucumbers", "category": "Produce", **fields}
    created = client.post(f"/v1/households/{hid}/inventory", json=body, headers=_auth(uid))
    assert created.status_code == 201
    return created.json()


def _jpeg() -> bytes:
    out = io.BytesIO()
    Image.new("RGB", (320, 240), (20, 160, 60)).save(out, format="JPEG")
    return out.getvalue()


def _product_photo(client: TestClient, hid: str, uid: str = "owner-1") -> str:
    uploaded = client.post(
        f"/v1/households/{hid}/product-photos",
        files={"file": ("p.jpg", _jpeg(), "image/jpeg")},
        headers=_auth(uid),
    )
    assert uploaded.status_code == 201
    return uploaded.json()["photo_id"]


def _capture(client: TestClient, hid: str, item_id: str, body: dict, uid: str = "owner-1"):
    return client.post(f"/v1/households/{hid}/inventory/{item_id}/capture", json=body, headers=_auth(uid))


def _events(hid: str):
    from app.scan_events_repository import get_scan_events_repository

    return get_scan_events_repository().list_events(hid)


def test_upc_capture_creates_the_product_and_links_the_item(client: TestClient) -> None:
    """AC2, AC4, AC6: new user_scan product; item gets barcode + product_id; scan event written."""
    hid = _household(client)
    item = _item(client, hid)
    response = _capture(client, hid, item["id"], {"upc": "033383000014", "name": "English Cucumber"})
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["outcome"] == "created"
    assert body["product"]["id"] == "033383000014" and body["product"]["code_kind"] == "upc"
    assert body["product"]["name"] == "English Cucumber" and body["product"]["category"] == "Produce"
    assert body["product"]["source"] == "user_scan" and body["product"]["confidence_score"] == 0.9
    assert body["enrichment_job_id"] and body["confirmation_counted"] is True
    assert body["inventory_item_id"] == item["id"]
    assert body["inventory_item"]["barcode"] == "033383000014"
    assert body["inventory_item"]["product_id"] == "033383000014"

    stored = client.get(f"/v1/households/{hid}/inventory/{item['id']}", headers=_auth()).json()
    assert stored["barcode"] == "033383000014" and stored["product_id"] == "033383000014"

    [event] = _events(hid)
    assert event.id == body["scan_event_id"]
    assert (event.context, event.outcome, event.upc, event.inventory_item_id) == (
        "inventory_capture", "created", "033383000014", item["id"],
    )


def test_second_household_links_and_shares_its_photo(client: TestClient) -> None:
    """AC5: the capture photo becomes the product image when it has none; outcome linked → scan found."""
    first = _household(client)
    _capture(client, first, _item(client, first)["id"], {"upc": "033383000014"})

    second = _household(client, uid="neighbor")
    item = _item(client, second, uid="neighbor")
    photo_id = _product_photo(client, second, uid="neighbor")
    body = _capture(client, second, item["id"], {"upc": "033383000014", "photo_id": photo_id}, uid="neighbor").json()

    assert body["outcome"] == "linked" and body["photo_applied_as"] == "product_image"
    assert body["product"]["image_url"] == f"/v1/product-photos/{photo_id}"
    assert body["product"]["confirmation_count"] == 2
    assert body["inventory_item"]["image_url"] == f"/v1/product-photos/{photo_id}"
    assert _events(second)[0].outcome == "found"

    from app.product_photos import get_product_photo_service

    assert get_product_photo_service().owned_by(second, photo_id).expires_at is None


def test_plu_capture_links_the_shared_produce_product(client: TestClient) -> None:
    """AC7: plu:<code>, shared chain, no barcode written to the item, never verified."""
    hid = _household(client)
    item = _item(client, hid, name="Bananas")
    body = _capture(client, hid, item["id"], {"plu_code": "4011"}).json()
    assert body["outcome"] == "created"
    product = body["product"]
    assert (product["id"], product["code_kind"], product["plu_code"], product["upc"]) == ("plu:4011", "plu", "4011", None)
    assert product["store_chain_id"] == "unknown" and product["status"] == "unverified"
    assert body["enrichment_job_id"] is None
    assert body["inventory_item"]["product_id"] == "plu:4011"
    assert body["inventory_item"]["barcode"] is None
    assert _events(hid)[0].plu_code == "4011"


@pytest.mark.parametrize(
    ("body", "detail"),
    [
        ({}, "exactly_one_code_required"),
        ({"upc": "033383000014", "plu_code": "4011"}, "exactly_one_code_required"),
        ({"upc": "12ab"}, "invalid_upc"),
        ({"upc": "1234567"}, "invalid_upc"),
        ({"plu_code": "401"}, "invalid_plu"),
        ({"upc": "033383000014", "photo_id": "not-a-uuid"}, "unknown_photo_id"),
    ],
)
def test_capture_rejects_bad_codes_and_photos(client: TestClient, body: dict, detail: str) -> None:
    hid = _household(client)
    item = _item(client, hid)
    response = _capture(client, hid, item["id"], body)
    assert response.status_code == 400 and response.json()["detail"] == detail
    assert _events(hid) == []


def test_photo_from_another_household_is_rejected(client: TestClient) -> None:
    hid = _household(client)
    other = _household(client, uid="neighbor")
    foreign_photo = _product_photo(client, other, uid="neighbor")
    response = _capture(client, hid, _item(client, hid)["id"], {"upc": "033383000014", "photo_id": foreign_photo})
    assert response.status_code == 400 and response.json()["detail"] == "unknown_photo_id"


def test_capture_requires_membership_and_an_existing_item(client: TestClient) -> None:
    hid = _household(client)
    item = _item(client, hid)
    assert _capture(client, hid, item["id"], {"upc": "033383000014"}, uid="stranger").status_code == 403
    assert _capture(client, hid, "missing-item", {"upc": "033383000014"}).status_code == 404
    assert client.post(f"/v1/households/{hid}/inventory/{item['id']}/capture", json={"upc": "033383000014"}).status_code in (401, 403)


def test_capture_photo_replaces_and_deletes_a_private_item_photo(client: TestClient) -> None:
    """REQ-INV-019 AC4 still holds: the replaced private photo is removed."""
    from app.item_photos import get_item_photo_service

    hid = _household(client)
    private = client.post(
        f"/v1/households/{hid}/item-photos", files={"file": ("i.jpg", _jpeg(), "image/jpeg")}, headers=_auth()
    ).json()
    item = _item(client, hid, image_url=private["url"])
    photo_id = _product_photo(client, hid)

    body = _capture(client, hid, item["id"], {"upc": "033383000014", "photo_id": photo_id}).json()
    assert body["inventory_item"]["image_url"] == f"/v1/product-photos/{photo_id}"
    assert get_item_photo_service().fetch(hid, private["photo_id"]) is None


def test_capture_without_photo_keeps_the_items_own_picture(client: TestClient) -> None:
    hid = _household(client)
    other = _household(client, uid="neighbor")
    photo_id = _product_photo(client, other, uid="neighbor")
    _capture(client, other, _item(client, other, uid="neighbor")["id"], {"upc": "033383000014", "photo_id": photo_id}, uid="neighbor")

    own = _item(client, hid, image_url="https://images.openfoodfacts.org/cucumber.jpg")
    kept = _capture(client, hid, own["id"], {"upc": "033383000014"}).json()
    assert kept["inventory_item"]["image_url"] == "https://images.openfoodfacts.org/cucumber.jpg"

    from app.category_icons import category_placeholder_url

    placeholder = _item(client, hid, name="Cucumber 2", image_url=category_placeholder_url("Produce"))
    upgraded = _capture(client, hid, placeholder["id"], {"upc": "033383000014"}).json()
    assert upgraded["inventory_item"]["image_url"] == f"/v1/product-photos/{photo_id}"
