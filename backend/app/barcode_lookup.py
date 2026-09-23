"""Third-party barcode / UPC / name product lookup (Open Food Facts)."""

from __future__ import annotations

import asyncio
import re

import httpx

from app.category_icons import category_placeholder_url
from app.models import BarcodeLookupResponse, ProductSearchHit, ProductSearchResponse

OFF_PRODUCT_URL = "https://world.openfoodfacts.org/api/v2/product/{code}"
OFF_SEARCH_URL = "https://world.openfoodfacts.org/cgi/search.pl"
USER_AGENT = "Mekasa/0.4 (https://github.com/fernandogator/mekasa)"

# Brand nicknames → OFF-friendly search terms (voice / manual / receipt).
_SEARCH_ALIASES: dict[str, tuple[str, ...]] = {
    "coke": ("coca-cola", "coca cola", "cola"),
    "diet coke": ("diet coca-cola", "coca-cola light", "diet cola"),
    "coke zero": ("coca-cola zero", "coke zero sugar", "coca cola zero"),
    "pepsi": ("pepsi-cola", "pepsi cola"),
    "diet pepsi": ("pepsi light", "diet pepsi cola"),
}

# Receipt / match token synonyms so "coke" overlaps "Coca-Cola".
_TOKEN_SYNONYMS: dict[str, frozenset[str]] = {
    "coke": frozenset({"coke", "coca", "cola"}),
    "coca": frozenset({"coke", "coca", "cola"}),
    "cola": frozenset({"coke", "coca", "cola"}),
}

# Prefer beverages before produce so "jus de fruit" does not steal soda hits.
_CATEGORY_MAP = (
    (("milk", "dairy", "cheese", "yogurt", "cream"), "Dairy"),
    (("meat", "poultry", "fish", "seafood", "beef", "chicken"), "Meat"),
    (("frozen",), "Frozen"),
    (
        (
            "beverage",
            "beverages",
            "drink",
            "drinks",
            "juice",
            "soda",
            "sodas",
            "cola",
            "coke",
            "soft-drink",
            "soft drinks",
            "water",
            "coffee",
            "tea",
        ),
        "Beverages",
    ),
    (("household", "cleaning", "detergent", "soap", "paper"), "Household"),
    (
        ("cereal", "pasta", "rice", "bread", "snack", "sauce", "oil", "pantry", "cookie", "biscuit"),
        "Pantry",
    ),
    # Word-ish produce needles (avoid matching "fruit" inside "jus de fruit" for sodas
    # that already matched Beverages above).
    (("vegetable", "produce", "banana", "apple", "fruits", "vegetables"), "Produce"),
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
    # Produce "fruit" only as a standalone tag token, not substring of "jus de fruit".
    if re.search(r"(?:^|[\s,:])fruit(?:s)?(?:$|[\s,:])", lowered):
        return "Produce"
    if tags:
        return _humanize_tag(tags[0])
    return "Other"


def _brand(product: dict) -> str | None:
    """Prefer a short consumer brand over corporate legal names."""
    raw = (product.get("brands") or "").strip()
    if not raw:
        return None
    parts = [part.strip() for part in raw.split(",") if part.strip()]
    if not parts:
        return None

    def _score(part: str) -> tuple[int, int, str]:
        lowered = part.casefold()
        corporate = int(
            any(
                marker in lowered
                for marker in ("services", "sa/nv", " inc", " llc", " ltd", " company", " co.")
            )
        )
        return (corporate, len(part), lowered)

    best = sorted(parts, key=_score)[0]
    if len(best) > 48:
        best = best[:48].rstrip()
    return best or None


def _display_name(product: dict) -> str | None:
    name = (product.get("product_name") or product.get("product_name_en") or "").strip()
    brand = _brand(product)
    if name and brand and brand.casefold() not in name.casefold():
        return f"{brand} {name}"
    if name:
        return name
    if brand:
        return brand
    return None


def _barcode(product: dict) -> str | None:
    for key in ("code", "id"):
        value = product.get(key)
        if value is None:
            continue
        cleaned = re.sub(r"\D", "", str(value))
        if len(cleaned) >= 6:
            return cleaned
    return None


def _product_image_url(product: dict, category: str) -> str:
    """
    ADR-006 step 1 + step 3 (ItemDB deferred).

    Prefer Open Food Facts front/image URLs; otherwise category placeholder.
    Always returns a non-empty string.
    """
    for key in ("image_front_url", "image_url", "image_front_small_url"):
        value = product.get(key)
        if isinstance(value, str) and value.strip().startswith("http"):
            return value.strip()
    return category_placeholder_url(category)


def _hit_from_product(product: dict) -> ProductSearchHit | None:
    name = _display_name(product)
    if not name:
        return None
    category = _map_category(product.get("categories_tags"), product.get("categories"))
    return ProductSearchHit(
        barcode=_barcode(product),
        name=name,
        brand=_brand(product),
        category=category,
        image_url=_product_image_url(product, category),
        source="openfoodfacts",
    )


def expand_search_queries(query: str) -> list[str]:
    """
    Expand brand nicknames (e.g. coke → coca-cola) for OFF search.

    Primary query is always first; aliases follow in preference order.
    """
    cleaned = " ".join((query or "").split()).strip()
    if not cleaned:
        return []
    queries: list[str] = [cleaned]
    key = cleaned.casefold()
    if key in _SEARCH_ALIASES:
        queries.extend(_SEARCH_ALIASES[key])
    else:
        tokens = {part for part in re.split(r"[^a-z0-9]+", key) if part}
        if "coke" in tokens and "coca" not in tokens:
            queries.append(re.sub(r"\bcoke\b", "coca-cola", key, flags=re.IGNORECASE))
            queries.append(re.sub(r"\bcoke\b", "cola", key, flags=re.IGNORECASE))
        for alias_key, expansions in _SEARCH_ALIASES.items():
            if " " in alias_key and alias_key in key:
                queries.extend(expansions)
                break

    seen: set[str] = set()
    ordered: list[str] = []
    for item in queries:
        normalized = " ".join(item.split()).strip()
        fold = normalized.casefold()
        if len(normalized) < 2 or fold in seen:
            continue
        seen.add(fold)
        ordered.append(normalized)
    return ordered


def expand_match_tokens(tokens: set[str]) -> set[str]:
    """Expand brand nickname tokens for receipt strong-match."""
    expanded = set(tokens)
    for token in tokens:
        expanded |= _TOKEN_SYNONYMS.get(token, frozenset())
    return expanded


async def _get_json_with_retry(
    http: httpx.AsyncClient,
    url: str,
    *,
    params: dict[str, str],
    retries: int = 3,
) -> dict:
    """GET JSON with short backoff on 5xx / transport errors."""
    last_error: Exception | None = None
    for attempt in range(retries):
        try:
            response = await http.get(url, params=params)
            if response.status_code >= 500:
                last_error = httpx.HTTPStatusError(
                    f"OFF {response.status_code}",
                    request=response.request,
                    response=response,
                )
                if attempt + 1 < retries:
                    await asyncio.sleep(0.35 * (attempt + 1))
                    continue
                response.raise_for_status()
            response.raise_for_status()
            payload = response.json()
            return payload if isinstance(payload, dict) else {}
        except httpx.HTTPError as exc:
            last_error = exc
            if attempt + 1 < retries:
                await asyncio.sleep(0.35 * (attempt + 1))
                continue
            raise
    assert last_error is not None
    raise last_error


def _collect_hits(
    products: list,
    *,
    limit: int,
    seen_barcodes: set[str],
    seen_names: set[str],
    results: list[ProductSearchHit],
) -> None:
    for product in products:
        if len(results) >= limit:
            return
        if not isinstance(product, dict):
            continue
        hit = _hit_from_product(product)
        if hit is None:
            continue
        if hit.barcode and hit.barcode in seen_barcodes:
            continue
        name_key = hit.name.casefold()
        if name_key in seen_names:
            continue
        if hit.barcode:
            seen_barcodes.add(hit.barcode)
        seen_names.add(name_key)
        results.append(hit)


async def lookup_barcode(code: str, *, client: httpx.AsyncClient | None = None) -> BarcodeLookupResponse:
    """
    Satisfies: REQ-004, ADR-006 (OFF image primary)
    Spec version: 1.0

    Query Open Food Facts for a UPC/EAN. Unknown codes return found=False.
    """
    cleaned = re.sub(r"\D", "", code or "")
    if len(cleaned) < 6:
        return BarcodeLookupResponse(barcode=cleaned or code, found=False, source="none")

    owns_client = client is None
    http = client or httpx.AsyncClient(timeout=8.0, headers={"User-Agent": USER_AGENT})
    try:
        last_status: int | None = None
        payload: dict = {}
        for attempt in range(3):
            try:
                response = await http.get(
                    OFF_PRODUCT_URL.format(code=cleaned),
                    params={
                        "fields": (
                            "product_name,product_name_en,brands,categories,categories_tags,"
                            "image_front_url,image_url,image_front_small_url"
                        )
                    },
                )
                last_status = response.status_code
                if response.status_code == 404:
                    return BarcodeLookupResponse(barcode=cleaned, found=False, source="none")
                if response.status_code >= 500:
                    if attempt + 1 < 3:
                        await asyncio.sleep(0.35 * (attempt + 1))
                        continue
                    response.raise_for_status()
                response.raise_for_status()
                raw = response.json()
                payload = raw if isinstance(raw, dict) else {}
                break
            except httpx.HTTPError:
                if attempt + 1 < 3:
                    await asyncio.sleep(0.35 * (attempt + 1))
                    continue
                return BarcodeLookupResponse(barcode=cleaned, found=False, source="none")
        else:
            return BarcodeLookupResponse(barcode=cleaned, found=False, source="none")

        if last_status == 404:
            return BarcodeLookupResponse(barcode=cleaned, found=False, source="none")
        if payload.get("status") != 1 or not isinstance(payload.get("product"), dict):
            return BarcodeLookupResponse(barcode=cleaned, found=False, source="none")
        product = payload["product"]
        name = _display_name(product)
        if not name:
            return BarcodeLookupResponse(barcode=cleaned, found=False, source="none")
        category = _map_category(product.get("categories_tags"), product.get("categories"))
        return BarcodeLookupResponse(
            barcode=cleaned,
            found=True,
            name=name,
            brand=_brand(product),
            category=category,
            quantity=1,
            image_url=_product_image_url(product, category),
            source="openfoodfacts",
        )
    finally:
        if owns_client:
            await http.aclose()


async def search_products(
    query: str,
    *,
    limit: int = 8,
    client: httpx.AsyncClient | None = None,
) -> ProductSearchResponse:
    """
    Satisfies: REQ-006, REQ-007 AC2
    Spec version: 1.0

    Full-text product search via Open Food Facts (legacy cgi/search.pl).
    Expands brand nicknames (coke → coca-cola) and retries transient OFF failures.
    """
    cleaned = " ".join((query or "").split()).strip()
    limit = max(1, min(limit, 20))
    if len(cleaned) < 2:
        return ProductSearchResponse(query=cleaned, results=[])

    owns_client = client is None
    http = client or httpx.AsyncClient(timeout=10.0, headers={"User-Agent": USER_AGENT})
    try:
        page_size = min(40, max(limit * 3, limit))
        results: list[ProductSearchHit] = []
        seen_barcodes: set[str] = set()
        seen_names: set[str] = set()

        for terms in expand_search_queries(cleaned):
            if len(results) >= limit:
                break
            try:
                payload = await _get_json_with_retry(
                    http,
                    OFF_SEARCH_URL,
                    params={
                        "search_terms": terms,
                        "search_simple": "1",
                        "action": "process",
                        "json": "1",
                        "page_size": str(page_size),
                        "sort_by": "unique_scans_n",
                    },
                )
            except httpx.HTTPError:
                continue
            products = payload.get("products")
            if not isinstance(products, list):
                continue
            _collect_hits(
                products,
                limit=limit,
                seen_barcodes=seen_barcodes,
                seen_names=seen_names,
                results=results,
            )

        return ProductSearchResponse(query=cleaned, results=results)
    finally:
        if owns_client:
            await http.aclose()
