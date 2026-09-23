"""Receipt OCR parsing via Cloud Vision with catalog enrichment (REQ-005)."""

from __future__ import annotations

import asyncio
import base64
import re
from dataclasses import dataclass

from app.barcode_lookup import search_products
from app.category_icons import category_placeholder_url
from app.models import ReceiptLineItem

# Cap concurrent OFF lookups so a long receipt does not stampede the API.
_ENRICH_CONCURRENCY = 4


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

_CATEGORY_KEYWORDS = (
    (("banana", "apple", "avocado", "lettuce", "produce", "fruit", "veg"), "Produce"),
    (("milk", "cheese", "yogurt", "butter", "cream", "dairy"), "Dairy"),
    (("bread", "loaf", "cereal", "pasta", "rice", "cookie", "oreo", "snack"), "Pantry"),
    (("chicken", "beef", "pork", "meat", "turkey", "fish"), "Meat"),
    (("frozen", "ice cream"), "Frozen"),
    (("soda", "juice", "water", "coffee", "tea", "beverage"), "Beverages"),
    (("soap", "paper", "detergent", "cleaner"), "Household"),
)


def _guess_category(name: str) -> str:
    lowered = name.casefold()
    for needles, label in _CATEGORY_KEYWORDS:
        if any(needle in lowered for needle in needles):
            return label
    return "Other"


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
        display = name.title() if name.isupper() else name
        category = _guess_category(display)
        items.append(
            ReceiptLineItem(
                name=display,
                category=category,
                quantity=1,
                price_paid=price,
                image_url=category_placeholder_url(category),
                identified=False,
            )
        )
    return items


def stub_receipt_items() -> list[ReceiptLineItem]:
    """Deterministic demo haul used when Vision is unavailable."""
    return [
        ReceiptLineItem(
            name="Bananas",
            category="Produce",
            quantity=1,
            price_paid=1.29,
            image_url=category_placeholder_url("Produce"),
            identified=False,
        ),
        ReceiptLineItem(
            name="Whole Milk",
            category="Dairy",
            quantity=1,
            price_paid=3.49,
            image_url=category_placeholder_url("Dairy"),
            identified=False,
        ),
        ReceiptLineItem(
            name="Sourdough Loaf",
            category="Pantry",
            quantity=1,
            price_paid=4.99,
            image_url=category_placeholder_url("Pantry"),
            identified=False,
        ),
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


def _tokens(value: str) -> set[str]:
    return {part for part in re.split(r"[^a-z0-9]+", value.casefold()) if len(part) >= 2}


def _is_strong_match(ocr_name: str, hit_name: str) -> bool:
    """Require overlapping tokens so weak OFF hits stay unidentified."""
    from app.barcode_lookup import expand_match_tokens

    ocr = expand_match_tokens(_tokens(ocr_name))
    hit = expand_match_tokens(_tokens(hit_name))
    if not ocr or not hit:
        return False
    if ocr_name.casefold() in hit_name.casefold() or hit_name.casefold() in ocr_name.casefold():
        return True
    overlap = ocr & hit
    # At least one meaningful token, and majority of OCR tokens when short.
    if not overlap:
        return False
    raw_ocr = _tokens(ocr_name)
    if len(raw_ocr) <= 2:
        # Nickname expansion: "coke" vs "Coca-Cola" should match via synonyms.
        return bool(overlap)
    return len(overlap) >= max(1, len(raw_ocr) // 2)


async def enrich_receipt_item(item: ReceiptLineItem) -> ReceiptLineItem:
    """
    Match a parsed line against Open Food Facts.

    Always returns an image_url (catalog photo or category placeholder).
    Sets identified=True only when a strong name match is found.
    """
    placeholder = category_placeholder_url(item.category)
    try:
        search = await search_products(item.name, limit=3)
    except Exception:
        return item.model_copy(
            update={
                "image_url": item.image_url or placeholder,
                "identified": False,
            }
        )

    for hit in search.results:
        if not _is_strong_match(item.name, hit.name):
            continue
        return item.model_copy(
            update={
                "name": hit.name[:120],
                "category": hit.category or item.category,
                "barcode": hit.barcode,
                "image_url": hit.image_url or placeholder,
                "identified": True,
            }
        )

    return item.model_copy(
        update={
            "image_url": item.image_url or placeholder,
            "identified": False,
        }
    )


async def enrich_receipt_items(items: list[ReceiptLineItem]) -> list[ReceiptLineItem]:
    """Enrich lines in parallel with a small concurrency limit."""
    if not items:
        return []
    semaphore = asyncio.Semaphore(_ENRICH_CONCURRENCY)

    async def _one(item: ReceiptLineItem) -> ReceiptLineItem:
        async with semaphore:
            return await enrich_receipt_item(item)

    return list(await asyncio.gather(*(_one(item) for item in items)))


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
    Catalog enrichment is applied separately by the router (async OFF lookup).
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
