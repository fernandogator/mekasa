"""
Shared product catalog routes: read, search, corrections.

Satisfies: REQ-RCP-007, REQ-RCP-011, REQ-RCP-019 AC3–AC5
Spec version: 1.0
"""

import os

import pytest
from fastapi.testclient import TestClient

os.environ["ALLOW_TEST_AUTH"] = "true"
os.environ["ENVIRONMENT"] = "test"
os.environ["HOUSEHOLD_PERSISTENCE"] = "memory"


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ALLOW_TEST_AUTH", "true")
    monkeypatch.setenv("HOUSEHOLD_PERSISTENCE", "memory")
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


def _household(client: TestClient, uid: str = "owner-1") -> str:
    created = client.post("/v1/households", json={"name": "Casa Catalog"}, headers=_auth(uid))
    assert created.status_code == 201
    return created.json()["id"]


def _seed_product(upc: str = "041220576037", name: str = "Coke", category: str = "Beverages", hashes: int = 1) -> None:
    from app.catalog_repository import get_catalog_repository, household_hash

    repo = get_catalog_repository()
    for i in range(hashes):
        repo.capture(
            store_chain_id="heb", upc=upc, hh=household_hash(f"seed-{i}"),
            fallback_name=name, fallback_category=category, brand="Coca-Cola",
        )


def test_product_routes_require_auth(client: TestClient) -> None:
    assert client.get("/v1/catalog/products/041220576037").status_code == 401
    assert client.get("/v1/catalog/products/search", params={"q": "coke"}).status_code == 401
    assert client.post("/v1/catalog/products/041220576037/corrections", json={"household_id": "h", "category": "x"}).status_code == 401


def test_get_product_any_signed_in_user_and_404(client: TestClient) -> None:
    _seed_product()
    res = client.get("/v1/catalog/products/041220576037", headers=_auth("someone-else"))
    assert res.status_code == 200
    body = res.json()
    assert body["id"] == "041220576037" and body["upc"] == "041220576037"
    assert body["source"] == "user_scan" and body["status"] == "unverified" and body["confirmation_count"] == 1
    assert set(body) >= {"id", "upc", "store_chain_id", "name", "category", "source", "confidence_score", "confirmation_count", "status", "image_source"}
    assert "household" not in str(body)
    assert client.get("/v1/catalog/products/000000000000", headers=_auth()).status_code == 404


def test_search_products(client: TestClient) -> None:
    _seed_product("041220576037", "Coke 12 pack")
    _seed_product("049000028904", "Coke Zero 12 pack")
    res = client.get("/v1/catalog/products/search", params={"q": "coke zero", "store_chain_id": "heb"}, headers=_auth())
    assert res.status_code == 200
    body = res.json()
    assert body["query"] == "coke zero"
    assert body["results"][0]["id"] == "049000028904"
    assert client.get("/v1/catalog/products/search", params={"q": "c"}, headers=_auth()).status_code == 422
    assert client.get("/v1/catalog/products/search", params={"q": "coke", "status": "bogus"}, headers=_auth()).status_code == 422


def test_corrections_apply_on_unverified_and_hash_household(client: TestClient) -> None:
    hid = _household(client)
    _seed_product(category="Frozen")
    res = client.post(
        "/v1/catalog/products/041220576037/corrections",
        json={"household_id": hid, "category": "Beverages", "unit_size": "12 x 12 fl oz"},
        headers=_auth(),
    )
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["applied"] is True and body["status_reset"] is True and body["conflicts"] == []
    assert body["product"]["category"] == "Beverages" and body["product"]["unit_size"] == "12 x 12 fl oz"
    assert body["product"]["confirmation_count"] == 0

    from app.catalog_repository import get_catalog_repository

    repo = get_catalog_repository()
    assert all(hid not in str(c) for c in repo.conflicts())  # NFR-002 AC1: no household id in the catalog


def test_corrections_on_verified_return_conflicts(client: TestClient) -> None:
    hid = _household(client)
    _seed_product(hashes=3)  # 3 distinct households → verified
    res = client.post(
        "/v1/catalog/products/041220576037/corrections",
        json={"household_id": hid, "name": "Coca-Cola Classic", "source_line_item": {"receipt_id": "r1", "line_item_id": "l1"}},
        headers=_auth(),
    )
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["applied"] is False and body["product"]["name"] == "Coke" and body["product"]["status"] == "verified"
    assert [c["field"] for c in body["conflicts"]] == ["name"]
    assert body["conflicts"][0]["observed_value"] == "Coca-Cola Classic" and body["conflicts"][0]["status"] == "open"


def test_corrections_error_mapping(client: TestClient) -> None:
    hid = _household(client)
    _seed_product("041220576037")
    _seed_product("049000028904", "Coke Zero")
    base = "/v1/catalog/products/041220576037/corrections"
    assert client.post(base, json={"household_id": hid, "name": "Coke"}, headers=_auth()).json()["detail"] == "no_changes"
    assert client.post(base, json={"household_id": hid, "name": "Coke"}, headers=_auth()).status_code == 400
    assert client.post(base, json={"household_id": hid, "upc": "049000028904"}, headers=_auth()).status_code == 409
    assert client.post(base, json={"household_id": hid, "upc": "12"}, headers=_auth()).status_code == 422
    assert client.post("/v1/catalog/products/nope/corrections", json={"household_id": hid, "category": "x"}, headers=_auth()).status_code == 404
    # non-member of the household → 403; unknown household → 404
    assert client.post(base, json={"household_id": hid, "category": "x"}, headers=_auth("stranger")).status_code == 403
    assert client.post(base, json={"household_id": "missing", "category": "x"}, headers=_auth()).status_code == 404
