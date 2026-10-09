"""Teen accounts share one household home photo that only owners can change."""

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
    from app.config import get_settings
    from app.members_repository import reset_members_repository
    from app.repository import reset_household_repository

    get_settings.cache_clear()
    reset_household_repository()
    reset_members_repository()

    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client

    get_settings.cache_clear()
    reset_household_repository()
    reset_members_repository()


def _auth(uid: str) -> dict[str, str]:
    return {"Authorization": f"Bearer test:{uid}"}


def _jpeg() -> tuple[str, bytes, str]:
    return ("home.jpg", b"\xff\xd8\xfffakejpeg", "image/jpeg")


def test_teen_shares_home_photo_and_cannot_change_it(client: TestClient) -> None:
    """
    Satisfies: REQ-002 AC4–AC5, REQ-019 AC6
    Spec version: 1.0
    """
    created = client.post(
        "/v1/households",
        json={"name": "Casa Test"},
        headers=_auth("owner-1"),
    )
    assert created.status_code == 201
    household_id = created.json()["id"]

    uploaded = client.post(
        f"/v1/households/{household_id}/photo",
        headers=_auth("owner-1"),
        files={"file": _jpeg()},
    )
    assert uploaded.status_code == 200
    shared_url = uploaded.json()["photo_url"]
    assert shared_url.startswith("data:image/jpeg;base64,")

    invited = client.post(
        f"/v1/households/{household_id}/invites",
        json={"name": "Riley", "email": "riley@example.com", "role": "teen"},
        headers=_auth("owner-1"),
    )
    assert invited.status_code == 201
    assert invited.json()["role"] == "teen"

    accepted = client.post(
        "/v1/invites/accept",
        json={"token": invited.json()["token"]},
        headers=_auth("teen-1"),
    )
    assert accepted.status_code == 200
    assert accepted.json()["role"] == "teen"

    seen = client.get("/v1/households/current", headers=_auth("teen-1"))
    assert seen.status_code == 200
    assert seen.json()["id"] == household_id
    assert seen.json()["photo_url"] == shared_url

    blocked_photo = client.post(
        f"/v1/households/{household_id}/photo",
        headers=_auth("teen-1"),
        files={"file": ("other.jpg", b"\xff\xd8\xffother", "image/jpeg")},
    )
    assert blocked_photo.status_code == 403
    blocked_name = client.put(
        f"/v1/households/{household_id}/name",
        json={"name": "Not Riley's house"},
        headers=_auth("teen-1"),
    )
    assert blocked_name.status_code == 403

    still = client.get("/v1/households/current", headers=_auth("teen-1"))
    assert still.json()["photo_url"] == shared_url
    assert still.json()["name"] == "Casa Test"

    unknown = client.post(
        f"/v1/households/{household_id}/invites",
        json={"name": "Nope", "email": "nope@example.com", "role": "admin"},
        headers=_auth("owner-1"),
    )
    assert unknown.status_code == 422


def test_any_owner_can_replace_the_shared_photo(client: TestClient) -> None:
    """
    Satisfies: REQ-002 AC5, REQ-019 AC3
    Spec version: 1.0
    """
    created = client.post(
        "/v1/households",
        json={"name": "Casa Test"},
        headers=_auth("owner-1"),
    )
    household_id = created.json()["id"]

    for uid, role, email in (
        ("teen-1", "teen", "riley@example.com"),
        ("member-1", "member", "sam@example.com"),
        ("owner-2", "owner", "alex@example.com"),
    ):
        invited = client.post(
            f"/v1/households/{household_id}/invites",
            json={"name": uid, "email": email, "role": role},
            headers=_auth("owner-1"),
        )
        assert invited.status_code == 201
        accepted = client.post(
            "/v1/invites/accept",
            json={"token": invited.json()["token"]},
            headers=_auth(uid),
        )
        assert accepted.status_code == 200
        assert accepted.json()["role"] == role

    for uid in ("teen-1", "member-1"):
        denied = client.post(
            f"/v1/households/{household_id}/photo",
            headers=_auth(uid),
            files={"file": _jpeg()},
        )
        assert denied.status_code == 403

    replaced = client.post(
        f"/v1/households/{household_id}/photo",
        headers=_auth("owner-2"),
        files={"file": ("home.jpg", b"\xff\xd8\xffcoowner", "image/jpeg")},
    )
    assert replaced.status_code == 200
    shared_url = replaced.json()["photo_url"]

    for uid in ("owner-1", "owner-2", "teen-1", "member-1"):
        seen = client.get("/v1/households/current", headers=_auth(uid))
        assert seen.status_code == 200
        assert seen.json()["photo_url"] == shared_url

    demoted = client.patch(
        f"/v1/households/{household_id}/members/teen-1",
        json={"role": "member"},
        headers=_auth("owner-2"),
    )
    assert demoted.status_code == 200
    assert demoted.json()["role"] == "member"
    promoted = client.patch(
        f"/v1/households/{household_id}/members/member-1",
        json={"role": "teen"},
        headers=_auth("owner-1"),
    )
    assert promoted.status_code == 200
    assert promoted.json()["role"] == "teen"

    listed = client.get(f"/v1/households/{household_id}/members", headers=_auth("teen-1"))
    assert listed.status_code == 200
    roles = [(row["uid"], row["role"]) for row in listed.json()["members"]]
    assert roles == [
        ("owner-1", "owner"),
        ("owner-2", "owner"),
        ("member-1", "teen"),
        ("teen-1", "member"),
    ]


def test_current_household_loads_when_invite_lookup_fails(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """
    Satisfies: REQ-019 AC7
    Spec version: 1.0

    A missing Firestore collection-group index used to 500 this route, which
    left the teen stuck before any household could load.
    """
    created = client.post("/v1/households", json={"name": "Casa Test"}, headers=_auth("owner-1"))
    assert created.status_code == 201
    household_id = created.json()["id"]

    from app.members_repository import get_members_repository

    def explode(*_args: object, **_kwargs: object) -> None:
        raise RuntimeError("FAILED_PRECONDITION: COLLECTION_GROUP_ASC index")

    monkeypatch.setattr(get_members_repository(), "accept_pending_invites_for_email", explode)
    current = client.get("/v1/households/current", headers=_auth("owner-1"))
    assert current.status_code == 200
    assert current.json()["id"] == household_id


def test_signing_in_with_the_invited_email_shows_family_inventory(client: TestClient) -> None:
    """
    Satisfies: REQ-019 AC7
    Spec version: 1.0

    Test auth email for uid teen-1 is teen-1@example.com. No invite link is opened.
    """
    created = client.post("/v1/households", json={"name": "Casa Test"}, headers=_auth("owner-1"))
    assert created.status_code == 201
    household_id = created.json()["id"]
    added = client.post(
        f"/v1/households/{household_id}/inventory",
        json={"name": "Milk", "category": "Dairy", "quantity": 2},
        headers=_auth("owner-1"),
    )
    assert added.status_code == 201

    invited = client.post(
        f"/v1/households/{household_id}/invites",
        json={"name": "Riley", "email": "Teen-1@example.com", "role": "teen"},
        headers=_auth("owner-1"),
    )
    assert invited.status_code == 201

    current = client.get("/v1/households/current", headers=_auth("teen-1"))
    assert current.status_code == 200
    assert current.json()["id"] == household_id

    listed = client.get(f"/v1/households/{household_id}/inventory", headers=_auth("teen-1"))
    assert listed.status_code == 200
    assert [item["name"] for item in listed.json()["items"]] == ["Milk"]

    members = client.get(f"/v1/households/{household_id}/members", headers=_auth("teen-1"))
    teen = next(row for row in members.json()["members"] if row["uid"] == "teen-1")
    assert teen["role"] == "teen"


def test_blank_signup_household_does_not_hide_family_inventory(client: TestClient) -> None:
    """
    Satisfies: REQ-019 AC7
    Spec version: 1.0
    """
    created = client.post("/v1/households", json={"name": "Casa Test"}, headers=_auth("owner-1"))
    household_id = created.json()["id"]
    added = client.post(
        f"/v1/households/{household_id}/inventory",
        json={"name": "Milk", "category": "Dairy"},
        headers=_auth("owner-1"),
    )
    assert added.status_code == 201
    uploaded = client.post(
        f"/v1/households/{household_id}/photo",
        headers=_auth("owner-1"),
        files={"file": _jpeg()},
    )
    assert uploaded.status_code == 200
    family_photo = uploaded.json()["photo_url"]

    blank = client.post("/v1/households", json={"name": "Riley's room"}, headers=_auth("teen-1"))
    assert blank.status_code == 201
    assert blank.json()["id"] != household_id

    invited = client.post(
        f"/v1/households/{household_id}/invites",
        json={"name": "Riley", "email": "teen-1@example.com", "role": "teen"},
        headers=_auth("owner-1"),
    )
    assert invited.status_code == 201

    current = client.get("/v1/households/current", headers=_auth("teen-1"))
    assert current.status_code == 200
    assert current.json()["id"] == household_id
    assert current.json()["photo_url"] == family_photo

    listed = client.get(
        f"/v1/households/{household_id}/inventory",
        headers=_auth("teen-1"),
    )
    assert listed.status_code == 200
    assert [item["name"] for item in listed.json()["items"]] == ["Milk"]
