"""
App error reports and diagnostics uploads.

Satisfies: NFR-007 (App Error Reports and Diagnostics) AC3, AC4, AC7
Spec version: 1.0
"""

import json
import logging
import os

import pytest
from fastapi.testclient import TestClient

os.environ["ALLOW_TEST_AUTH"] = "true"
os.environ["ENVIRONMENT"] = "test"
os.environ["HOUSEHOLD_PERSISTENCE"] = "memory"

AUTH = {"Authorization": "Bearer test:owner-1"}
APP = {"platform": "ios", "app_version": "1.0.0", "build": "42", "os_version": "18.1", "device_model": "iPhone17,1"}


class _Lines(logging.Handler):
    def __init__(self) -> None:
        super().__init__(level=logging.DEBUG)
        from app.observability import JsonFormatter

        self.setFormatter(JsonFormatter("test-project"))
        self.lines: list[dict] = []

    def emit(self, record: logging.LogRecord) -> None:
        self.lines.append(json.loads(self.format(record)))

    def events(self, name: str) -> list[dict]:
        return [line for line in self.lines if line.get("event") == name]


@pytest.fixture()
def lines():
    handler = _Lines()
    root = logging.getLogger()
    root.addHandler(handler)
    yield handler
    root.removeHandler(handler)


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch, lines: _Lines):
    monkeypatch.setenv("ALLOW_TEST_AUTH", "true")
    monkeypatch.setenv("HOUSEHOLD_PERSISTENCE", "memory")
    from app.client_diagnostics import diagnostics_quota, report_quota
    from app.config import get_settings
    from app.main import create_app

    get_settings.cache_clear()
    report_quota.reset()
    diagnostics_quota.reset()
    with TestClient(create_app()) as test_client:
        yield test_client
    report_quota.reset()
    diagnostics_quota.reset()


def _report(index: int = 0, **overrides) -> dict:
    report = {
        "id": f"report-{index:08d}",
        "time": "2026-10-08T02:10:00Z",
        "where": "receipt.scan",
        "error_type": "URLError.timedOut",
        "message": "The request timed out.",
        "status": None,
        "path": "/v1/households/hh-1/receipts/scan",
        "request_id": "req-aaaaaaaa",
        "correlation_id": "receipt-flow-0001",
        "breadcrumbs": [
            {"level": "info", "category": "receipt", "message": "Receipt scan started", "correlation_id": "receipt-flow-0001"},
            {"level": "info", "category": "api", "message": "POST /v1/households/hh-1/receipts/scan", "fields": {"status": 0}},
        ],
    }
    report.update(overrides)
    return report


# --------------------------------------------------------------------- AC3 error reports


def test_error_report_logs_one_warning_on_the_failed_flow(client: TestClient, lines: _Lines) -> None:
    response = client.post("/v1/client-errors", json={"app": APP, "reports": [_report()]}, headers=AUTH)

    assert response.status_code == 202
    assert response.json() == {"accepted": 1, "dropped": 0}
    [line] = lines.events("client.error")
    assert line["severity"] == "WARNING"
    assert line["correlation_id"] == "receipt-flow-0001"
    assert line["request_id"] == response.headers["x-request-id"]
    assert line["platform"] == "ios"
    assert line["build"] == "42"
    assert line["where"] == "receipt.scan"
    assert line["error_type"] == "URLError.timedOut"
    assert line["error_message"] == "The request timed out."
    assert line["app_request_id"] == "req-aaaaaaaa"
    assert [crumb["text"] for crumb in line["breadcrumbs"]] == [
        "Receipt scan started",
        "POST /v1/households/hh-1/receipts/scan",
    ]
    assert line["user_ref"]


def test_report_without_correlation_keeps_the_upload_ids(client: TestClient, lines: _Lines) -> None:
    client.post(
        "/v1/client-errors",
        json={"app": APP, "reports": [_report(correlation_id=None)]},
        headers={**AUTH, "X-Request-ID": "upload-12345678"},
    )
    [line] = lines.events("client.error")
    assert line["correlation_id"] == "upload-12345678"


def test_reports_log_no_change_event(client: TestClient, lines: _Lines) -> None:
    client.post("/v1/client-errors", json={"app": APP, "reports": [_report()]}, headers=AUTH)
    assert lines.events("change") == []
    [request] = lines.events("http.request")
    assert request["status"] == 202


def test_reports_need_a_signed_in_user(client: TestClient) -> None:
    response = client.post("/v1/client-errors", json={"app": APP, "reports": [_report()]})
    assert response.status_code == 401


def test_batch_and_breadcrumb_limits(client: TestClient) -> None:
    too_many = [_report(i) for i in range(21)]
    assert client.post("/v1/client-errors", json={"app": APP, "reports": too_many}, headers=AUTH).status_code == 422
    crumbs = [{"message": f"step {i}"} for i in range(31)]
    long_trail = [_report(breadcrumbs=crumbs)]
    assert client.post("/v1/client-errors", json={"app": APP, "reports": long_trail}, headers=AUTH).status_code == 422
    assert client.post("/v1/client-errors", json={"app": APP, "reports": []}, headers=AUTH).status_code == 422


def test_reports_over_the_hourly_limit_are_dropped(client: TestClient, lines: _Lines) -> None:
    from app.client_diagnostics import REPORTS_PER_HOUR

    sent = 0
    while sent + 20 <= REPORTS_PER_HOUR:
        body = {"app": APP, "reports": [_report(sent + i) for i in range(20)]}
        assert client.post("/v1/client-errors", json=body, headers=AUTH).json()["dropped"] == 0
        sent += 20

    body = {"app": APP, "reports": [_report(1000 + i) for i in range(3)]}
    response = client.post("/v1/client-errors", json=body, headers=AUTH)
    assert response.json() == {"accepted": 0, "dropped": 3}
    assert len(lines.events("client.error")) == REPORTS_PER_HOUR
    assert lines.events("client.error.dropped")[0]["dropped"] == 3

    other_user = {"Authorization": "Bearer test:member-2"}
    response = client.post("/v1/client-errors", json={"app": APP, "reports": [_report(2000)]}, headers=other_user)
    assert response.json()["accepted"] == 1


# --------------------------------------------------------------------- AC4 diagnostics


def test_diagnostics_upload_logs_a_summary_and_every_entry(client: TestClient, lines: _Lines) -> None:
    entries = [
        {"time": "2026-10-08T02:00:00Z", "level": "info", "category": "session", "message": "Signed in"},
        {
            "level": "error",
            "category": "receipt",
            "message": "Receipt scan failed",
            "correlation_id": "receipt-flow-0002",
            "fields": {"where": "receipt.scan"},
        },
    ]
    response = client.post(
        "/v1/client-diagnostics",
        json={"app": {**APP, "platform": "android"}, "note": "Scan hung", "entries": entries},
        headers=AUTH,
    )

    assert response.status_code == 201
    body = response.json()
    assert body["diagnostics_id"] == response.headers["x-request-id"]
    assert body["reference"] == body["diagnostics_id"][:8].upper()
    assert body["entries"] == 2

    [summary] = lines.events("client.diagnostics")
    assert summary["platform"] == "android"
    assert summary["entries"] == 2
    assert summary["note"] == "Scan hung"
    logged = lines.events("client.log")
    assert [(line["seq"], line["text"]) for line in logged] == [(0, "Signed in"), (1, "Receipt scan failed")]
    assert all(line["diagnostics_id"] == body["diagnostics_id"] for line in logged)
    assert logged[0]["severity"] == "INFO"
    assert logged[1]["client_level"] == "error"
    assert logged[1]["correlation_id"] == "receipt-flow-0002"
    assert logged[1]["fields"] == {"where": "receipt.scan"}
    assert lines.events("change") == []


def test_diagnostics_entry_limit_and_rate_limit(client: TestClient) -> None:
    from app.client_diagnostics import DIAGNOSTICS_PER_HOUR

    too_long = {"app": APP, "entries": [{"message": "x"}] * 501}
    assert client.post("/v1/client-diagnostics", json=too_long, headers=AUTH).status_code == 422

    body = {"app": APP, "entries": [{"message": "hello"}]}
    for _ in range(DIAGNOSTICS_PER_HOUR):
        assert client.post("/v1/client-diagnostics", json=body, headers=AUTH).status_code == 201
    limited = client.post("/v1/client-diagnostics", json=body, headers=AUTH)
    assert limited.status_code == 429
    assert limited.json()["detail"] == "diagnostics_rate_limited"


# --------------------------------------------------------------------- AC7 privacy


def test_personal_details_never_reach_the_logs(client: TestClient, lines: _Lines) -> None:
    report = _report(
        message="Sign-in failed for ana@example.com",
        breadcrumbs=[
            {
                "message": "Invite sent to sam@example.com",
                "fields": {"email": "sam@example.com", "token": "abc123", "address": "1 Main St", "item": "Bananas"},
            }
        ],
    )
    client.post("/v1/client-errors", json={"app": APP, "reports": [report]}, headers=AUTH)
    client.post(
        "/v1/client-diagnostics",
        json={"app": APP, "entries": [{"message": "Hello bob@example.com", "fields": {"password": "pw"}}]},
        headers=AUTH,
    )

    raw = json.dumps(lines.lines)
    for secret in ("ana@example.com", "sam@example.com", "bob@example.com", "abc123", "1 Main St", '"pw"'):
        assert secret not in raw
    [line] = lines.events("client.error")
    assert line["breadcrumbs"][0]["fields"]["item"] == "Bananas"
    assert line["breadcrumbs"][0]["fields"]["email"] == "[redacted]"
