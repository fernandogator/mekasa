"""
Product capture from inventory (OpenAPI `captureInventoryItemProduct`).

Satisfies: REQ-RCP-020 AC2, AC4, AC5, AC6, AC7
Spec version: 1.0

The receipt line-item variant (`…/line-items/{lid}/capture`) needs persisted
receipts and is not served yet.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status

from app.auth import AuthUser, verify_bearer_token
from app.catalog_repository import (
    SHARED_CHAIN_ID,
    CatalogRepository,
    get_catalog_repository,
    household_hash,
    photo_image_url,
)
from app.catalog_routes import conflict_to_response, product_to_response
from app.category_icons import is_placeholder_url
from app.inventory_repository import InventoryRepository, get_inventory_repository
from app.item_photos import ItemPhotoService, get_item_photo_service
from app.models import InventoryItemResponse, ProductCaptureRequest, ProductCaptureResponse
from app.product_photos import ProductPhotoService, get_product_photo_service
from app.scan_events_repository import ScanEventsRepository, get_scan_events_repository, new_scan_event

capture_router = APIRouter(prefix="/v1", tags=["inventory"])


def _bad_request(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=detail)


def _item_image(item: InventoryItemResponse, photo_id: str | None, product_image_url: str | None) -> str | None:
    """The household's own capture photo wins; otherwise only a placeholder gives way to the product image."""
    if photo_id:
        return photo_image_url(photo_id)
    if product_image_url and (item.image_url is None or is_placeholder_url(item.image_url)):
        return product_image_url
    return item.image_url


@capture_router.post(
    "/households/{household_id}/inventory/{item_id}/capture",
    response_model=ProductCaptureResponse,
)
def capture_inventory_item_product(
    household_id: str,
    item_id: str,
    payload: ProductCaptureRequest,
    user: AuthUser = Depends(verify_bearer_token),
    inventory: InventoryRepository = Depends(get_inventory_repository),
    catalog: CatalogRepository = Depends(get_catalog_repository),
    product_photos: ProductPhotoService = Depends(get_product_photo_service),
    item_photos: ItemPhotoService = Depends(get_item_photo_service),
    scan_events: ScanEventsRepository = Depends(get_scan_events_repository),
) -> ProductCaptureResponse:
    """
    Satisfies: REQ-RCP-020 AC2, AC4, AC5, AC6, AC7
    Spec version: 1.0

    Links the item to the shared product for the scanned UPC or typed PLU,
    creating it when the catalog does not know the code, and sets the item's
    `barcode` (UPCs only), `product_id` and `image_url`. A capture photo must
    come from this household's `POST …/product-photos`; it is shared with the
    product under the REQ-RCP-020 AC5 rules.
    """
    if (payload.upc is None) == (payload.plu_code is None):
        raise _bad_request("exactly_one_code_required")
    try:
        item = inventory.get(household_id, item_id, user.uid)
    except KeyError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found") from exc
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden") from exc
    if item is None or item.deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")

    photo_id: str | None = None
    if payload.photo_id:
        record = product_photos.owned_by(household_id, payload.photo_id)
        if record is None:
            raise _bad_request("unknown_photo_id")
        photo_id = record.photo_id

    try:
        result = catalog.capture(
            store_chain_id=SHARED_CHAIN_ID,
            upc=payload.upc,
            plu_code=payload.plu_code,
            hh=household_hash(household_id),
            fallback_name=item.name,
            fallback_category=item.category,
            name=payload.name,
            brand=payload.brand,
            category=payload.category,
            unit_size=payload.unit_size,
            photo_id=photo_id,
        )
    except ValueError as exc:
        raise _bad_request(str(exc)) from exc
    if photo_id:
        product_photos.mark_referenced(household_id, photo_id)

    new_image = _item_image(item, photo_id, result.product.image_url)
    updated = inventory.apply_capture(
        household_id,
        item_id,
        user.uid,
        barcode=result.product.upc or item.barcode,
        product_id=result.product.id,
        image_url=new_image,
    )
    if item.image_url and item.image_url != new_image:
        item_photos.delete_if_owned(household_id, item.image_url)

    event = scan_events.record(
        new_scan_event(
            household_id,
            user.uid,
            context="inventory_capture",
            outcome="found" if result.outcome == "linked" else "created",
            upc=result.product.upc,
            plu_code=result.product.plu_code,
            product_id=result.product.id,
            inventory_item_id=item_id,
        )
    )
    return ProductCaptureResponse(
        outcome=result.outcome,
        product=product_to_response(result.product),
        inventory_item_id=item_id,
        inventory_item=updated,
        scan_event_id=event.id,
        confirmation_counted=result.confirmation_counted,
        enrichment_job_id=result.enrichment_job_id,
        photo_applied_as=result.photo_applied_as,
        conflict=conflict_to_response(result.conflict) if result.conflict else None,
    )
