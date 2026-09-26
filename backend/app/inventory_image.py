"""Resolve and persist missing inventory product images (ADR-006)."""

from __future__ import annotations

from app.barcode_lookup import lookup_barcode
from app.category_icons import category_placeholder_url
from app.models import InventoryItemResponse, InventoryItemUpdateRequest


async def resolve_missing_image_url(item: InventoryItemResponse) -> str | None:
    """
    Return an image URL for an item that has none, or None if lookup cannot help yet.

    Barcoded items: Open Food Facts (with category placeholder when OFF has no photo).
    Manual items: category placeholder. Transient/unknown barcode misses leave None
    so a later open can retry.
    """
    if item.image_url:
        return item.image_url

    if item.barcode and item.barcode.strip():
        hit = await lookup_barcode(item.barcode)
        if hit.found and hit.image_url:
            return hit.image_url
        return None

    return category_placeholder_url(item.category)


async def refresh_item_image(
    item: InventoryItemResponse,
    *,
    update,
) -> InventoryItemResponse:
    """
    Persist a product image when the item has none.

    `update` is a callable(InventoryItemUpdateRequest) -> InventoryItemResponse.
    """
    if item.image_url:
        return item

    image_url = await resolve_missing_image_url(item)
    if not image_url:
        return item

    return update(InventoryItemUpdateRequest(image_url=image_url))


async def refresh_item_health(
    item: InventoryItemResponse,
    *,
    update,
) -> InventoryItemResponse:
    """
    REQ-021 AC4: backfill `health` for barcoded rows saved before grading existed.

    Items that already carry health data, or have no barcode, are returned unchanged.
    Unknown barcodes / OFF products without nutrition data leave the row untouched so
    a later open can retry.
    """
    if item.health is not None or not (item.barcode and item.barcode.strip()):
        return item

    hit = await lookup_barcode(item.barcode)
    if not hit.found or hit.health is None:
        return item

    return update(InventoryItemUpdateRequest(health=hit.health))
