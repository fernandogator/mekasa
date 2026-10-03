"""Receipt line-item extraction with Gemini on Vertex AI (REQ-005).

Gemini reads the receipt photo (or pasted text) directly and returns structured
line items, expanding store abbreviations ("GV WHL MLK 1GAL") into product
names the catalog search can match. Any failure returns None so the caller
falls back to the Vision OCR + regex path in ``receipt_ocr``.
"""

from __future__ import annotations

import asyncio
import logging

from pydantic import BaseModel, Field

from app.barcode_codes import digits_only
from app.category_icons import category_placeholder_url
from app.config import Settings
from app.models import ReceiptLineItem
from app.receipt_ocr import ReceiptParseResult, decode_image

logger = logging.getLogger(__name__)

CATEGORIES = (
    "Produce",
    "Dairy",
    "Pantry",
    "Meat",
    "Frozen",
    "Beverages",
    "Household",
    "Other",
)

_PROMPT = f"""You extract purchased items from a grocery or household store receipt.

Return one entry per purchased product line. Rules:
- Skip totals, subtotals, tax, payment, change, loyalty, coupons and store info.
- Fold discount/coupon lines into the product they apply to (lower its price_paid).
- Expand store abbreviations into the most likely full product name, including
  brand when printed, e.g. "GV WHL MLK 1GAL" -> "Great Value Whole Milk 1 Gallon".
  Put the product text exactly as printed (without price or item code) in
  receipt_text.
- receipt_code is the UPC / item number printed on the line, digits only,
  or null when none is printed.
- quantity is the count purchased (weighed items count as 1).
- price_paid is the line total actually paid, in the receipt currency, as a number.
- category must be one of: {", ".join(CATEGORIES)}.
- store_name is the store brand as printed in the header, e.g. "Walmart",
  "Trader Joe's"; store_address is its street address. Null when not shown.
- If the image is not a receipt or nothing is legible, return an empty items list.
"""


class _ExtractedItem(BaseModel):
    name: str = Field(description="Full product name, abbreviations expanded")
    receipt_text: str = Field(description="Product text exactly as printed")
    receipt_code: str | None = Field(default=None, description="Printed UPC / item number")
    category: str
    quantity: int = 1
    price_paid: float | None = None


class _Extraction(BaseModel):
    store_name: str | None = None
    store_address: str | None = None
    items: list[_ExtractedItem]


def _image_mime(image_bytes: bytes) -> str:
    if image_bytes.startswith(b"\x89PNG"):
        return "image/png"
    if image_bytes[4:12] in (b"ftypheic", b"ftypheix", b"ftypmif1"):
        return "image/heic"
    if image_bytes.startswith(b"RIFF") and image_bytes[8:12] == b"WEBP":
        return "image/webp"
    return "image/jpeg"


def _to_line_item(extracted: _ExtractedItem) -> ReceiptLineItem | None:
    name = " ".join(extracted.name.split())[:120] or " ".join(extracted.receipt_text.split())[:120]
    if not name:
        return None
    category = extracted.category if extracted.category in CATEGORIES else "Other"
    price = extracted.price_paid if extracted.price_paid is not None and extracted.price_paid >= 0 else None
    code = digits_only(extracted.receipt_code)[:64] or None
    return ReceiptLineItem(
        name=name,
        category=category,
        quantity=min(max(extracted.quantity, 1), 9999),
        price_paid=round(price, 2) if price is not None else None,
        image_url=category_placeholder_url(category),
        identified=False,
        receipt_text=" ".join(extracted.receipt_text.split())[:200] or None,
        receipt_code=code,
    )


async def _generate(settings: Settings, contents: list) -> _Extraction:
    from google import genai  # type: ignore
    from google.genai import types  # type: ignore

    client = genai.Client(
        vertexai=True,
        project=settings.gcp_project_id,
        location=settings.gemini_location,
    )
    response = await client.aio.models.generate_content(
        model=settings.gemini_receipt_model,
        contents=contents,
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
            response_schema=_Extraction,
            temperature=0,
            thinking_config=types.ThinkingConfig(thinking_level=types.ThinkingLevel.LOW),
        ),
    )
    if isinstance(response.parsed, _Extraction):
        return response.parsed
    return _Extraction.model_validate_json(response.text or "")


async def parse_receipt_llm(
    settings: Settings,
    *,
    image_base64: str | None = None,
    raw_text: str | None = None,
) -> ReceiptParseResult | None:
    """
    Satisfies: REQ-005 AC1
    Spec version: 1.0

    Returns None when Gemini is disabled, errors, times out, or finds no items.
    """
    if not settings.receipt_llm_enabled or not settings.gcp_project_id:
        return None

    from google.genai import types  # type: ignore

    if raw_text and raw_text.strip():
        contents: list = [_PROMPT, f"Receipt text:\n{raw_text}"]
    elif image_base64:
        try:
            image_bytes = decode_image(image_base64)
        except Exception:
            return None
        contents = [
            types.Part.from_bytes(data=image_bytes, mime_type=_image_mime(image_bytes)),
            _PROMPT,
        ]
    else:
        return None

    try:
        extraction = await asyncio.wait_for(
            _generate(settings, contents),
            timeout=settings.gemini_timeout_seconds,
        )
    except Exception:
        logger.warning("Gemini receipt extraction failed; falling back to OCR", exc_info=True)
        return None

    items = [item for item in map(_to_line_item, extraction.items) if item is not None]
    if not items:
        return None
    return ReceiptParseResult(
        items=items,
        engine="gemini",
        raw_text="\n".join(extracted.receipt_text for extracted in extraction.items),
        store_name=(extraction.store_name or "").strip() or None,
        store_address=(extraction.store_address or "").strip() or None,
    )
