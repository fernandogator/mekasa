"""Backend tests for health grade + per-member avoidances (REQ-021)."""

import os
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

os.environ["ALLOW_TEST_AUTH"] = "true"
os.environ["ENVIRONMENT"] = "test"
os.environ["HOUSEHOLD_PERSISTENCE"] = "memory"


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ALLOW_TEST_AUTH", "true")
    monkeypatch.setenv("HOUSEHOLD_PERSISTENCE", "memory")
    from app.config import get_settings
    from app.inventory_repository import reset_inventory_repository
    from app.members_repository import reset_members_repository
    from app.repository import reset_household_repository
    from app.shopping_list_repository import reset_shopping_list_repository
    from app.spending_repository import reset_spending_repository

    def _reset() -> None:
        get_settings.cache_clear()
        reset_household_repository()
        reset_inventory_repository()
        reset_shopping_list_repository()
        reset_members_repository()
        reset_spending_repository()

    _reset()
    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client
    _reset()


def _auth(uid: str = "owner-1") -> dict[str, str]:
    return {"Authorization": f"Bearer test:{uid}"}


def _household(client: TestClient, uid: str = "owner-1") -> str:
    created = client.post("/v1/households", json={"name": "Health House"}, headers=_auth(uid))
    assert created.status_code == 201
    return created.json()["id"]


def _invite_member(client: TestClient, household_id: str, uid: str, name: str) -> None:
    invite = client.post(
        f"/v1/households/{household_id}/invites",
        json={"name": name, "email": f"{uid}@example.com", "role": "member"},
        headers=_auth("owner-1"),
    )
    assert invite.status_code == 201
    accepted = client.post(
        "/v1/invites/accept", json={"token": invite.json()["token"]}, headers=_auth(uid)
    )
    assert accepted.status_code == 200


RAMEN_PRODUCT = {
    "product_name": "Instant Ramen Chicken",
    "brands": "NoodleCo",
    "categories": "Instant noodles",
    "categories_tags": ["en:instant-noodles"],
    "image_front_url": "https://images.openfoodfacts.org/ramen.jpg",
    "nutriscore_grade": "d",
    "nova_group": 4,
    "additives_tags": ["en:e621", "en:e627", "en:e150c", "en:e330"],
    "allergens_tags": ["en:gluten", "en:soybeans"],
    "traces_tags": ["en:eggs", "en:peanuts"],
    "ingredients_text": "Wheat flour, palm oil, salt, monosodium glutamate, soy sauce powder",
    "ingredients_analysis_tags": ["en:palm-oil", "en:non-vegan"],
}


def _mock_off(product: dict):
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.raise_for_status = MagicMock()
    mock_response.json.return_value = {"status": 1, "code": "0000000012345", "product": product}
    mock_client = AsyncMock()
    mock_client.get.return_value = mock_response
    mock_client.aclose = AsyncMock()
    return patch("app.barcode_lookup.httpx.AsyncClient", return_value=mock_client)


# ---------------------------------------------------------------- pure logic


def test_grade_from_nutriscore_with_additive_penalties() -> None:
    """
    Satisfies: REQ-021 AC3 (transparent grade formula)
    Spec version: 1.0
    """
    from app.product_health import health_from_off_product

    health = health_from_off_product(RAMEN_PRODUCT)
    assert health is not None
    # Nutri-Score D (35) − NOVA 4 (5) − MSG (10) − E627 (10) − E150c (10) − E330 (0) = 0 → E
    assert health.nutriscore == "D"
    assert health.nova_group == 4
    assert health.score == 0
    assert health.grade == "E"
    codes = [additive.code for additive in health.additives]
    assert codes == ["E621", "E627", "E150C", "E330"]
    assert health.additives[0].name.startswith("Monosodium glutamate")
    assert health.additives[0].concern == "moderate"
    assert health.allergens == ["Gluten", "Soybeans"]
    assert health.traces == ["Eggs", "Peanuts"]
    assert "Palm oil" in health.flags


def test_grade_clean_product_is_a() -> None:
    from app.product_health import health_from_off_product

    health = health_from_off_product(
        {"nutriscore_grade": "a", "nova_group": 1, "additives_tags": [], "ingredients_text": "Oats"}
    )
    assert health is not None
    assert health.grade == "A"
    assert health.score == 90


def test_grade_falls_back_to_nova_and_none_without_data() -> None:
    from app.product_health import health_from_off_product

    nova_only = health_from_off_product({"nova_group": "3"})
    assert nova_only is not None and nova_only.grade == "C" and nova_only.nutriscore is None

    assert health_from_off_product({"product_name": "Mystery"}) is None
    ingredients_only = health_from_off_product({"ingredients_text": "Sugar, water"})
    assert ingredients_only is not None and ingredients_only.grade is None


def test_matched_avoidances_msg_gluten_and_free_text() -> None:
    """
    Satisfies: REQ-021 AC2 (MSG → E621, gluten → allergen tag, free text → ingredients)
    Spec version: 1.0
    """
    from app.product_health import health_from_off_product, matched_avoidances

    health = health_from_off_product(RAMEN_PRODUCT)
    hits = matched_avoidances(["MSG", "Gluten", "peanuts", "palm oil", "chicken", "Milk / dairy"], health)
    # MSG via E621 code, gluten via allergen tag, peanuts via traces,
    # palm oil via analysis flag + ingredients, free text "chicken" not in ingredients.
    assert hits == ["msg", "gluten", "peanuts", "palm_oil"]


def test_matched_avoidances_word_boundaries() -> None:
    from app.models import ProductHealth
    from app.product_health import matched_avoidances

    veggie = ProductHealth(ingredients_text="Veggie mix, water")
    assert matched_avoidances(["eggs"], veggie) == []
    eggs = ProductHealth(ingredients_text="Sugar, eggs, flour")
    assert matched_avoidances(["egg"], eggs) == ["eggs"]
    assert matched_avoidances(["egg"], None) == []


def test_normalize_avoidance_aliases() -> None:
    from app.product_health import normalize_avoidance

    assert normalize_avoidance("  Monosodium Glutamate ") == "msg"
    assert normalize_avoidance("Milk / dairy") == "milk"
    assert normalize_avoidance("Lactose") == "milk"
    assert normalize_avoidance("Red 40") == "artificial_colors"
    assert normalize_avoidance("cilantro") == "cilantro"
    assert normalize_avoidance("") == ""


# ---------------------------------------------------------------- HTTP


def test_avoidances_catalog_endpoint(client: TestClient) -> None:
    assert client.get("/v1/health/avoidances").status_code == 401
    response = client.get("/v1/health/avoidances", headers=_auth())
    assert response.status_code == 200
    keys = {option["key"] for option in response.json()["options"]}
    assert {"msg", "gluten", "peanuts", "milk"} <= keys


def test_member_updates_own_avoid_list_and_owner_updates_others(client: TestClient) -> None:
    """
    Satisfies: REQ-021 AC1
    Spec version: 1.0
    """
    household_id = _household(client)
    _invite_member(client, household_id, "member-2", "Sam")

    mine = client.put(
        f"/v1/households/{household_id}/members/member-2/avoid",
        json={"avoid": ["MSG", "monosodium glutamate", "Peanuts", "", "cilantro"]},
        headers=_auth("member-2"),
    )
    assert mine.status_code == 200
    assert mine.json()["avoid"] == ["msg", "peanuts", "cilantro"]

    # Owner may edit a member; a member may not edit someone else.
    by_owner = client.put(
        f"/v1/households/{household_id}/members/member-2/avoid",
        json={"avoid": ["gluten"]},
        headers=_auth("owner-1"),
    )
    assert by_owner.status_code == 200
    assert by_owner.json()["avoid"] == ["gluten"]

    forbidden = client.put(
        f"/v1/households/{household_id}/members/owner-1/avoid",
        json={"avoid": ["soy"]},
        headers=_auth("member-2"),
    )
    assert forbidden.status_code == 403

    listed = client.get(f"/v1/households/{household_id}/members", headers=_auth("owner-1"))
    by_uid = {row["uid"]: row for row in listed.json()["members"]}
    assert by_uid["member-2"]["avoid"] == ["gluten"]

    missing = client.put(
        f"/v1/households/{household_id}/members/ghost/avoid",
        json={"avoid": ["soy"]},
        headers=_auth("owner-1"),
    )
    assert missing.status_code == 404


def test_barcode_lookup_returns_health_and_household_warnings(client: TestClient) -> None:
    """
    Satisfies: REQ-021 AC2 (warn at scan time)
    Spec version: 1.0
    """
    household_id = _household(client)
    _invite_member(client, household_id, "member-2", "Sam")
    assert (
        client.put(
            f"/v1/households/{household_id}/members/member-2/avoid",
            json={"avoid": ["MSG"]},
            headers=_auth("member-2"),
        ).status_code
        == 200
    )
    assert (
        client.put(
            f"/v1/households/{household_id}/members/owner-1/avoid",
            json={"avoid": ["shellfish"]},
            headers=_auth("owner-1"),
        ).status_code
        == 200
    )

    with _mock_off(RAMEN_PRODUCT):
        plain = client.get("/v1/barcode/0000000012345", headers=_auth())
        scoped = client.get(
            f"/v1/barcode/0000000012345?household_id={household_id}", headers=_auth()
        )

    assert plain.status_code == 200
    assert plain.json()["health"]["grade"] == "E"
    assert plain.json()["warnings"] == []

    body = scoped.json()
    assert body["health"]["nutriscore"] == "D"
    assert body["warnings"] == [
        {"member_uid": "member-2", "member_name": "Test User", "matched": ["MSG"]}
    ]


def test_inventory_item_persists_health_and_lists_warnings(client: TestClient) -> None:
    """
    Satisfies: REQ-021 AC2 (warnings on stored items), REQ-006
    Spec version: 1.0
    """
    from app.product_health import health_from_off_product

    household_id = _household(client)
    _invite_member(client, household_id, "member-2", "Sam")
    client.put(
        f"/v1/households/{household_id}/members/member-2/avoid",
        json={"avoid": ["gluten", "peanuts"]},
        headers=_auth("member-2"),
    )
    health = health_from_off_product(RAMEN_PRODUCT)
    assert health is not None

    created = client.post(
        f"/v1/households/{household_id}/inventory",
        json={
            "name": "Instant Ramen",
            "category": "Pantry",
            "barcode": "0000000012345",
            "source": "barcode",
            "health": health.model_dump(mode="json"),
        },
        headers=_auth("owner-1"),
    )
    assert created.status_code == 201
    row = created.json()
    assert row["health"]["grade"] == "E"
    assert row["warnings"] == [
        {"member_uid": "member-2", "member_name": "Test User", "matched": ["Gluten", "Peanuts"]}
    ]

    # Items without health data carry no warnings and are unaffected.
    plain = client.post(
        f"/v1/households/{household_id}/inventory",
        json={"name": "Bananas", "category": "Produce"},
        headers=_auth("owner-1"),
    )
    assert plain.status_code == 201
    assert plain.json()["health"] is None and plain.json()["warnings"] == []

    listed = client.get(f"/v1/households/{household_id}/inventory", headers=_auth("member-2"))
    assert listed.status_code == 200
    by_name = {item["name"]: item for item in listed.json()["items"]}
    assert by_name["Instant Ramen"]["warnings"][0]["matched"] == ["Gluten", "Peanuts"]
    assert by_name["Bananas"]["warnings"] == []

    fetched = client.get(
        f"/v1/households/{household_id}/inventory/{row['id']}", headers=_auth("owner-1")
    )
    assert fetched.json()["health"]["additives"][0]["code"] == "E621"

    # PATCH can attach / replace health (e.g. re-scan) and keeps typed data.
    patched = client.patch(
        f"/v1/households/{household_id}/inventory/{row['id']}",
        json={"health": {"grade": "B", "score": 70, "nutriscore": "B"}},
        headers=_auth("owner-1"),
    )
    assert patched.status_code == 200
    assert patched.json()["health"]["grade"] == "B"
    assert patched.json()["health"]["additives"] == []
