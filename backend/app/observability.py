"""
Structured JSON logs, request / correlation ids and change events.

Satisfies: NFR-006 (Request Tracing and Diagnostic Logs) AC1–AC6; NFR-002 AC3
Spec version: 1.0
"""

from __future__ import annotations

import hashlib
import json
import logging
import re
import sys
import time
import traceback
import uuid
from collections.abc import Awaitable, Callable, Iterator, MutableMapping
from contextlib import contextmanager
from contextvars import ContextVar
from dataclasses import dataclass, replace
from datetime import UTC, datetime
from typing import Any

logger = logging.getLogger("app.http")

REQUEST_ID_HEADER = "x-request-id"
CORRELATION_ID_HEADER = "x-correlation-id"
WRITE_METHODS = frozenset({"POST", "PUT", "PATCH", "DELETE"})
REDACTED = "[redacted]"

_ID_RE = re.compile(r"^[A-Za-z0-9._:-]{8,128}$")
_EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
_HOUSEHOLD_PATH_RE = re.compile(r"^/v1/households/([^/]+)")
_TRACE_RE = re.compile(r"^([0-9a-fA-F]{32})")

# Keys whose values never reach the logs (AC6). Matched case-insensitively.
_SECRET_KEYS = frozenset(
    {
        "authorization",
        "token",
        "id_token",
        "fcm_token",
        "invite_token",
        "password",
        "email",
        "address",
        "street",
        "phone",
        "display_name",
    }
)
# Raw receipt input: logged as a size only.
_SIZE_ONLY_KEYS = frozenset({"image_base64", "raw_text"})
# On these routes `name` is a household or person name, not an item.
_PERSON_NAME_ROUTE_PARTS = ("/invites", "/members", "/households/{household_id}/name")
_PERSON_NAME_ROUTES = frozenset({"/v1/households"})
# POST handlers that change no data; their story is told by their own events.
_READ_ONLY_ACTIONS = frozenset({"scan_receipt", "report_client_errors", "upload_client_diagnostics"})

_MAX_BODY_BYTES = 64 * 1024
_MAX_STRING = 500
_MAX_LIST = 50

_RESERVED = frozenset(
    {
        "severity",
        "message",
        "time",
        "logger",
        "event",
        "request_id",
        "correlation_id",
        "household_id",
        "user_ref",
        "stack_trace",
        "logging.googleapis.com/trace",
    }
)


@dataclass
class RequestContext:
    """Per-request ids, shared by every log line written while the request runs."""

    request_id: str
    correlation_id: str
    trace: str | None = None
    household_id: str | None = None
    user_ref: str | None = None


_context: ContextVar[RequestContext | None] = ContextVar("mekasa_request_context", default=None)


def current_context() -> RequestContext | None:
    return _context.get()


def new_id() -> str:
    return uuid.uuid4().hex


def valid_id(value: str | None) -> str | None:
    """A client id we accept as-is (AC1); anything else is replaced."""
    if value and _ID_RE.match(value):
        return value
    return None


def user_ref(uid: str) -> str:
    """Short, stable, non-reversible reference to a Firebase uid (AC6)."""
    return hashlib.sha256(uid.encode("utf-8")).hexdigest()[:12]


def bind_user(uid: str) -> None:
    """Attach the authenticated caller to the current request's log lines."""
    context = _context.get()
    if context is not None:
        context.user_ref = user_ref(uid)


# --------------------------------------------------------------------- scrubbing


def mask_emails(text: str) -> str:
    return _EMAIL_RE.sub(REDACTED, text)


def scrub(value: Any, *, extra_keys: frozenset[str] = frozenset(), depth: int = 0) -> Any:
    """Copy of `value` that is safe to log (AC6)."""
    if depth > 6:
        return "…"
    if isinstance(value, dict):
        cleaned: dict[str, Any] = {}
        for key, item in value.items():
            name = str(key)
            lowered = name.lower()
            if lowered in _SECRET_KEYS or lowered in extra_keys:
                cleaned[name] = REDACTED if item not in (None, "") else item
            elif lowered in _SIZE_ONLY_KEYS:
                cleaned[name] = f"[redacted {len(item)} chars]" if isinstance(item, str) else item
            else:
                cleaned[name] = scrub(item, extra_keys=extra_keys, depth=depth + 1)
        return cleaned
    if isinstance(value, (list, tuple)):
        items = [scrub(item, extra_keys=extra_keys, depth=depth + 1) for item in value[:_MAX_LIST]]
        if len(value) > _MAX_LIST:
            items.append(f"… {len(value) - _MAX_LIST} more")
        return items
    if isinstance(value, str):
        text = mask_emails(value)
        return text if len(text) <= _MAX_STRING else text[:_MAX_STRING] + "…"
    if value is None or isinstance(value, (bool, int, float)):
        return value
    return scrub(str(value), extra_keys=extra_keys, depth=depth + 1)


# --------------------------------------------------------------------- formatting


class JsonFormatter(logging.Formatter):
    """One JSON object per line, in the shape Cloud Logging reads from stdout (AC2)."""

    def __init__(self, project_id: str | None = None) -> None:
        super().__init__()
        self.project_id = project_id

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "severity": record.levelname,
            "message": mask_emails(record.getMessage()),
            "time": datetime.fromtimestamp(record.created, UTC).isoformat(),
            "logger": record.name,
        }
        context = _context.get()
        if context is not None:
            payload["request_id"] = context.request_id
            payload["correlation_id"] = context.correlation_id
            if context.household_id:
                payload["household_id"] = context.household_id
            if context.user_ref:
                payload["user_ref"] = context.user_ref
            if context.trace and self.project_id:
                payload["logging.googleapis.com/trace"] = f"projects/{self.project_id}/traces/{context.trace}"
        event = getattr(record, "event", None)
        if event:
            payload["event"] = event
        fields = getattr(record, "fields", None)
        if isinstance(fields, dict):
            for key, value in scrub(fields).items():
                payload[key if key not in _RESERVED else f"field_{key}"] = value
        if record.exc_info:
            payload["stack_trace"] = mask_emails("".join(traceback.format_exception(*record.exc_info)))
        return json.dumps(payload, default=str, ensure_ascii=False)


class TextFormatter(logging.Formatter):
    """Readable lines for local runs (`LOG_FORMAT=text`)."""

    def format(self, record: logging.LogRecord) -> str:
        context = _context.get()
        prefix = f"[{context.correlation_id[:8]}/{context.request_id[:8]}] " if context else ""
        fields = getattr(record, "fields", None)
        suffix = f" {json.dumps(scrub(fields), default=str, ensure_ascii=False)}" if fields else ""
        line = f"{record.levelname} {record.name} {prefix}{mask_emails(record.getMessage())}{suffix}"
        if record.exc_info:
            line += "\n" + mask_emails("".join(traceback.format_exception(*record.exc_info)))
        return line


_HANDLER_MARK = "_mekasa_handler"


def configure_logging(level: str = "INFO", fmt: str = "json", project_id: str | None = None) -> None:
    """
    Route every logger (app, libraries, uvicorn) through one stdout handler (AC2).
    Idempotent: a second call replaces the handler it installed before.
    """
    root = logging.getLogger()
    for handler in list(root.handlers):
        if getattr(handler, _HANDLER_MARK, False):
            root.removeHandler(handler)
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(TextFormatter() if fmt.lower() == "text" else JsonFormatter(project_id))
    setattr(handler, _HANDLER_MARK, True)
    root.addHandler(handler)
    root.setLevel(level.upper())
    for name in ("uvicorn", "uvicorn.error"):
        server_logger = logging.getLogger(name)
        server_logger.handlers.clear()
        server_logger.propagate = True
    # `http.request` replaces the access log (AC3).
    access = logging.getLogger("uvicorn.access")
    access.handlers.clear()
    access.disabled = True


def log_event(target: logging.Logger, event: str, level: int = logging.INFO, **fields: Any) -> None:
    """Structured event: `event` plus its fields as top-level JSON keys."""
    target.log(level, event, extra={"event": event, "fields": fields})


@contextmanager
def correlated(correlation_id: str | None) -> Iterator[None]:
    """
    Log lines inside the block carry `correlation_id` instead of the request's own,
    so an app report lands next to the API calls it describes (NFR-007 AC3, AC4).
    """
    context = _context.get()
    accepted = valid_id(correlation_id)
    if context is None or accepted is None:
        yield
        return
    token = _context.set(replace(context, correlation_id=accepted))
    try:
        yield
    finally:
        _context.reset(token)


# --------------------------------------------------------------------- middleware

Scope = MutableMapping[str, Any]
Message = MutableMapping[str, Any]
Receive = Callable[[], Awaitable[Message]]
Send = Callable[[Message], Awaitable[None]]
ASGIApp = Callable[[Scope, Receive, Send], Awaitable[None]]


def _header_map(scope: Scope) -> dict[str, str]:
    return {key.decode("latin-1").lower(): value.decode("latin-1") for key, value in scope.get("headers", [])}


def _trace_id(headers: dict[str, str]) -> str | None:
    cloud = _TRACE_RE.match(headers.get("x-cloud-trace-context", ""))
    if cloud:
        return cloud.group(1)
    parts = headers.get("traceparent", "").split("-")
    if len(parts) >= 2 and re.fullmatch(r"[0-9a-f]{32}", parts[1]):
        return parts[1]
    return None


def _person_name_route(template: str) -> bool:
    return template in _PERSON_NAME_ROUTES or any(part in template for part in _PERSON_NAME_ROUTE_PARTS)


def _path_ids(path_params: dict[str, Any]) -> dict[str, Any]:
    return {
        key: user_ref(str(value)) if key.endswith("_uid") else value
        for key, value in path_params.items()
    }


def _result_id(body: Any) -> str | None:
    if not isinstance(body, dict):
        return None
    for key in ("id", "photo_id", "event_id"):
        if isinstance(body.get(key), str):
            return body[key]
    nested = body.get("item")
    if isinstance(nested, dict) and isinstance(nested.get("id"), str):
        return nested["id"]
    return None


def _json(chunks: list[bytes]) -> Any:
    try:
        return json.loads(b"".join(chunks) or b"null")
    except (ValueError, UnicodeDecodeError):
        return None


class RequestTracingMiddleware:
    """
    Satisfies: NFR-006 AC1, AC3, AC4
    Spec version: 1.0

    Assigns request / correlation ids, echoes them on the response, and logs one
    `http.request` per call plus a `change` event for every successful write.
    """

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        headers = _header_map(scope)
        request_id = valid_id(headers.get(REQUEST_ID_HEADER)) or new_id()
        correlation_id = valid_id(headers.get(CORRELATION_ID_HEADER)) or request_id
        household = _HOUSEHOLD_PATH_RE.match(scope.get("path", ""))
        context = RequestContext(
            request_id=request_id,
            correlation_id=correlation_id,
            trace=_trace_id(headers),
            household_id=household.group(1) if household and household.group(1) != "current" else None,
        )
        token = _context.set(context)

        method = scope.get("method", "GET")
        is_write = method in WRITE_METHODS
        is_json_request = "application/json" in headers.get("content-type", "")
        request_chunks: list[bytes] = []
        response_chunks: list[bytes] = []
        sizes = {"request": 0, "response": 0}
        state: dict[str, Any] = {"status": 500, "json_response": False}

        async def receive_wrapper() -> Message:
            message = await receive()
            if message["type"] == "http.request":
                chunk = message.get("body", b"")
                sizes["request"] += len(chunk)
                if is_write and is_json_request and sizes["request"] <= _MAX_BODY_BYTES:
                    request_chunks.append(chunk)
            return message

        async def send_wrapper(message: Message) -> None:
            if message["type"] == "http.response.start":
                state["status"] = message["status"]
                response_headers = list(message.get("headers", []))
                content_type = next(
                    (value for key, value in response_headers if key.lower() == b"content-type"), b""
                )
                state["json_response"] = b"application/json" in content_type
                response_headers.append((b"x-request-id", request_id.encode("latin-1")))
                response_headers.append((b"x-correlation-id", correlation_id.encode("latin-1")))
                message["headers"] = response_headers
            elif message["type"] == "http.response.body":
                chunk = message.get("body", b"")
                sizes["response"] += len(chunk)
                if is_write and state["json_response"] and sizes["response"] <= _MAX_BODY_BYTES:
                    response_chunks.append(chunk)
            await send(message)

        started = time.perf_counter()
        try:
            await self.app(scope, receive_wrapper, send_wrapper)
        except Exception:
            state["status"] = 500
            logger.error(
                "http.exception",
                exc_info=True,
                extra={"event": "http.exception", "fields": {"method": method, "path": scope.get("path")}},
            )
            raise
        finally:
            try:
                self._log(scope, method, state["status"], started, sizes, request_chunks, response_chunks, headers)
            finally:
                _context.reset(token)

    @staticmethod
    def _log(
        scope: Scope,
        method: str,
        status: int,
        started: float,
        sizes: dict[str, int],
        request_chunks: list[bytes],
        response_chunks: list[bytes],
        headers: dict[str, str],
    ) -> None:
        route = scope.get("route")
        template = getattr(route, "path", None) or "unmatched"
        level = logging.ERROR if status >= 500 else logging.WARNING if status >= 400 else logging.INFO
        log_event(
            logger,
            "http.request",
            level,
            method=method,
            route=template,
            status=status,
            duration_ms=round((time.perf_counter() - started) * 1000, 1),
            request_bytes=sizes["request"],
            response_bytes=sizes["response"],
            user_agent=headers.get("user-agent", "")[:200] or None,
        )
        if method not in WRITE_METHODS or status >= 400 or route is None:
            return
        if getattr(route, "name", None) in _READ_ONLY_ACTIONS:
            return
        if request_chunks:
            extra_keys = frozenset({"name"}) if _person_name_route(template) else frozenset()
            changes = scrub(_json(request_chunks), extra_keys=extra_keys)
        elif sizes["request"]:
            changes = {"upload_bytes": sizes["request"]}
        else:
            changes = None
        log_event(
            logger,
            "change",
            action=getattr(route, "name", None),
            method=method,
            route=template,
            ids=_path_ids(dict(scope.get("path_params") or {})),
            changes=changes,
            result_id=_result_id(_json(response_chunks)) if response_chunks else None,
            status=status,
        )
