"""
Shared product photos for the capture flow.

Satisfies: REQ-RCP-021 (Product Photo Upload and Storage)
Acceptance criteria: AC1, AC2, AC3, AC5, AC6
Spec version: 1.0
"""

import base64
import io
import os
from uuid import UUID

import pytest
from fastapi.testclient import TestClient
from PIL import Image

os.environ["ALLOW_TEST_AUTH"] = "true"
os.environ["ENVIRONMENT"] = "test"
os.environ["HOUSEHOLD_PERSISTENCE"] = "memory"


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ALLOW_TEST_AUTH", "true")
    monkeypatch.setenv("HOUSEHOLD_PERSISTENCE", "memory")
    monkeypatch.delenv("PRODUCT_PHOTO_BUCKET", raising=False)
    monkeypatch.delenv("DATABASE_URL", raising=False)
    from app.catalog_repository import reset_catalog_repository
    from app.config import get_settings
    from app.product_photos import reset_product_photo_service
    from app.repository import reset_household_repository

    get_settings.cache_clear()
    reset_household_repository()
    reset_product_photo_service()
    reset_catalog_repository()

    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client

    get_settings.cache_clear()
    reset_household_repository()
    reset_product_photo_service()
    reset_catalog_repository()


def _auth(uid: str = "owner-1") -> dict[str, str]:
    return {"Authorization": f"Bearer test:{uid}"}


def _household(client: TestClient, uid: str = "owner-1") -> str:
    created = client.post("/v1/households", json={"name": f"Casa {uid}"}, headers=_auth(uid))
    assert created.status_code == 201
    return created.json()["id"]


def _jpeg(width: int = 2400, height: int = 1200) -> bytes:
    image = Image.new("RGB", (width, height), (30, 120, 200))
    exif = Image.Exif()
    exif[0x0110] = "Test Phone"
    out = io.BytesIO()
    image.save(out, format="JPEG", exif=exif.tobytes())
    return out.getvalue()


def _upload(client: TestClient, household_id: str, data: bytes, uid: str = "owner-1", mime: str = "image/jpeg"):
    return client.post(
        f"/v1/households/{household_id}/product-photos",
        files={"file": ("product.jpg", data, mime)},
        headers=_auth(uid),
    )


def test_multipart_upload_reencodes_and_returns_stable_url(client: TestClient) -> None:
    """AC1: JPEG out, EXIF gone, long edge ≤ 1600, UUID v4 id, /v1/product-photos/{id}."""
    hid = _household(client)
    response = _upload(client, hid, _jpeg())
    assert response.status_code == 201
    body = response.json()
    assert UUID(body["photo_id"]).version == 4
    assert body["image_url"] == f"/v1/product-photos/{body['photo_id']}"
    assert (body["width"], body["height"]) == (1600, 800)
    assert body["bytes"] > 0
    assert body["expires_at"] is not None

    fetched = client.get(body["image_url"], headers=_auth())
    assert fetched.status_code == 200
    assert fetched.headers["cache-control"] == "private, max-age=600"
    image = Image.open(io.BytesIO(fetched.content))
    assert image.format == "JPEG" and image.size == (1600, 800)
    assert not image.getexif()


def test_json_base64_upload(client: TestClient) -> None:
    hid = _household(client)
    payload = {"image_base64": base64.b64encode(_jpeg(300, 200)).decode(), "content_type": "image/jpeg"}
    response = client.post(f"/v1/households/{hid}/product-photos", json=payload, headers=_auth())
    assert response.status_code == 201
    assert (response.json()["width"], response.json()["height"]) == (300, 200)

    bad = client.post(f"/v1/households/{hid}/product-photos", json={"image_base64": "@@not base64@@"}, headers=_auth())
    assert bad.status_code == 400 and bad.json()["detail"] == "invalid_base64"


def test_object_name_and_record_carry_no_household_in_the_shared_path(client: TestClient) -> None:
    """AC2: bytes at product-photos/{id}.jpg; ownership only under the household."""
    from app.product_photos import get_product_photo_service

    hid = _household(client)
    photo_id = _upload(client, hid, _jpeg(200, 200)).json()["photo_id"]
    service = get_product_photo_service()
    assert service.store.object_names() == [f"product-photos/{photo_id}.jpg"]
    record = service.owned_by(hid, photo_id)
    assert record is not None and record.uploaded_by_uid == "owner-1"
    assert service.owned_by("someone-else", photo_id) is None


def test_any_signed_in_user_can_view_but_only_members_upload(client: TestClient) -> None:
    """AC3: viewing needs a token from any household; upload needs membership."""
    hid = _household(client)
    image_url = _upload(client, hid, _jpeg(200, 200)).json()["image_url"]
    _household(client, uid="neighbor")

    assert client.get(image_url, headers=_auth("neighbor")).status_code == 200
    assert client.get(image_url).status_code in (401, 403)
    assert _upload(client, hid, _jpeg(200, 200), uid="neighbor").status_code == 403
    assert _upload(client, "missing-household", _jpeg(200, 200)).status_code == 404
    assert client.get("/v1/product-photos/not-a-uuid", headers=_auth()).status_code == 404
    assert client.get("/v1/product-photos/6f1c2d4e-8a3b-4c5d-9e7f-0a1b2c3d4e5f", headers=_auth()).status_code == 404


def test_rejects_non_images_and_oversize(client: TestClient) -> None:
    """AC6: rejected, never truncated."""
    hid = _household(client)
    assert _upload(client, hid, b"plain text", mime="text/plain").status_code == 415
    assert _upload(client, hid, b"not really a jpeg").status_code == 415
    too_big = _upload(client, hid, b"\xff" * (8 * 1024 * 1024 + 1))
    assert too_big.status_code == 413 and too_big.json()["detail"] == "payload_too_large"
    raw = client.post(
        f"/v1/households/{hid}/product-photos", content=b"x", headers={**_auth(), "content-type": "application/octet-stream"}
    )
    assert raw.status_code == 415


def test_delete_by_uploader_removes_photo_and_catalog_image(client: TestClient) -> None:
    """AC5: only the uploading household deletes; products using it lose the image."""
    from app.catalog_repository import get_catalog_repository, household_hash

    hid = _household(client)
    other = _household(client, uid="neighbor")
    photo_id = _upload(client, hid, _jpeg(200, 200)).json()["photo_id"]
    catalog = get_catalog_repository()
    created = catalog.capture(
        store_chain_id="heb", upc="041220576037", hh=household_hash(hid),
        fallback_name="Chips", fallback_category="Pantry", photo_id=photo_id,
    )
    assert created.product.image_url == f"/v1/product-photos/{photo_id}"

    assert client.delete(f"/v1/households/{other}/product-photos/{photo_id}", headers=_auth("neighbor")).status_code == 404
    assert client.delete(f"/v1/households/{hid}/product-photos/{photo_id}", headers=_auth("neighbor")).status_code == 403

    assert client.delete(f"/v1/households/{hid}/product-photos/{photo_id}", headers=_auth()).status_code == 204
    assert client.get(f"/v1/product-photos/{photo_id}", headers=_auth()).status_code == 404
    product = catalog.get_product("041220576037")
    assert product.image_url is None and product.image_source is None
    assert client.delete(f"/v1/households/{hid}/product-photos/{photo_id}", headers=_auth()).status_code == 404


def test_gcs_store_redirects_to_a_short_lived_signed_url() -> None:
    """AC3 with Cloud Storage: V4 signed URL, ≤ 15 minutes, signed through IAM."""
    from datetime import timedelta

    from app.product_photos import GcsProductPhotoStore, PhotoRedirect

    calls: dict = {}

    class FakeBlob:
        def __init__(self, name: str, present: bool) -> None:
            self.name, self.present = name, present

        def exists(self) -> bool:
            return self.present

        def generate_signed_url(self, **kwargs) -> str:
            calls.update(kwargs, name=self.name)
            return "https://storage.googleapis.com/signed?X-Goog-Expires=900"

    class FakeBucket:
        def blob(self, name: str) -> FakeBlob:
            return FakeBlob(name, present=name.endswith("present.jpg"))

    store = GcsProductPhotoStore.__new__(GcsProductPhotoStore)
    store._bucket = FakeBucket()
    store._signer = lambda: ("mekasa-api@example.iam.gserviceaccount.com", "token-123")

    resolved = store.resolve("present")
    assert isinstance(resolved, PhotoRedirect)
    assert calls["name"] == "product-photos/present.jpg"
    assert calls["version"] == "v4" and calls["method"] == "GET"
    assert calls["expiration"] <= timedelta(minutes=15)
    assert calls["service_account_email"].endswith("iam.gserviceaccount.com")
    assert store.resolve("missing") is None
