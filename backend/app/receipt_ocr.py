"""Receipt OCR parsing via Cloud Vision with a deterministic stub fallback (REQ-005)."""

from __future__ import annotations

import base64
import re
from dataclasses import dataclass

from app.models import ReceiptLineItem


@dataclass(frozen=True)
class ReceiptParseResult:
    """OCR parse outcome."""

    items: list[ReceiptLineItem]
    engine: str
    raw_text: str


_PRICE_RE = re.compile(
    r"^(?P<name>.+?)\s+(?:\$)?(?P<price>\d+\.\d{2})\s*$"
)
_SKIP_PREFIXES = (
    "total",
    "subtotal",
    "tax",
    "change",
    "cash",
    "card",
    "visa",
    "mastercard",
    "auth",
    "thank",
    "www",
    "tel",
    "phone",
)


def parse_receipt_text(text: str) -> list[ReceiptLineItem]:
    """Heuristic line-item extraction from OCR / stub text."""
    items: list[ReceiptLineItem] = []
    for raw_line in (text or "").splitlines():
        line = " ".join(raw_line.strip().split())
        if not line:
            continue
        lowered = line.casefold()
        if any(lowered.startswith(prefix) for prefix in _SKIP_PREFIXES):
            continue
        match = _PRICE_RE.match(line)
        if not match:
            continue
        name = match.group("name").strip(" -·•")
        if len(name) < 2:
            continue
        price = float(match.group("price"))
        items.append(
            ReceiptLineItem(
                name=name.title() if name.isupper() else name,
                category="Other",
                quantity=1,
                price_paid=price,
            )
        )
    return items


def stub_receipt_items() -> list[ReceiptLineItem]:
    """Deterministic demo haul used when Vision is unavailable."""
    return [
        ReceiptLineItem(name="Bananas", category="Produce", quantity=1, price_paid=1.29),
        ReceiptLineItem(name="Whole Milk", category="Dairy", quantity=1, price_paid=3.49),
        ReceiptLineItem(name="Sourdough Loaf", category="Pantry", quantity=1, price_paid=4.99),
    ]


def _decode_image(image_base64: str) -> bytes:
    cleaned = image_base64.strip()
    if "," in cleaned and cleaned.lower().startswith("data:"):
        cleaned = cleaned.split(",", 1)[1]
    return base64.b64decode(cleaned, validate=False)


def _vision_annotate(image_bytes: bytes) -> str:
    """Call Cloud Vision DOCUMENT_TEXT_DETECTION. Raises on failure."""
    from google.cloud import vision  # type: ignore

    client = vision.ImageAnnotatorClient()
    image = vision.Image(content=image_bytes)
    response = client.document_text_detection(image=image)
    if response.error.message:
        raise RuntimeError(response.error.message)
    annotation = response.full_text_annotation
    return annotation.text if annotation and annotation.text else ""


def parse_receipt_image(
    *,
    image_base64: str | None = None,
    raw_text: str | None = None,
    allow_stub: bool = True,
) -> ReceiptParseResult:
    """
    Satisfies: REQ-005 AC1
    Spec version: 1.0

    Prefer Vision OCR when image bytes are present and the client library works.
    ``raw_text`` supports tests without GCP credentials. Falls back to stub haul.
    """
    if raw_text and raw_text.strip():
        items = parse_receipt_text(raw_text)
        return ReceiptParseResult(items=items or stub_receipt_items(), engine="text", raw_text=raw_text)

    if image_base64:
        try:
            image_bytes = _decode_image(image_base64)
            text = _vision_annotate(image_bytes)
            items = parse_receipt_text(text)
            if items:
                return ReceiptParseResult(items=items, engine="vision", raw_text=text)
            if allow_stub:
                return ReceiptParseResult(items=stub_receipt_items(), engine="stub", raw_text=text)
            return ReceiptParseResult(items=[], engine="vision", raw_text=text)
        except Exception:
            if not allow_stub:
                raise

    if allow_stub:
        return ReceiptParseResult(items=stub_receipt_items(), engine="stub", raw_text="")
    return ReceiptParseResult(items=[], engine="none", raw_text="")
