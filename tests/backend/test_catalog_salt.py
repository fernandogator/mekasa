"""
Catalog household salt must be a real secret in production.

Satisfies: REQ-RCP-009 AC4, AC5; NFR-002 AC1
Spec version: 1.0
"""

import pytest
from fastapi.testclient import TestClient

from app.catalog_repository import CatalogSaltMissing, household_hash
from app.config import DEV_HOUSEHOLD_SALT, get_settings


def _reset() -> None:
    from app.catalog_repository import reset_catalog_repository
    from app.inventory_repository import reset_inventory_repository
    from app.repository import reset_household_repository
    from app.scan_events_repository import reset_scan_events_repository

    get_settings.cache_clear()
    reset_household_repository()
    reset_inventory_repository()
    reset_catalog_repository()
    reset_scan_events_repository()


@pytest.fixture()
def prod_env(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ENVIRONMENT", "prod")
    monkeypatch.setenv("ALLOW_TEST_AUTH", "true")
    monkeypatch.setenv("HOUSEHOLD_PERSISTENCE", "memory")
    for name in ("DATABASE_URL", "PRODUCT_PHOTO_BUCKET", "ITEM_PHOTO_BUCKET", "CATALOG_HOUSEHOLD_SALT"):
        monkeypatch.delenv(name, raising=False)
    _reset()
    yield monkeypatch
    _reset()


def _auth() -> dict[str, str]:
    return {"Authorization": "Bearer test:owner-1"}


def _capture_upc(client: TestClient):
    hid = client.post("/v1/households", json={"name": "Casa"}, headers=_auth()).json()["id"]
    item = client.post(
        f"/v1/households/{hid}/inventory", json={"name": "Peanut butter", "category": "Pantry"}, headers=_auth()
    ).json()
    return client.post(
        f"/v1/households/{hid}/inventory/{item['id']}/capture", json={"upc": "041220576037"}, headers=_auth()
    )


def test_prod_refuses_the_development_salt(prod_env) -> None:
    with pytest.raises(CatalogSaltMissing):
        household_hash("household-a")


def test_explicit_salt_is_always_allowed(prod_env) -> None:
    assert household_hash("household-a", salt=DEV_HOUSEHOLD_SALT)


def test_prod_with_secret_salt_hashes_with_it(prod_env) -> None:
    prod_env.setenv("CATALOG_HOUSEHOLD_SALT", "s3cret-test-salt")
    get_settings.cache_clear()
    assert household_hash("household-a") == household_hash("household-a", salt="s3cret-test-salt")
    assert household_hash("household-a") != household_hash("household-a", salt=DEV_HOUSEHOLD_SALT)


def test_non_prod_keeps_the_development_salt(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("ENVIRONMENT", "local")
    monkeypatch.delenv("CATALOG_HOUSEHOLD_SALT", raising=False)
    get_settings.cache_clear()
    try:
        assert household_hash("household-a") == household_hash("household-a", salt=DEV_HOUSEHOLD_SALT)
    finally:
        get_settings.cache_clear()


def test_capture_without_salt_in_prod_is_503_and_writes_nothing(prod_env) -> None:
    from app.catalog_repository import get_catalog_repository
    from app.main import create_app

    with TestClient(create_app()) as client:
        response = _capture_upc(client)
    assert response.status_code == 503
    assert response.json() == {"detail": "catalog_unavailable"}
    assert get_catalog_repository().get_product("041220576037") is None


def test_capture_with_salt_in_prod_succeeds(prod_env) -> None:
    prod_env.setenv("CATALOG_HOUSEHOLD_SALT", "s3cret-test-salt")
    get_settings.cache_clear()
    from app.main import create_app

    with TestClient(create_app()) as client:
        response = _capture_upc(client)
    assert response.status_code == 200, response.text
