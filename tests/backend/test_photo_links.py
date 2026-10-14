"""
Signed photo links with a per-instance cache.

Satisfies: REQ-023 (Signed Photo Links With a Server-Side Cache)
Acceptance criteria: AC1, AC2, AC3, AC4, AC5, AC6
Spec version: 1.0
"""

import io
import logging
import os
from datetime import datetime, timedelta, timezone
from uuid import uuid4

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
    monkeypatch.delenv("ITEM_PHOTO_BUCKET", raising=False)
    monkeypatch.delenv("PRODUCT_PHOTO_BUCKET", raising=False)
    monkeypatch.delenv("DATABASE_URL", raising=False)
    from app.catalog_repository import reset_catalog_repository
    from app.config import get_settings
    from app.item_photos import reset_item_photo_service
    from app.product_photos import reset_product_photo_service
    from app.repository import reset_household_repository

    def reset() -> None:
        get_settings.cache_clear()
        reset_household_repository()
        reset_item_photo_service()
        reset_product_photo_service()
        reset_catalog_repository()

    reset()
    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client
    reset()


def _auth(uid: str = "owner-1") -> dict[str, str]:
    return {"Authorization": f"Bearer test:{uid}"}


def _household(client: TestClient, uid: str = "owner-1") -> str:
    created = client.post("/v1/households", json={"name": f"Casa {uid}"}, headers=_auth(uid))
    assert created.status_code == 201
    return created.json()["id"]


def _jpeg() -> bytes:
    out = io.BytesIO()
    Image.new("RGB", (64, 48), (90, 111, 79)).save(out, format="JPEG")
    return out.getvalue()


def _item_photo_path(client: TestClient, hid: str, uid: str = "owner-1") -> str:
    uploaded = client.post(
        f"/v1/households/{hid}/item-photos",
        files={"file": ("item.jpg", _jpeg(), "image/jpeg")},
        headers=_auth(uid),
    )
    assert uploaded.status_code == 201
    return f"/v1/households/{hid}/item-photos/{uploaded.json()['photo_id']}"


def _product_photo_path(client: TestClient, hid: str, uid: str = "owner-1") -> str:
    uploaded = client.post(
        f"/v1/households/{hid}/product-photos",
        files={"file": ("product.jpg", _jpeg(), "image/jpeg")},
        headers=_auth(uid),
    )
    assert uploaded.status_code == 201
    return uploaded.json()["image_url"]


def _links(client: TestClient, hid: str, photos: list[str], uid: str = "owner-1"):
    return client.post(f"/v1/households/{hid}/photo-links", json={"photos": photos}, headers=_auth(uid))


def test_local_links_are_the_api_paths_and_missing_photos_are_null(client: TestClient) -> None:
    """AC1, AC6: item and product paths resolve; unknown photos map to null."""
    hid = _household(client)
    item = _item_photo_path(client, hid)
    product = _product_photo_path(client, hid)
    missing = f"/v1/product-photos/{uuid4()}"

    response = _links(client, hid, [item, product, missing])

    assert response.status_code == 200
    links = response.json()["links"]
    assert links[item] == {"url": item, "expires_at": None}
    assert links[product] == {"url": product, "expires_at": None}
    assert links[missing] is None


def test_other_households_item_photos_are_null_but_product_photos_are_shared(client: TestClient) -> None:
    """AC2: item photos stay household-private; any product photo is allowed."""
    mine = _household(client, "owner-1")
    theirs = _household(client, "owner-2")
    their_item = _item_photo_path(client, theirs, "owner-2")
    their_product = _product_photo_path(client, theirs, "owner-2")

    links = _links(client, mine, [their_item, their_product]).json()["links"]

    assert links[their_item] is None
    assert links[their_product] is not None


def test_non_members_get_403_and_unknown_households_404(client: TestClient) -> None:
    """AC2: membership is checked on every call."""
    hid = _household(client, "owner-1")
    item = _item_photo_path(client, hid)

    assert _links(client, hid, [item], uid="stranger").status_code == 403
    assert _links(client, "no-such-household", [item]).status_code == 404
    assert client.post(f"/v1/households/{hid}/photo-links", json={"photos": [item]}).status_code == 401


def test_too_many_or_malformed_paths_return_400(client: TestClient) -> None:
    """AC1: at most 100 paths, each one of the two photo path shapes."""
    hid = _household(client)
    too_many = [f"/v1/product-photos/{uuid4()}" for _ in range(101)]

    assert _links(client, hid, too_many).status_code == 400
    assert _links(client, hid, ["https://example.com/cat.jpg"]).status_code == 400
    assert _links(client, hid, [f"/v1/households/{hid}/item-photos/not-a-uuid"]).status_code == 400
    assert _links(client, hid, [f"/v1/product-photos/{uuid4()}"] * 100).status_code == 200


def test_each_call_logs_one_photo_links_line(client: TestClient, caplog: pytest.LogCaptureFixture) -> None:
    """AC5: requested / cached / signed / missing counts."""
    hid = _household(client)
    item = _item_photo_path(client, hid)
    caplog.set_level(logging.INFO, logger="app.photo_links")

    _links(client, hid, [item, f"/v1/product-photos/{uuid4()}"])

    lines = [r for r in caplog.records if getattr(r, "event", None) == "photo_links"]
    assert len(lines) == 1
    assert lines[0].fields == {"requested": 2, "cached": 0, "signed": 0, "missing": 1}


class _Clock:
    def __init__(self) -> None:
        self.now = datetime(2026, 10, 14, 12, 0, tzinfo=timezone.utc)

    def __call__(self) -> datetime:
        return self.now


class _FakeBlob:
    def __init__(self, bucket: "_FakeBucket", name: str) -> None:
        self.bucket, self.name = bucket, name

    def exists(self) -> bool:
        return self.name in self.bucket.objects

    def generate_signed_url(self, **kwargs) -> str:
        self.bucket.sign_calls.append(dict(kwargs, name=self.name))
        return f"https://storage.googleapis.com/{self.bucket.name}/{self.name}?sig={len(self.bucket.sign_calls)}"


class _FakeBucket:
    def __init__(self, name: str = "photos", objects: set[str] | None = None) -> None:
        self.name = name
        self.objects = objects or set()
        self.sign_calls: list[dict] = []

    def blob(self, name: str) -> _FakeBlob:
        return _FakeBlob(self, name)


class _FakeCredentials:
    def __init__(self) -> None:
        self.calls = 0

    def current(self) -> tuple[str, str]:
        self.calls += 1
        return "mekasa-api@example.iam.gserviceaccount.com", "token-123"


def _signer(bucket: _FakeBucket, clock: _Clock, max_entries: int = 5000):
    from app.photo_links import CachedGcsSigner, SignedLinkCache

    credentials = _FakeCredentials()
    cache = SignedLinkCache(max_entries=max_entries, clock=clock)
    return CachedGcsSigner(bucket, cache, credentials, clock=clock), credentials, cache


def test_signed_links_are_v4_get_valid_for_60_minutes() -> None:
    """AC3: V4 GET URL, 60-minute expiry, signed through IAM credentials."""
    clock = _Clock()
    bucket = _FakeBucket(objects={"a.jpg"})
    signer, _, _ = _signer(bucket, clock)

    lookup = signer.link("a.jpg")

    assert lookup.link is not None and not lookup.cached
    assert lookup.link.expires_at == clock.now + timedelta(minutes=60)
    call = bucket.sign_calls[0]
    assert call["version"] == "v4" and call["method"] == "GET"
    assert call["expiration"] == timedelta(minutes=60)
    assert call["service_account_email"].endswith("iam.gserviceaccount.com")
    assert signer.link("missing.jpg").link is None


def test_cached_link_is_reused_until_less_than_15_minutes_remain() -> None:
    """AC4: a hit returns the same URL with no signing call; near expiry it re-signs."""
    clock = _Clock()
    bucket = _FakeBucket(objects={"a.jpg"})
    signer, credentials, _ = _signer(bucket, clock)

    first = signer.link("a.jpg").link
    clock.now += timedelta(minutes=45)
    again = signer.link("a.jpg")
    assert again.cached and again.link == first
    assert credentials.calls == 1 and len(bucket.sign_calls) == 1

    clock.now += timedelta(seconds=1)
    renewed = signer.link("a.jpg")
    assert not renewed.cached and renewed.link != first
    assert renewed.link.expires_at - clock.now == timedelta(minutes=60)
    assert len(bucket.sign_calls) == 2


def test_cache_drops_least_recently_used_and_evicts_deleted_photos() -> None:
    """AC4: bounded LRU; evicting a deleted photo forces a fresh lookup."""
    clock = _Clock()
    bucket = _FakeBucket(objects={"a.jpg", "b.jpg", "c.jpg"})
    signer, _, cache = _signer(bucket, clock, max_entries=2)

    signer.link("a.jpg")
    signer.link("b.jpg")
    signer.link("a.jpg")
    signer.link("c.jpg")
    assert len(cache) == 2
    assert signer.link("a.jpg").cached
    assert not signer.link("b.jpg").cached

    signer.evict("a.jpg")
    bucket.objects.discard("a.jpg")
    assert signer.link("a.jpg").link is None


def test_route_reports_cached_and_signed_counts_with_cloud_storage(
    client: TestClient, caplog: pytest.LogCaptureFixture
) -> None:
    """AC4, AC5: through the API with a GCS-backed item store, the second call is a cache hit."""
    from app.item_photos import ItemPhotoService, get_item_photo_service
    from app.photo_links import LinkLookup

    hid = _household(client)
    photo_id = str(uuid4())
    path = f"/v1/households/{hid}/item-photos/{photo_id}"
    clock = _Clock()
    bucket = _FakeBucket(objects={f"households/{hid}/item-photos/{photo_id}.jpg"})
    signer, _, _ = _signer(bucket, clock)

    class GcsLikeStore:
        def link(self, ref) -> LinkLookup:
            return signer.link(ref.object_name)

    app = client.app
    app.dependency_overrides[get_item_photo_service] = lambda: ItemPhotoService(GcsLikeStore())
    caplog.set_level(logging.INFO, logger="app.photo_links")
    try:
        first = _links(client, hid, [path]).json()["links"][path]
        second = _links(client, hid, [path]).json()["links"][path]
    finally:
        app.dependency_overrides.clear()

    assert first == second
    assert first["url"].startswith("https://storage.googleapis.com/")
    assert first["expires_at"] is not None
    counts = [r.fields for r in caplog.records if getattr(r, "event", None) == "photo_links"]
    assert counts == [
        {"requested": 1, "cached": 0, "signed": 1, "missing": 0},
        {"requested": 1, "cached": 1, "signed": 0, "missing": 0},
    ]
