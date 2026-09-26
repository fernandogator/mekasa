"""Third-party barcode / UPC / name product lookup (Open Food Facts family)."""

from __future__ import annotations

import asyncio
import logging
import re
import time

import httpx

from app.barcode_codes import candidates as barcode_candidates
from app.barcode_codes import digits_only
from app.category_icons import category_placeholder_url
from app.models import BarcodeLookupResponse, ProductSearchHit, ProductSearchResponse
from app.product_health import health_from_off_product

logger = logging.getLogger(__name__)

OFF_PRODUCT_URL = "https://world.openfoodfacts.org/api/v2/product/{code}"
OFF_SEARCH_URL = "https://world.openfoodfacts.org/cgi/search.pl"
USER_AGENT = "Mekasa/0.4 (https://github.com/fernandogator/mekasa)"

# Sister databases share the OFF API shape; queried when OFF has no record so
# household / beauty / pet products stop coming back as "unknown".
PRODUCT_SOURCES: tuple[tuple[str, str], ...] = (
    ("openfoodfacts", OFF_PRODUCT_URL),
    ("openproductsfacts", "https://world.openproductsfacts.org/api/v2/product/{code}"),
    ("openbeautyfacts", "https://world.openbeautyfacts.org/api/v2/product/{code}"),
    ("openpetfoodfacts", "https://world.openpetfoodfacts.org/api/v2/product/{code}"),
)

LOOKUP_TIMEOUT_SECONDS = 5.0
LOOKUP_ATTEMPTS = 2
# Positive hits are stable; misses are retried sooner because contributors add
# products daily and a miss may also have been a partial outage.
CACHE_TTL_FOUND_SECONDS = 6 * 60 * 60
CACHE_TTL_MISS_SECONDS = 15 * 60
CACHE_MAX_ENTRIES = 2000

# REQ-021: health grade + allergen inputs requested alongside the catalog fields.
OFF_HEALTH_FIELDS = (
    "nutriscore_grade,nutrition_grades,nova_group,additives_tags,allergens_tags,"
    "traces_tags,ingredients_text,ingredients_text_en,ingredients_analysis_tags"
)
# OFF has no wildcard for localised names, so the common ones are listed explicitly.
_LOCALISED_NAME_FIELDS = ",".join(
    f"product_name_{lang}" for lang in ("es", "fr", "de", "it", "pt", "nl", "pl", "ja", "zh", "ko", "ar", "ru")
)
OFF_PRODUCT_FIELDS = (
    "code,product_name,product_name_en,abbreviated_product_name,generic_name,"
    f"generic_name_en,{_LOCALISED_NAME_FIELDS},brands,categories,categories_tags,"
    "image_front_url,image_url,image_front_small_url,"
    + OFF_HEALTH_FIELDS
)


class ProductLookupUnavailableError(RuntimeError):
    """Every product-database call failed (timeout / 429 / 5xx); the code may still exist."""

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
    (("milk", "dairy", "dairies", "cheese", "yogurt", "yoghurt", "cream"), "Dairy"),
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
        (
            "cereal", "pasta", "rice", "bread", "snack", "sauce", "oil", "pantry",
            "cookie", "biscuit", "spread", "chocolate", "candy", "sweet", "cracker",
            "can", "canned", "soup", "flour", "sugar", "spice", "condiment",
        ),
        "Pantry",
    ),
    # Word-ish produce needles (avoid matching "fruit" inside "jus de fruit" for sodas
    # that already matched Beverages above).
    (("vegetable", "produce", "banana", "apple", "fruits", "vegetables"), "Produce"),
)


def _humanize_tag(tag: str) -> str:
    value = tag.removeprefix("en:").replace("-", " ").strip()
    return value[:1].upper() + value[1:] if value else "Other"


def _word_in(needle: str, haystack: str) -> bool:
    """
    Whole-word match with optional plural, so "cola" no longer hits "chocolate" and
    "tea" no longer hits "steak" (both used to classify as Beverages).
    """
    pattern = rf"(?<![a-z]){re.escape(needle)}(?:s|es)?(?![a-z])"
    return re.search(pattern, haystack) is not None


def _map_category(tags: list[str] | None, categories: str | None) -> str:
    haystack = " ".join(tags or [])
    if categories:
        haystack = f"{haystack} {categories}"
    lowered = haystack.casefold()
    for needles, label in _CATEGORY_MAP:
        if any(_word_in(needle, lowered) for needle in needles):
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


_NAME_KEYS = (
    "product_name",
    "product_name_en",
    "abbreviated_product_name",
    "generic_name",
    "generic_name_en",
)


def _product_name(product: dict) -> str:
    """
    First usable name: English keys, then any localised `product_name_xx`.

    OFF records added from a non-English locale often carry only `product_name_es`
    (etc.); previously those were reported as "not found" despite a full record.
    """
    for key in _NAME_KEYS:
        value = product.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    for key in sorted(product):
        if key.startswith("product_name_") and isinstance(product[key], str) and product[key].strip():
            return product[key].strip()
    return ""


def _display_name(product: dict) -> str | None:
    name = _product_name(product)
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
        health=health_from_off_product(product),
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
    """
    GET JSON with short backoff on 429 / 5xx / transport errors.

    Raises httpx.HTTPError after the last attempt so callers can tell an upstream
    outage from a genuine "not found" (a 404 is returned as `{}` with no raise).
    """
    last_error: Exception | None = None
    for attempt in range(retries):
        try:
            response = await http.get(url, params=params)
            if response.status_code == 404:
                return {}
            if response.status_code == 429 or response.status_code >= 500:
                last_error = httpx.HTTPStatusError(
                    f"upstream {response.status_code}",
                    request=response.request,
                    response=response,
                )
                if attempt + 1 < retries:
                    await asyncio.sleep(_retry_delay(response, attempt))
                    continue
                response.raise_for_status()
            response.raise_for_status()
            try:
                payload = response.json()
            except ValueError:
                # OFF's maintenance page is HTML with a 200 on some edges.
                payload = {}
            return payload if isinstance(payload, dict) else {}
        except httpx.HTTPError as exc:
            last_error = exc
            if attempt + 1 < retries:
                await asyncio.sleep(0.35 * (attempt + 1))
                continue
            raise
    assert last_error is not None
    raise last_error


def _retry_delay(response: httpx.Response, attempt: int) -> float:
    headers = getattr(response, "headers", None)
    retry_after = headers.get("Retry-After") if isinstance(headers, httpx.Headers) else None
    if isinstance(retry_after, str) and retry_after.strip().isdigit():
        return min(float(retry_after), 2.0)
    return 0.35 * (attempt + 1)


def _off_key(code: str) -> str:
    """How the OFF family stores a code: EAN-8 shapes stay 8 digits, everything else pads to 13."""
    if len(code) <= 8:
        return code.zfill(8)
    if len(code) < 13:
        return code.zfill(13)
    return code


def lookup_keys(code: str) -> list[str]:
    """Distinct codes to query for a scanned value (UPC-E expanded, UPC-A padded)."""
    keys: list[str] = []
    for candidate in barcode_candidates(code):
        key = _off_key(candidate)
        if key not in keys:
            keys.append(key)
    return keys


_CACHE: dict[str, tuple[float, BarcodeLookupResponse]] = {}


def clear_lookup_cache() -> None:
    _CACHE.clear()


def _cache_get(keys: list[str]) -> BarcodeLookupResponse | None:
    now = time.monotonic()
    for key in keys:
        entry = _CACHE.get(key)
        if entry is None:
            continue
        expires_at, cached = entry
        if expires_at <= now:
            _CACHE.pop(key, None)
            continue
        return cached
    return None


def _cache_put(keys: list[str], result: BarcodeLookupResponse) -> None:
    ttl = CACHE_TTL_FOUND_SECONDS if result.found else CACHE_TTL_MISS_SECONDS
    expires_at = time.monotonic() + ttl
    if len(_CACHE) >= CACHE_MAX_ENTRIES:
        for stale in sorted(_CACHE, key=lambda k: _CACHE[k][0])[: CACHE_MAX_ENTRIES // 10]:
            _CACHE.pop(stale, None)
    for key in keys:
        _CACHE[key] = (expires_at, result)


async def _fetch_product(
    http: httpx.AsyncClient,
    source: str,
    url_template: str,
    code: str,
) -> tuple[dict | None, bool]:
    """
    Return (product, upstream_failed).

    product is the OFF-style dict when the database knows the code, None otherwise.
    upstream_failed is True when the call itself failed (timeout / 429 / 5xx).
    """
    try:
        payload = await _get_json_with_retry(
            http,
            url_template.format(code=code),
            params={"fields": OFF_PRODUCT_FIELDS},
            retries=LOOKUP_ATTEMPTS,
        )
    except httpx.HTTPError as exc:
        logger.warning("barcode lookup %s %s failed: %s", source, code, exc)
        return None, True
    if payload.get("status") != 1 or not isinstance(payload.get("product"), dict):
        return None, False
    return payload["product"], False


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


async def lookup_barcode(
    code: str,
    *,
    client: httpx.AsyncClient | None = None,
    raise_when_unavailable: bool = False,
) -> BarcodeLookupResponse:
    """
    Satisfies: REQ-004 (AC1, AC2, AC6, AC7), ADR-006 (OFF image primary)
    Spec version: 1.0

    Resolve a scanned UPC/EAN against the Open Food Facts family of databases.

    * Every equivalent code shape is tried (UPC-E expanded to UPC-A, 12 → 13 digits),
      because contributors save the same product under different shapes.
    * Open Food Facts is asked first; Open Products / Beauty / Pet Food Facts are
      queried in parallel when OFF has no record.
    * Results (hits and misses) are cached in-process to stay inside OFF rate limits.
    * Unknown codes return found=False. When *every* database call failed and
      `raise_when_unavailable` is set, ProductLookupUnavailableError is raised so the
      API can answer 503 instead of pretending the product does not exist.
    """
    cleaned = digits_only(code)
    if len(cleaned) < 6:
        return BarcodeLookupResponse(barcode=cleaned or code, found=False, source="none")

    keys = lookup_keys(cleaned)
    cached = _cache_get(keys)
    if cached is not None:
        return cached.model_copy(update={"barcode": cleaned})

    owns_client = client is None
    http = client or httpx.AsyncClient(
        timeout=LOOKUP_TIMEOUT_SECONDS, headers={"User-Agent": USER_AGENT}
    )
    try:
        primary_source, primary_url = PRODUCT_SOURCES[0]
        primary = await asyncio.gather(
            *(_fetch_product(http, primary_source, primary_url, key) for key in keys)
        )
        upstream_failed = any(failed for _, failed in primary)
        for key, (product, _) in zip(keys, primary):
            hit = _response_from_product(product, cleaned, key, primary_source)
            if hit is not None:
                _cache_put(keys, hit)
                return hit

        secondary = [
            (source, url, key)
            for source, url in PRODUCT_SOURCES[1:]
            for key in keys
        ]
        results = await asyncio.gather(
            *(_fetch_product(http, source, url, key) for source, url, key in secondary)
        )
        for (source, _, key), (product, failed) in zip(secondary, results):
            upstream_failed = upstream_failed or failed
            hit = _response_from_product(product, cleaned, key, source)
            if hit is not None:
                _cache_put(keys, hit)
                return hit

        if upstream_failed:
            logger.warning("barcode %s: product databases unavailable", cleaned)
            if raise_when_unavailable:
                raise ProductLookupUnavailableError(cleaned)
            # Do not cache: the code may exist and the outage is transient.
            return BarcodeLookupResponse(barcode=cleaned, found=False, source="none")

        logger.info("barcode %s: not in any product database (tried %s)", cleaned, keys)
        miss = BarcodeLookupResponse(barcode=cleaned, found=False, source="none")
        _cache_put(keys, miss)
        return miss
    finally:
        if owns_client:
            await http.aclose()


def _response_from_product(
    product: dict | None,
    scanned: str,
    key: str,
    source: str,
) -> BarcodeLookupResponse | None:
    if product is None:
        return None
    name = _display_name(product)
    if not name:
        logger.info("barcode %s: %s record %s has no name yet", scanned, source, key)
        return None
    category = _map_category(product.get("categories_tags"), product.get("categories"))
    return BarcodeLookupResponse(
        barcode=scanned,
        found=True,
        name=name,
        brand=_brand(product),
        category=category,
        quantity=1,
        image_url=_product_image_url(product, category),
        source=source,  # type: ignore[arg-type]
        health=health_from_off_product(product),
    )


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

        attempted = 0
        failed = 0
        for terms in expand_search_queries(cleaned):
            if len(results) >= limit:
                break
            attempted += 1
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
            except httpx.HTTPError as exc:
                failed += 1
                logger.warning("product search %r failed: %s", terms, exc)
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

        if not results and attempted and failed == attempted:
            # OFF search is rate limited to ~10 req/min per IP and returns 503 during
            # maintenance; surface that instead of an empty result list.
            raise ProductLookupUnavailableError(cleaned)
        return ProductSearchResponse(query=cleaned, results=results)
    finally:
        if owns_client:
            await http.aclose()
