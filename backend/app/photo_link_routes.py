"""
Signed photo links for clients that cannot send the bearer token with an image
request (OpenAPI tag `photo-links`).

Satisfies: REQ-023 (Signed Photo Links With a Server-Side Cache)
Acceptance criteria: AC1, AC2, AC5, AC6
Spec version: 1.0
"""

from __future__ import annotations

import logging
import re
from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from app.auth import AuthUser, verify_bearer_token
from app.household_access import assert_household_member
from app.item_photos import ItemPhotoService, get_item_photo_service
from app.observability import log_event
from app.photo_links import LinkLookup
from app.product_photos import ProductPhotoService, get_product_photo_service

logger = logging.getLogger("app.photo_links")

photo_links_router = APIRouter(prefix="/v1", tags=["photo-links"])

MAX_PATHS = 100
_UUID = r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
_ITEM_PATH = re.compile(rf"^/v1/households/(?P<hid>[^/?#]+)/item-photos/(?P<pid>{_UUID})$")
_PRODUCT_PATH = re.compile(rf"^/v1/product-photos/(?P<pid>{_UUID})$")


class PhotoLinksRequest(BaseModel):
    photos: list[str] = Field(default_factory=list)


class PhotoLinkOut(BaseModel):
    url: str
    expires_at: datetime | None = None


class PhotoLinksResponse(BaseModel):
    links: dict[str, PhotoLinkOut | None]


def _bad_request(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=detail)


@photo_links_router.post(
    "/households/{household_id}/photo-links",
    response_model=PhotoLinksResponse,
)
def create_photo_links(
    household_id: str,
    payload: PhotoLinksRequest,
    user: AuthUser = Depends(verify_bearer_token),
    item_photos: ItemPhotoService = Depends(get_item_photo_service),
    product_photos: ProductPhotoService = Depends(get_product_photo_service),
) -> PhotoLinksResponse:
    """
    Satisfies: REQ-023 (Signed Photo Links With a Server-Side Cache)
    Acceptance criteria: AC1, AC2, AC5, AC6
    Spec version: 1.0

    Membership is checked before any link is looked up, on every call, so a
    cached link is never handed to a caller who could not fetch the photo.
    Item photos of another household and missing photos map to null.
    """
    if len(payload.photos) > MAX_PATHS:
        raise _bad_request("too_many_photos")
    parsed: list[tuple[str, str, str | None]] = []
    for path in payload.photos:
        item = _ITEM_PATH.match(path)
        product = _PRODUCT_PATH.match(path)
        if item:
            parsed.append((path, item.group("pid"), item.group("hid")))
        elif product:
            parsed.append((path, product.group("pid"), None))
        else:
            raise _bad_request("invalid_photo_path")
    try:
        assert_household_member(household_id, user.uid)
    except KeyError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Household not found") from exc
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden") from exc

    links: dict[str, PhotoLinkOut | None] = {}
    cached = signed = missing = 0
    for path, photo_id, path_household in parsed:
        if path in links:
            continue
        lookup: LinkLookup
        if path_household is None:
            lookup = product_photos.link(photo_id)
        elif path_household == household_id:
            lookup = item_photos.link(household_id, str(UUID(photo_id)))
        else:
            lookup = LinkLookup(None, cached=False)
        if lookup.link is None:
            missing += 1
            links[path] = None
            continue
        if lookup.cached:
            cached += 1
        elif lookup.link.expires_at is not None:
            signed += 1
        links[path] = PhotoLinkOut(url=lookup.link.url, expires_at=lookup.link.expires_at)
    log_event(
        logger,
        "photo_links",
        requested=len(payload.photos),
        cached=cached,
        signed=signed,
        missing=missing,
    )
    return PhotoLinksResponse(links=links)
