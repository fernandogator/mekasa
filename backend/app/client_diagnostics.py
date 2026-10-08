"""
App error reports and diagnostics uploads, written to Cloud Logging.

Satisfies: NFR-007 (App Error Reports and Diagnostics) AC3, AC4, AC7; NFR-002 AC3
Spec version: 1.0
"""

from __future__ import annotations

import logging
import threading
import time
from collections import defaultdict, deque
from datetime import datetime
from typing import Any, Literal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from app.auth import AuthUser, verify_bearer_token
from app.observability import correlated, current_context, log_event, new_id, user_ref

logger = logging.getLogger("app.client")

diagnostics_router = APIRouter(prefix="/v1", tags=["diagnostics"])

REPORTS_PER_HOUR = 120
DIAGNOSTICS_PER_HOUR = 10
_WINDOW_SECONDS = 3600.0


class ClientApp(BaseModel):
    """Which app build sent the report."""

    platform: Literal["ios", "android"]
    app_version: str = Field(default="", max_length=40)
    build: str = Field(default="", max_length=40)
    os_version: str = Field(default="", max_length=40)
    device_model: str = Field(default="", max_length=60)


class ClientLogEntry(BaseModel):
    """One on-device log entry (NFR-007 AC1)."""

    time: datetime | None = None
    level: Literal["debug", "info", "warning", "error"] = "info"
    category: str = Field(default="app", max_length=40)
    message: str = Field(default="", max_length=2000)
    request_id: str | None = Field(default=None, max_length=128)
    correlation_id: str | None = Field(default=None, max_length=128)
    fields: dict[str, Any] = Field(default_factory=dict)


class ClientErrorReport(BaseModel):
    """An error the app hit, with the entries that led up to it (NFR-007 AC2)."""

    id: str = Field(min_length=8, max_length=128)
    time: datetime | None = None
    where: str = Field(default="", max_length=120)
    error_type: str = Field(default="", max_length=120)
    message: str = Field(default="", max_length=2000)
    status: int | None = None
    path: str | None = Field(default=None, max_length=300)
    request_id: str | None = Field(default=None, max_length=128)
    correlation_id: str | None = Field(default=None, max_length=128)
    breadcrumbs: list[ClientLogEntry] = Field(default_factory=list, max_length=30)


class ClientErrorBatch(BaseModel):
    app: ClientApp
    reports: list[ClientErrorReport] = Field(min_length=1, max_length=20)


class ClientErrorBatchResponse(BaseModel):
    accepted: int
    dropped: int


class ClientDiagnosticsUpload(BaseModel):
    app: ClientApp
    note: str | None = Field(default=None, max_length=500)
    entries: list[ClientLogEntry] = Field(default_factory=list, max_length=500)


class ClientDiagnosticsResponse(BaseModel):
    diagnostics_id: str
    reference: str
    entries: int


class _HourlyQuota:
    """Per-user sliding-window counter; per instance, which is enough to stop floods."""

    def __init__(self, limit: int) -> None:
        self.limit = limit
        self._lock = threading.Lock()
        self._used: dict[str, deque[float]] = defaultdict(deque)

    def take(self, key: str, wanted: int) -> int:
        """Grant up to `wanted` units now; returns how many were granted."""
        now = time.monotonic()
        with self._lock:
            used = self._used[key]
            while used and now - used[0] > _WINDOW_SECONDS:
                used.popleft()
            granted = max(0, min(wanted, self.limit - len(used)))
            used.extend([now] * granted)
            return granted

    def reset(self) -> None:
        with self._lock:
            self._used.clear()


report_quota = _HourlyQuota(REPORTS_PER_HOUR)
diagnostics_quota = _HourlyQuota(DIAGNOSTICS_PER_HOUR)


def _app_fields(app: ClientApp) -> dict[str, Any]:
    return {
        "platform": app.platform,
        "app_version": app.app_version,
        "build": app.build,
        "os_version": app.os_version,
        "device_model": app.device_model,
    }


def _entry_fields(entry: ClientLogEntry) -> dict[str, Any]:
    return {
        "occurred_at": entry.time.isoformat() if entry.time else None,
        "client_level": entry.level,
        "category": entry.category,
        "text": entry.message,
        "app_request_id": entry.request_id,
        "app_correlation_id": entry.correlation_id,
        "fields": entry.fields,
    }


@diagnostics_router.post(
    "/client-errors",
    response_model=ClientErrorBatchResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
def report_client_errors(
    payload: ClientErrorBatch,
    user: AuthUser = Depends(verify_bearer_token),
) -> ClientErrorBatchResponse:
    """
    Log each app error report as one `client.error` line (AC3).

    Satisfies: NFR-007 AC3, AC7
    Spec version: 1.0
    """
    accepted = report_quota.take(user_ref(user.uid), len(payload.reports))
    app = _app_fields(payload.app)
    for report in payload.reports[:accepted]:
        with correlated(report.correlation_id):
            log_event(
                logger,
                "client.error",
                logging.WARNING,
                **app,
                report_id=report.id,
                occurred_at=report.time.isoformat() if report.time else None,
                where=report.where,
                error_type=report.error_type,
                error_message=report.message,
                status=report.status,
                path=report.path,
                app_request_id=report.request_id,
                app_correlation_id=report.correlation_id,
                breadcrumbs=[_entry_fields(entry) for entry in report.breadcrumbs],
            )
    dropped = len(payload.reports) - accepted
    if dropped:
        log_event(logger, "client.error.dropped", logging.WARNING, dropped=dropped, limit=REPORTS_PER_HOUR)
    return ClientErrorBatchResponse(accepted=accepted, dropped=dropped)


@diagnostics_router.post(
    "/client-diagnostics",
    response_model=ClientDiagnosticsResponse,
    status_code=status.HTTP_201_CREATED,
)
def upload_client_diagnostics(
    payload: ClientDiagnosticsUpload,
    user: AuthUser = Depends(verify_bearer_token),
) -> ClientDiagnosticsResponse:
    """
    Log a user-sent on-device log: one summary line, then one line per entry (AC4).

    Satisfies: NFR-007 AC4, AC5, AC7
    Spec version: 1.0
    """
    if diagnostics_quota.take(user_ref(user.uid), 1) == 0:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="diagnostics_rate_limited")
    context = current_context()
    diagnostics_id = context.request_id if context else new_id()
    log_event(
        logger,
        "client.diagnostics",
        **_app_fields(payload.app),
        diagnostics_id=diagnostics_id,
        entries=len(payload.entries),
        note=payload.note,
    )
    for seq, entry in enumerate(payload.entries):
        with correlated(entry.correlation_id):
            log_event(logger, "client.log", diagnostics_id=diagnostics_id, seq=seq, **_entry_fields(entry))
    return ClientDiagnosticsResponse(
        diagnostics_id=diagnostics_id,
        reference=diagnostics_id[:8].upper(),
        entries=len(payload.entries),
    )
