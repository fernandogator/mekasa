"""Google Places nearby store lookup (REQ-003)."""

from __future__ import annotations

import math
from typing import Any

import httpx

from app.models import Store

PLACES_NEARBY_URL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
USER_AGENT = "Mekasa/0.5 (https://github.com/fernandogator/mekasa)"

# Prefer grocery / big-box retail for household shopping.
_PLACE_TYPES = ("supermarket", "grocery_or_supermarket", "department_store")


def _haversine_miles(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    radius = 3958.8
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * radius * math.asin(math.sqrt(a))


def _store_from_place(place: dict[str, Any], *, origin_lat: float, origin_lng: float) -> Store | None:
    place_id = place.get("place_id")
    name = (place.get("name") or "").strip()
    geometry = place.get("geometry") or {}
    location = geometry.get("location") or {}
    lat = location.get("lat")
    lng = location.get("lng")
    if not place_id or not name or lat is None or lng is None:
        return None
    address = (place.get("vicinity") or place.get("formatted_address") or "").strip() or "Address unavailable"
    return Store(
        id=str(place_id),
        name=name,
        address=address,
        latitude=float(lat),
        longitude=float(lng),
        distance_miles=round(_haversine_miles(origin_lat, origin_lng, float(lat), float(lng)), 2),
        provider="places",
    )


async def fetch_nearby_stores(
    *,
    latitude: float,
    longitude: float,
    radius_miles: float,
    api_key: str,
    client: httpx.AsyncClient | None = None,
) -> list[Store]:
    """
    Satisfies: REQ-003 AC4
    Spec version: 1.0

    Queries Google Places Nearby Search. Caller falls back to stub on failure/empty key.
    """
    radius_meters = max(100, min(int(radius_miles * 1609.34), 50000))
    owns_client = client is None
    http = client or httpx.AsyncClient(timeout=8.0, headers={"User-Agent": USER_AGENT})
    by_id: dict[str, Store] = {}
    try:
        for place_type in _PLACE_TYPES:
            response = await http.get(
                PLACES_NEARBY_URL,
                params={
                    "key": api_key,
                    "location": f"{latitude},{longitude}",
                    "radius": radius_meters,
                    "type": place_type,
                },
            )
            response.raise_for_status()
            payload = response.json()
            status = payload.get("status")
            if status not in {"OK", "ZERO_RESULTS"}:
                continue
            for place in payload.get("results") or []:
                if not isinstance(place, dict):
                    continue
                store = _store_from_place(place, origin_lat=latitude, origin_lng=longitude)
                if store is None:
                    continue
                if store.distance_miles > radius_miles:
                    continue
                by_id.setdefault(store.id, store)
    finally:
        if owns_client:
            await http.aclose()

    return sorted(by_id.values(), key=lambda item: item.distance_miles)
