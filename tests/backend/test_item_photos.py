"""
Household-private item photos.

Satisfies: REQ-INV-019 (Replace an Item Picture With a Private Photo)
Acceptance criteria: AC1, AC3, AC4, AC5, AC6, AC7
Spec version: 1.0
"""

import io
import os

import pytest
from fastapi.testclient import TestClient
from PIL import Image
from PIL.TiffImagePlugin import IFDRational

os.environ["ALLOW_TEST_AUTH"] = "true"
os.environ["ENVIRONMENT"] = "test"
os.environ["HOUSEHOLD_PERSISTENCE"] = "memory"


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ALLOW_TEST_AUTH", "true")
    monkeypatch.setenv("HOUSEHOLD_PERSISTENCE", "memory")
    monkeypatch.delenv("ITEM_PHOTO_BUCKET", raising=False)
    from app.config import get_settings
    from app.item_photos import reset_item_photo_service
    from app.repository import reset_household_repository

    get_settings.cache_clear()
    reset_household_repository()
    reset_item_photo_service()

    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client

    get_settings.cache_clear()
    reset_household_repository()
    reset_item_photo_service()


def _auth(uid: str = "owner-1") -> dict[str, str]:
    return {"Authorization": f"Bearer test:{uid}"}


def _household(client: TestClient, uid: str = "owner-1") -> str:
    created = client.post("/v1/households", json={"name": "Casa Fotos"}, headers=_auth(uid))
    assert created.status_code == 201
    return created.json()["id"]


def _jpeg(width: int = 2400, height: int = 1200, with_exif: bool = True) -> bytes:
    image = Image.new("RGB", (width, height), (200, 40, 30))
    out = io.BytesIO()
    if with_exif:
        exif = Image.Exif()
        exif[0x0110] = "Test Phone"  # Model
        gps = exif.get_ifd(0x8825)
        gps[1] = "N"
        gps[2] = (IFDRational(29, 1), IFDRational(45, 1), IFDRational(0, 1))
        image.save(out, format="JPEG", exif=exif.tobytes())
        reloaded = Image.open(io.BytesIO(out.getvalue())).getexif()
        assert reloaded[0x0110] == "Test Phone", "fixture must carry EXIF"
    else:
        image.save(out, format="JPEG")
    return out.getvalue()


def _png_rgba() -> bytes:
    image = Image.new("RGBA", (120, 80), (0, 120, 60, 128))
    out = io.BytesIO()
    image.save(out, format="PNG")
    return out.getvalue()


def _upload(client: TestClient, household_id: str, data: bytes, uid: str = "owner-1", **kw):
    return client.post(
        f"/v1/households/{household_id}/item-photos",
        files={"file": (kw.get("name", "item.jpg"), data, kw.get("mime", "image/jpeg"))},
        headers=_auth(uid),
    )


def test_upload_reencodes_strips_metadata_and_caps_size(client: TestClient) -> None:
    """AC1: JPEG out, metadata gone, long edge ≤ 1600."""
    household_id = _household(client)
    response = _upload(client, household_id, _jpeg())
    assert response.status_code == 201
    body = response.json()
    assert body["url"] == f"http://testserver/v1/households/{household_id}/item-photos/{body['photo_id']}"

    fetched = client.get(body["url"].removeprefix("http://testserver"), headers=_auth())
    assert fetched.status_code == 200
    assert fetched.headers["content-type"] == "image/jpeg"
    assert fetched.headers["cache-control"].startswith("private")
    image = Image.open(io.BytesIO(fetched.content))
    assert image.format == "JPEG"
    assert max(image.size) == 1600
    assert image.size == (1600, 800)
    assert not image.getexif(), "EXIF/GPS must be stripped"
    assert "exif" not in image.info


def test_png_with_alpha_is_flattened_to_jpeg(client: TestClient) -> None:
    household_id = _household(client)
    response = _upload(client, household_id, _png_rgba(), name="item.png", mime="image/png")
    assert response.status_code == 201
    fetched = client.get(response.json()["url"].removeprefix("http://testserver"), headers=_auth())
    image = Image.open(io.BytesIO(fetched.content))
    assert image.format == "JPEG"
    assert image.mode == "RGB"
    assert image.size == (120, 80)


def test_only_household_members_can_upload_or_view(client: TestClient) -> None:
    """AC3: outsiders get 403 for both upload and fetch; bearer is required."""
    household_id = _household(client)
    uploaded = _upload(client, household_id, _jpeg(400, 300)).json()
    path = uploaded["url"].removeprefix("http://testserver")

    assert _upload(client, household_id, _jpeg(400, 300), uid="stranger").status_code == 403
    assert client.get(path, headers=_auth("stranger")).status_code == 403
    assert client.get(path).status_code in (401, 403)
    assert client.get(path, headers=_auth()).status_code == 200

    # A member of another household cannot read it through their own household id.
    other = _household(client, uid="neighbor")
    assert (
        client.get(
            f"/v1/households/{other}/item-photos/{uploaded['photo_id']}", headers=_auth("neighbor")
        ).status_code
        == 404
    )


def test_rejects_non_images_and_oversize(client: TestClient) -> None:
    """AC1 limits: 415 for non-images, 413 past 8 MB."""
    household_id = _household(client)
    assert _upload(client, household_id, b"hello", name="x.txt", mime="text/plain").status_code == 415
    assert _upload(client, household_id, b"not really a jpeg", mime="image/jpeg").status_code == 415
    big = b"\xff\xd8" + b"\x00" * (8 * 1024 * 1024 + 1)
    assert _upload(client, household_id, big).status_code == 413


def test_patch_image_url_replaces_and_deletes_previous_private_photo(client: TestClient) -> None:
    """AC4: swapping to a new private photo removes the old object."""
    household_id = _household(client)
    item = client.post(
        f"/v1/households/{household_id}/inventory",
        json={"name": "Oat Milk", "category": "Dairy", "quantity": 1, "source": "manual"},
        headers=_auth(),
    ).json()

    first = _upload(client, household_id, _jpeg(300, 300)).json()
    second = _upload(client, household_id, _jpeg(300, 300)).json()
    first_path = first["url"].removeprefix("http://testserver")
    second_path = second["url"].removeprefix("http://testserver")

    patched = client.patch(
        f"/v1/households/{household_id}/inventory/{item['id']}",
        json={"image_url": first["url"]},
        headers=_auth(),
    )
    assert patched.status_code == 200
    assert patched.json()["image_url"] == first["url"]
    assert client.get(first_path, headers=_auth()).status_code == 200

    patched = client.patch(
        f"/v1/households/{household_id}/inventory/{item['id']}",
        json={"image_url": second["url"]},
        headers=_auth(),
    )
    assert patched.status_code == 200
    assert patched.json()["image_url"] == second["url"]
    assert client.get(first_path, headers=_auth()).status_code == 404, "old photo deleted"
    assert client.get(second_path, headers=_auth()).status_code == 200

    # Patching other fields leaves the photo alone.
    client.patch(
        f"/v1/households/{household_id}/inventory/{item['id']}",
        json={"quantity": 3},
        headers=_auth(),
    )
    assert client.get(second_path, headers=_auth()).status_code == 200


def test_delete_photo_then_refresh_falls_back_to_placeholder(client: TestClient) -> None:
    """AC5: after DELETE the item's next refresh-image gets a category placeholder."""
    household_id = _household(client)
    item = client.post(
        f"/v1/households/{household_id}/inventory",
        json={"name": "Bananas", "category": "Produce", "quantity": 3, "source": "manual"},
        headers=_auth(),
    ).json()
    photo = _upload(client, household_id, _jpeg(300, 300)).json()
    client.patch(
        f"/v1/households/{household_id}/inventory/{item['id']}",
        json={"image_url": photo["url"]},
        headers=_auth(),
    )

    delete_path = f"/v1/households/{household_id}/item-photos/{photo['photo_id']}"
    assert client.delete(delete_path, headers=_auth("stranger")).status_code == 403
    assert client.delete(delete_path, headers=_auth()).status_code == 204
    assert client.delete(delete_path, headers=_auth()).status_code == 404
    assert client.get(photo["url"].removeprefix("http://testserver"), headers=_auth()).status_code == 404

    refreshed = client.post(
        f"/v1/households/{household_id}/inventory/{item['id']}/refresh-image",
        headers=_auth(),
    )
    assert refreshed.status_code == 200
    assert refreshed.json()["image_url"] != photo["url"]
    assert refreshed.json()["image_url"]


def test_private_photo_url_parsing_is_strict() -> None:
    """AC6 guard: only our own household-scoped URLs are recognised for cleanup."""
    from app.item_photos import ItemPhotoRef, parse_item_photo_url

    pid = "0b5c7e4e-7f3e-4d0c-9c1e-6d2b8a9f1c22"
    ref = parse_item_photo_url(f"https://api.example.com/v1/households/h-1/item-photos/{pid}")
    assert ref == ItemPhotoRef(household_id="h-1", photo_id=pid)
    assert ref.object_name == f"households/h-1/item-photos/{pid}.jpg"
    assert parse_item_photo_url(f"/v1/households/h-1/item-photos/{pid}") == ref
    assert parse_item_photo_url(f"/v1/households/h-1/item-photos/{pid}?x=1") == ref

    assert parse_item_photo_url(None) is None
    assert parse_item_photo_url("https://images.openfoodfacts.org/x.jpg") is None
    assert parse_item_photo_url("/v1/photos/" + pid) is None
    assert parse_item_photo_url("/v1/product-photos/" + pid) is None
    assert parse_item_photo_url("/v1/households/h-1/item-photos/not-a-uuid") is None


def test_delete_if_owned_ignores_other_households() -> None:
    """AC4/AC6: a household can only clean up its own objects."""
    from app.item_photos import InMemoryItemPhotoStore, ItemPhotoRef, ItemPhotoService

    store = InMemoryItemPhotoStore()
    service = ItemPhotoService(store)
    mine = ItemPhotoRef("h-1", "0b5c7e4e-7f3e-4d0c-9c1e-6d2b8a9f1c22")
    theirs = ItemPhotoRef("h-2", "1b5c7e4e-7f3e-4d0c-9c1e-6d2b8a9f1c22")
    store.put(mine, b"a")
    store.put(theirs, b"b")

    assert service.delete_if_owned("h-1", theirs.url_path()) is False
    assert service.delete_if_owned("h-1", "https://images.openfoodfacts.org/x.jpg") is False
    assert store.object_names() == [mine.object_name, theirs.object_name]
    assert service.delete_if_owned("h-1", "https://host" + mine.url_path()) is True
    assert store.object_names() == [theirs.object_name]
