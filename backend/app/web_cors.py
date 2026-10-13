"""
Cross-origin access for the one call the web app cannot route through
Firebase Hosting.

Hosting rewrites to Cloud Run stop at 60 s and a receipt scan can take longer,
so the web app sends `POST …/receipts/scan` straight to the Cloud Run URL.
Every other path stays same-origin and gets no CORS headers at all.

Satisfies: UI-007 (Desktop Web App)
Acceptance criteria: AC11
Spec version: 1.0
"""

from __future__ import annotations

import re

from starlette.middleware.cors import CORSMiddleware
from starlette.types import ASGIApp, Receive, Scope, Send

from app.observability import CORRELATION_ID_HEADER, REQUEST_ID_HEADER

RECEIPT_SCAN_PATH = re.compile(r"^/v1/households/[^/]+/receipts/scan$")


def parse_origins(value: str | None) -> list[str]:
    return [origin.strip().rstrip("/") for origin in (value or "").split(",") if origin.strip()]


class ReceiptScanCorsMiddleware:
    """Starlette's CORS handling, applied only to the receipt scan path."""

    def __init__(self, app: ASGIApp, origins: list[str]) -> None:
        self.app = app
        self.cors = CORSMiddleware(
            app,
            allow_origins=origins,
            allow_methods=["POST"],
            allow_headers=["authorization", "content-type", REQUEST_ID_HEADER, CORRELATION_ID_HEADER],
            expose_headers=[REQUEST_ID_HEADER, CORRELATION_ID_HEADER],
            allow_credentials=False,
            max_age=600,
        )

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] == "http" and RECEIPT_SCAN_PATH.match(scope.get("path", "")):
            await self.cors(scope, receive, send)
            return
        await self.app(scope, receive, send)
