"""
Request / correlation ids, JSON logs, change events and the receipt scan story.

Satisfies: NFR-006 (Request Tracing and Diagnostic Logs) AC1–AC6; NFR-002 AC3
Spec version: 1.0
"""

import json
import logging
import os
from unittest.mock import AsyncMock, patch

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

os.environ["ALLOW_TEST_AUTH"] = "true"
os.environ["ENVIRONMENT"] = "test"
os.environ["HOUSEHOLD_PERSISTENCE"] = "memory"

UID = "owner-1"
AUTH = {"Authorization": f"Bearer test:{UID}"}


def _reset() -> None:
    from app.catalog_repository import reset_catalog_repository
    from app.config import get_settings
    from app.inventory_repository import reset_inventory_repository
    from app.members_repository import reset_members_repository
    from app.repository import reset_household_repository
    from app.shopping_list_repository import reset_shopping_list_repository

    get_settings.cache_clear()
    reset_household_repository()
    reset_inventory_repository()
    reset_catalog_repository()
    reset_members_repository()
    reset_shopping_list_repository()


class _Lines(logging.Handler):
    """Formats each record while its request context is still active, like stdout does."""

    def __init__(self, project_id: str | None = None) -> None:
        super().__init__(level=logging.DEBUG)
        from app.observability import JsonFormatter

        self.setFormatter(JsonFormatter(project_id))
        self.lines: list[dict] = []
        self.raw: list[str] = []

    def emit(self, record: logging.LogRecord) -> None:
        text = self.format(record)
        self.raw.append(text)
        self.lines.append(json.loads(text))

    def events(self, name: str) -> list[dict]:
        return [line for line in self.lines if line.get("event") == name]


@pytest.fixture()
def lines():
    handler = _Lines("test-project")
    root = logging.getLogger()
    root.addHandler(handler)
    yield handler
    root.removeHandler(handler)


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch, lines: _Lines):
    monkeypatch.setenv("ALLOW_TEST_AUTH", "true")
    monkeypatch.setenv("HOUSEHOLD_PERSISTENCE", "memory")
    monkeypatch.setenv("RECEIPT_LLM_ENABLED", "true")
    monkeypatch.setenv("GCP_PROJECT_ID", "test-project")
    for name in ("DATABASE_URL", "PRODUCT_PHOTO_BUCKET", "ITEM_PHOTO_BUCKET"):
        monkeypatch.delenv(name, raising=False)
    _reset()
    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client
    _reset()


def _household(client: TestClient) -> str:
    created = client.post("/v1/households", json={"name": "The Guerrero Home"}, headers=AUTH)
    assert created.status_code == 201
    return created.json()["id"]


# --------------------------------------------------------------------- AC1 ids


def test_ids_are_echoed_when_valid(client: TestClient) -> None:
    response = client.get(
        "/health",
        headers={"X-Request-ID": "req-12345678", "X-Correlation-ID": "receipt-flow-abc123"},
    )
    assert response.headers["x-request-id"] == "req-12345678"
    assert response.headers["x-correlation-id"] == "receipt-flow-abc123"


def test_missing_or_invalid_ids_are_generated(client: TestClient) -> None:
    response = client.get("/health", headers={"X-Request-ID": "bad id with spaces", "X-Correlation-ID": "short"})
    request_id = response.headers["x-request-id"]
    assert request_id != "bad id with spaces"
    assert len(request_id) == 32
    assert response.headers["x-correlation-id"] == request_id


# --------------------------------------------------------------------- AC2 / AC3


def test_every_line_carries_the_request_context(client: TestClient, lines: _Lines) -> None:
    hid = _household(client)
    client.get(
        f"/v1/households/{hid}/inventory",
        headers={**AUTH, "X-Correlation-ID": "flow-00000001", "X-Cloud-Trace-Context": "0af7651916cd43dd8448eb211c80319c/1;o=1"},
    )
    summary = lines.events("http.request")[-1]
    assert summary["severity"] == "INFO"
    assert summary["method"] == "GET"
    assert summary["route"] == "/v1/households/{household_id}/inventory"
    assert summary["status"] == 200
    assert summary["duration_ms"] >= 0
    assert summary["correlation_id"] == "flow-00000001"
    assert summary["household_id"] == hid
    assert summary["logging.googleapis.com/trace"] == "projects/test-project/traces/0af7651916cd43dd8448eb211c80319c"
    from app.observability import user_ref

    assert summary["user_ref"] == user_ref(UID)
    assert {"time", "logger", "message", "request_id"} <= summary.keys()


def test_client_errors_log_as_warnings(client: TestClient, lines: _Lines) -> None:
    client.get("/v1/households/nope/inventory", headers=AUTH)
    summary = lines.events("http.request")[-1]
    assert summary["severity"] == "WARNING"
    assert summary["status"] in (403, 404)
    assert not lines.events("change")


def test_unhandled_errors_log_the_stack_trace(lines: _Lines) -> None:
    from app.observability import RequestTracingMiddleware

    app = FastAPI()

    @app.get("/boom")
    def boom() -> None:
        raise RuntimeError("kaboom")

    app.add_middleware(RequestTracingMiddleware)
    TestClient(app, raise_server_exceptions=False).get("/boom")
    crash = lines.events("http.exception")[-1]
    assert crash["severity"] == "ERROR"
    assert "kaboom" in crash["stack_trace"]
    assert lines.events("http.request")[-1]["severity"] == "ERROR"


def test_text_format_and_idempotent_setup() -> None:
    from app.observability import configure_logging

    configure_logging("DEBUG", "text")
    configure_logging("INFO", "json")
    marked = [h for h in logging.getLogger().handlers if getattr(h, "_mekasa_handler", False)]
    assert len(marked) == 1
    assert logging.getLogger().level == logging.INFO
    assert logging.getLogger("uvicorn.access").disabled


# --------------------------------------------------------------------- AC4 change events


def test_writes_log_a_change_event(client: TestClient, lines: _Lines) -> None:
    hid = _household(client)
    created = client.post(
        f"/v1/households/{hid}/inventory",
        json={"name": "Organic Bananas", "category": "Produce", "quantity": 3},
        headers=AUTH,
    ).json()
    client.patch(f"/v1/households/{hid}/inventory/{created['id']}", json={"quantity": 1}, headers=AUTH)

    create, update = [c for c in lines.events("change") if c["route"].startswith("/v1/households/{household_id}/inventory")]
    assert create["action"] == "create_inventory_item"
    assert create["ids"] == {"household_id": hid}
    assert create["changes"]["name"] == "Organic Bananas"
    assert create["result_id"] == created["id"]
    assert update["action"] == "update_inventory_item"
    assert update["method"] == "PATCH"
    assert update["ids"] == {"household_id": hid, "item_id": created["id"]}
    assert update["changes"] == {"quantity": 1}


def test_reads_and_failed_writes_log_no_change(client: TestClient, lines: _Lines) -> None:
    hid = _household(client)
    before = len(lines.events("change"))
    client.get(f"/v1/households/{hid}/inventory", headers=AUTH)
    client.post(f"/v1/households/{hid}/inventory", json={"name": ""}, headers=AUTH)
    assert len(lines.events("change")) == before


# --------------------------------------------------------------------- AC6 privacy


def test_personal_details_never_reach_the_logs(client: TestClient, lines: _Lines) -> None:
    hid = _household(client)
    client.put(f"/v1/households/{hid}/address", json={"address": "123 Peachtree St, Atlanta, GA"}, headers=AUTH)
    client.post(
        f"/v1/households/{hid}/invites",
        json={"name": "Grandma Rosa", "email": "rosa@example.com", "phone": "555-0100"},
        headers=AUTH,
    )
    client.patch(f"/v1/households/{hid}/members/member-uid-9", json={"role": "owner"}, headers=AUTH)
    logging.getLogger("app.test").warning("contact %s", "someone@example.org")

    everything = "\n".join(lines.raw)
    for secret in ("test:owner-1", "Peachtree", "Grandma Rosa", "rosa@example.com", "555-0100", "Guerrero", "someone@example.org"):
        assert secret not in everything, secret
    assert f'"{UID}"' not in everything

    household = next(c for c in lines.events("change") if c["action"] == "create_household")
    assert household["changes"]["name"] == "[redacted]"
    invite = next(c for c in lines.events("change") if c["action"] == "create_household_invite")
    assert invite["changes"]["email"] == "[redacted]"
    member = [c for c in lines.events("http.request") if c["route"].endswith("/members/{member_uid}")]
    assert member, "member route was logged"


def test_scrub_rules() -> None:
    from app.observability import scrub

    cleaned = scrub(
        {
            "Authorization": "Bearer x",
            "raw_text": "MILK 3.49\nEGGS 2.99",
            "image_base64": "QUJD",
            "nested": [{"email": "a@b.co", "name": "Milk"}],
            "note": "ping me at x@y.io",
            "empty_email": {"email": None},
        }
    )
    assert cleaned["Authorization"] == "[redacted]"
    assert cleaned["raw_text"] == "[redacted 19 chars]"
    assert cleaned["image_base64"] == "[redacted 4 chars]"
    assert cleaned["nested"] == [{"email": "[redacted]", "name": "Milk"}]
    assert cleaned["note"] == "ping me at [redacted]"
    assert cleaned["empty_email"] == {"email": None}
    assert scrub({"name": "Ana"}, extra_keys=frozenset({"name"})) == {"name": "[redacted]"}


# --------------------------------------------------------------------- AC5 receipt scan story


def _extraction():
    from app.receipt_llm import _Extraction, _ExtractedItem

    return _Extraction(
        store_name="H-E-B",
        store_address="1 Main St",
        items=[
            _ExtractedItem(name="Bananas", receipt_text="BANANAS", receipt_code="4011", category="Produce", price_paid=0.59),
            _ExtractedItem(name="Mystery Snack", receipt_text="MYST SNK", receipt_code=None, category="Snacks", price_paid=2.0),
        ],
    )


def _scan(client: TestClient, hid: str, generate: AsyncMock, correlation: str = "receipt-flow-0001"):
    from app.models import ProductSearchResponse

    off = AsyncMock(return_value=ProductSearchResponse(query="x", results=[]))
    with patch("app.receipt_llm._generate", new=generate), patch("app.receipt_ocr.search_products", new=off):
        return client.post(
            f"/v1/households/{hid}/receipts/scan",
            json={"raw_text": "BANANAS 4011 0.59\nMYST SNK 2.00"},
            headers={**AUTH, "X-Correlation-ID": correlation},
        )


def test_receipt_scan_logs_every_step(client: TestClient, lines: _Lines) -> None:
    hid = _household(client)
    response = _scan(client, hid, AsyncMock(return_value=_extraction()))
    assert response.status_code == 200

    story = [
        line
        for line in lines.lines
        if line.get("correlation_id") == "receipt-flow-0001" and str(line.get("event", "")).startswith("receipt.")
    ]
    assert [line["event"] for line in story] == [
        "receipt.scan.started",
        "receipt.llm.finished",
        "receipt.store.resolved",
        "receipt.line",
        "receipt.line",
        "receipt.scan.finished",
    ]
    started, llm, store, banana, snack, finished = story
    assert started["input"] == "text"
    assert started["text_lines"] == 2
    assert llm["outcome"] == "ok"
    assert llm["items"] == 2
    assert llm["model"]
    assert store["store_name"] == "H-E-B"
    assert store["store_chain_id"] == "heb"
    assert banana["receipt_text"] == "BANANAS"
    assert banana["receipt_code"] == "4011"
    assert banana["match_method"] == "plu_standard"
    assert banana["identified"] is True
    assert snack["name"] == "Mystery Snack"
    assert snack["identified"] is False
    assert finished["lines"] == 2
    assert finished["identified"] == 1
    assert finished["unidentified"] == 1
    assert finished["match_methods"] == {"plu_standard": 1, "none": 1}
    assert all(line["household_id"] == hid for line in story)
    assert "1 Main St" not in "\n".join(lines.raw)
    assert "BANANAS 4011 0.59" not in "\n".join(lines.raw)


def test_receipt_scan_logs_the_fallback(client: TestClient, lines: _Lines) -> None:
    hid = _household(client)
    _scan(client, hid, AsyncMock(side_effect=TimeoutError()))
    llm = lines.events("receipt.llm.finished")[-1]
    assert llm["outcome"] == "timeout"
    assert llm["severity"] == "WARNING"
    ocr = lines.events("receipt.ocr.finished")[-1]
    assert ocr["engine"] == "text"
    assert lines.events("receipt.scan.finished")[-1]["engine"] == "text"


def test_receipt_scan_logs_a_disabled_model(client: TestClient, lines: _Lines, monkeypatch: pytest.MonkeyPatch) -> None:
    hid = _household(client)
    monkeypatch.setenv("RECEIPT_LLM_ENABLED", "false")
    from app.config import get_settings

    get_settings.cache_clear()
    _scan(client, hid, AsyncMock(return_value=_extraction()))
    assert lines.events("receipt.llm.finished")[-1]["outcome"] == "disabled"


def test_one_correlation_id_ties_a_flow_together(client: TestClient, lines: _Lines) -> None:
    hid = _household(client)
    flow = {**AUTH, "X-Correlation-ID": "receipt-flow-0002"}
    _scan(client, hid, AsyncMock(return_value=_extraction()), correlation="receipt-flow-0002")
    client.post(f"/v1/households/{hid}/inventory", json={"name": "Bananas", "category": "Produce", "source": "receipt"}, headers=flow)

    flow_requests = [line for line in lines.events("http.request") if line["correlation_id"] == "receipt-flow-0002"]
    assert [line["route"] for line in flow_requests] == [
        "/v1/households/{household_id}/receipts/scan",
        "/v1/households/{household_id}/inventory",
    ]
    assert len({line["request_id"] for line in flow_requests}) == 2
    change = next(c for c in lines.events("change") if c["correlation_id"] == "receipt-flow-0002")
    assert change["action"] == "create_inventory_item"
