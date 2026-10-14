"""
Receipt scans called straight on Cloud Run from the web app.

Satisfies: UI-007 (Desktop Web App)
Acceptance criteria: AC11
Spec version: 1.0
"""

import os

import pytest
from fastapi.testclient import TestClient

os.environ["ALLOW_TEST_AUTH"] = "true"
os.environ["ENVIRONMENT"] = "test"
os.environ["HOUSEHOLD_PERSISTENCE"] = "memory"

WEB = "https://mekasa.web.app"
SCAN = "/v1/households/hh-1/receipts/scan"


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ALLOW_TEST_AUTH", "true")
    monkeypatch.setenv("HOUSEHOLD_PERSISTENCE", "memory")
    monkeypatch.delenv("WEB_CORS_ORIGINS", raising=False)
    from app.config import get_settings
    from app.repository import reset_household_repository

    get_settings.cache_clear()
    reset_household_repository()
    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client
    get_settings.cache_clear()
    reset_household_repository()


def _preflight(client: TestClient, path: str, origin: str):
    return client.options(
        path,
        headers={
            "Origin": origin,
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "authorization, content-type, x-request-id, x-correlation-id",
        },
    )


@pytest.mark.parametrize(
    "origin",
    [WEB, "https://mekasa.firebaseapp.com", "http://localhost:5173"],
)
def test_preflight_from_web_origins_is_allowed_on_receipt_scan(client: TestClient, origin: str) -> None:
    response = _preflight(client, SCAN, origin)

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == origin
    assert "POST" in response.headers["access-control-allow-methods"]
    allowed = response.headers["access-control-allow-headers"].lower()
    for header in ("authorization", "content-type", "x-request-id", "x-correlation-id"):
        assert header in allowed
    assert "access-control-allow-credentials" not in response.headers


def test_scan_response_carries_cors_and_exposes_trace_ids(client: TestClient) -> None:
    response = client.post(SCAN, json={"raw_text": "MILK 3.49"}, headers={"Origin": WEB})

    assert response.headers["access-control-allow-origin"] == WEB
    exposed = response.headers["access-control-expose-headers"].lower()
    assert "x-request-id" in exposed and "x-correlation-id" in exposed


def test_other_origins_are_refused(client: TestClient) -> None:
    response = _preflight(client, SCAN, "https://evil.example")

    assert response.status_code == 400
    assert "access-control-allow-origin" not in response.headers


def test_other_paths_get_no_cors_headers(client: TestClient) -> None:
    created = client.post(
        "/v1/households",
        json={"name": "Casa"},
        headers={"Authorization": "Bearer test:owner-1", "Origin": WEB},
    )
    assert created.status_code == 201
    assert "access-control-allow-origin" not in created.headers

    preflight = _preflight(client, "/v1/households/hh-1/inventory", WEB)
    assert "access-control-allow-origin" not in preflight.headers


def test_origins_come_from_settings(client: TestClient, monkeypatch: pytest.MonkeyPatch) -> None:
    from app.config import get_settings
    from app.main import create_app

    monkeypatch.setenv("WEB_CORS_ORIGINS", "https://preview.example/ , https://other.example")
    get_settings.cache_clear()
    with TestClient(create_app()) as custom:
        assert _preflight(custom, SCAN, "https://preview.example").headers.get(
            "access-control-allow-origin"
        ) == "https://preview.example"
        assert "access-control-allow-origin" not in _preflight(custom, SCAN, WEB).headers
