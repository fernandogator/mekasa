"""Third-party barcode / UPC product lookup (Open Food Facts)."""

from __future__ import annotations

import re

import httpx

from app.models import BarcodeLookupResponse

OFF_PRODUCT_URL = "https://world.openfoodfacts.org/api/v2/product/{code}"
USER_AGENT = "Mekasa/0.3 (https://github.com/fernandogator/mekasa)"

_CATEGORY_MAP = (
    (("milk", "dairy", "cheese", "yogurt", "cream"), "Dairy"),
    (("fruit", "vegetable", "produce", "banana", "apple"), "Produce"),
    (("meat", "poultry", "fish", "seafood", "beef", "chicken"), "Meat"),
    (("frozen",), "Frozen"),
    (("beverage", "drink", "juice", "soda", "water", "coffee", "tea"), "Beverages"),
    (("household", "cleaning", "detergent", "soap", "paper"), "Household"),
    (("cereal", "pasta", "rice", "bread", "snack", "sauce", "oil", "pantry"), "Pantry"),
)


def _humanize_tag(tag: str) -> str:
    value = tag.removeprefix("en:").replace("-", " ").strip()
    return value[:1].upper() + value[1:] if value else "Other"


def _map_category(tags: list[str] | None, categories: str | None) -> str:
    haystack = " ".join(tags or [])
    if categories:
        haystack = f"{haystack} {categories}"
    lowered = haystack.casefold()
    for needles, label in _CATEGORY_MAP:
        if any(needle in lowered for needle in needles):
            return label
    if tags:
        return _humanize_tag(tags[0])
    return "Other"


def _display_name(product: dict) -> str | None:
    name = (product.get("product_name") or product.get("product_name_en") or "").strip()
    brand = (product.get("brands") or "").split(",")[0].strip()
    if name and brand and brand.casefold() not in name.casefold():
        return f"{brand} {name}"
    if name:
        return name
    if brand:
        return brand
    return None


async def lookup_barcode(code: str, *, client: httpx.AsyncClient | None = None) -> BarcodeLookupResponse:
    """
    Satisfies: REQ-004
    Spec version: 1.0

    Query Open Food Facts for a UPC/EAN. Unknown codes return found=False.
    """
    cleaned = re.sub(r"\D", "", code or "")
    if len(cleaned) < 6:
        return BarcodeLookupResponse(barcode=cleaned or code, found=False, source="none")

    owns_client = client is None
    http = client or httpx.AsyncClient(timeout=8.0, headers={"User-Agent": USER_AGENT})
    try:
        response = await http.get(
            OFF_PRODUCT_URL.format(code=cleaned),
            params={"fields": "product_name,product_name_en,brands,categories,categories_tags"},
        )
        if response.status_code == 404:
            return BarcodeLookupResponse(barcode=cleaned, found=False, source="none")
        response.raise_for_status()
        payload = response.json()
        if payload.get("status") != 1 or not isinstance(payload.get("product"), dict):
            return BarcodeLookupResponse(barcode=cleaned, found=False, source="none")
        product = payload["product"]
        name = _display_name(product)
        if not name:
            return BarcodeLookupResponse(barcode=cleaned, found=False, source="none")
        return BarcodeLookupResponse(
            barcode=cleaned,
            found=True,
            name=name,
            brand=(product.get("brands") or None),
            category=_map_category(product.get("categories_tags"), product.get("categories")),
            quantity=1,
            source="openfoodfacts",
        )
    except httpx.HTTPError:
        return BarcodeLookupResponse(barcode=cleaned, found=False, source="none")
    finally:
        if owns_client:
            await http.aclose()
