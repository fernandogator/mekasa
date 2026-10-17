"""Google Places nearby store lookup and address geocoding (REQ-003).

Uses Places API (New): Google no longer lets new projects enable the
legacy Places API.
"""

from __future__ import annotations

import math
from typing import Any

import httpx

from app.models import Store
from app.store_chains import resolve_store_chain

PLACES_NEARBY_URL = "https://places.googleapis.com/v1/places:searchNearby"
GEOCODE_URL = "https://maps.googleapis.com/maps/api/geocode/json"
USER_AGENT = "Mekasa/0.5 (https://github.com/fernandogator/mekasa)"
FIELD_MASK = "places.id,places.displayName,places.shortFormattedAddress,places.formattedAddress,places.location"

GROCERY_TYPES = ["grocery_store", "supermarket", "warehouse_store"]
# Department and discount stores only count when they are a chain we know
# sells groceries (Walmart, Target), so the list isn't filled with malls.
BIG_BOX_TYPES = ["department_store", "discount_store"]
MAX_RESULTS = 20
MAX_RADIUS_METERS = 50_000


def _haversine_miles(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    radius = 3958.8
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * radius * math.asin(math.sqrt(a))


def _store_from_place(place: dict[str, Any], *, origin_lat: float, origin_lng: float) -> Store | None:
    """
    Satisfies: REQ-003
    Acceptance criteria: AC4, AC8
    Spec version: 1.0
    """
    place_id = place.get("id")
    name = ((place.get("displayName") or {}).get("text") or "").strip()
    location = place.get("location") or {}
    lat = location.get("latitude")
    lng = location.get("longitude")
    if not place_id or not name or lat is None or lng is None:
        return None
    address = (place.get("shortFormattedAddress") or place.get("formattedAddress") or "").strip() or "Address unavailable"
    return Store(
        id=str(place_id),
        name=name,
        address=address,
        latitude=float(lat),
        longitude=float(lng),
        distance_miles=round(_haversine_miles(origin_lat, origin_lng, float(lat), float(lng)), 2),
        provider="places",
    )


async def _search(
    http: httpx.AsyncClient,
    *,
    api_key: str,
    types: list[str],
    latitude: float,
    longitude: float,
    radius_meters: float,
) -> list[dict[str, Any]]:
    response = await http.post(
        PLACES_NEARBY_URL,
        headers={"X-Goog-Api-Key": api_key, "X-Goog-FieldMask": FIELD_MASK},
        json={
            "includedTypes": types,
            "maxResultCount": MAX_RESULTS,
            "rankPreference": "DISTANCE",
            "locationRestriction": {
                "circle": {"center": {"latitude": latitude, "longitude": longitude}, "radius": radius_meters}
            },
        },
    )
    response.raise_for_status()
    places = response.json().get("places") or []
    return [place for place in places if isinstance(place, dict)]


async def fetch_nearby_stores(
    *,
    latitude: float,
    longitude: float,
    radius_miles: float,
    api_key: str,
    client: httpx.AsyncClient | None = None,
) -> list[Store]:
    """
    Satisfies: REQ-003
    Acceptance criteria: AC4, AC8
    Spec version: 1.0

    Grocery stores, supermarkets and warehouse clubs, plus Walmart and
    Target, within the radius and sorted by distance. Raises on HTTP errors;
    the caller decides what to fall back to.
    """
    radius_meters = float(max(100, min(int(radius_miles * 1609.34), MAX_RADIUS_METERS)))
    owns_client = client is None
    http = client or httpx.AsyncClient(timeout=8.0, headers={"User-Agent": USER_AGENT})
    by_id: dict[str, Store] = {}
    try:
        for types, chains_only in ((GROCERY_TYPES, False), (BIG_BOX_TYPES, True)):
            places = await _search(
                http, api_key=api_key, types=types, latitude=latitude, longitude=longitude, radius_meters=radius_meters
            )
            for place in places:
                store = _store_from_place(place, origin_lat=latitude, origin_lng=longitude)
                if store is None or store.distance_miles > radius_miles:
                    continue
                if chains_only and resolve_store_chain(store.name) not in {"walmart", "target", "costco"}:
                    continue
                by_id.setdefault(store.id, store)
    finally:
        if owns_client:
            await http.aclose()

    return sorted(by_id.values(), key=lambda item: item.distance_miles)


async def geocode_address(
    address: str,
    *,
    api_key: str,
    client: httpx.AsyncClient | None = None,
) -> tuple[float, float] | None:
    """
    Satisfies: REQ-003
    Acceptance criteria: AC7
    Spec version: 1.0

    Coordinates of the best match, or None when nothing matches. Raises on
    HTTP errors.
    """
    owns_client = client is None
    http = client or httpx.AsyncClient(timeout=8.0, headers={"User-Agent": USER_AGENT})
    try:
        response = await http.get(GEOCODE_URL, params={"address": address, "key": api_key})
        response.raise_for_status()
        payload = response.json()
    finally:
        if owns_client:
            await http.aclose()
    if payload.get("status") != "OK":
        return None
    location = ((payload.get("results") or [{}])[0].get("geometry") or {}).get("location") or {}
    lat, lng = location.get("lat"), location.get("lng")
    if lat is None or lng is None:
        return None
    return float(lat), float(lng)
