"""Auth session expiry responses (REQ-022)."""

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
    from app.repository import reset_household_repository

    get_settings.cache_clear()
    reset_household_repository()

    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client

    get_settings.cache_clear()
    reset_household_repository()


def test_me_missing_bearer_returns_401(client: TestClient) -> None:
    """
    Satisfies: REQ-022 AC1
    Spec version: 1.0
    """
    response = client.get("/v1/me")
    assert response.status_code == 401
    detail = str(response.json()["detail"]).lower()
    assert "bearer" in detail or "token" in detail


def test_me_invalid_bearer_returns_401_expired_or_invalid(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """
    Satisfies: REQ-022 AC1
    Spec version: 1.0

    With test auth off, a garbage token must be rejected so clients can
    auto sign-out on session expiry.
    """
    monkeypatch.setenv("ALLOW_TEST_AUTH", "false")
    from app.config import get_settings

    get_settings.cache_clear()

    response = client.get(
        "/v1/me",
        headers={"Authorization": "Bearer not-a-real-firebase-token"},
    )
    assert response.status_code == 401
    detail = str(response.json().get("detail", "")).lower()
    assert "invalid" in detail or "expired" in detail or "token" in detail

    monkeypatch.setenv("ALLOW_TEST_AUTH", "true")
    get_settings.cache_clear()
