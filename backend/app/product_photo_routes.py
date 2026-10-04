"""
Shared product photo routes (OpenAPI tag `product-photos`).

Satisfies: REQ-RCP-021 (Product Photo Upload and Storage)
Acceptance criteria: AC1, AC3, AC5, AC6
Spec version: 1.0
"""

from __future__ import annotations

import base64
import binascii

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from fastapi.responses import RedirectResponse
from pydantic import ValidationError
from starlette.datastructures import UploadFile

from app.auth import AuthUser, verify_bearer_token
from app.catalog_repository import CatalogRepository, get_catalog_repository
from app.household_access import assert_household_member
from app.models import ProductPhotoResponse, ProductPhotoUploadJson
from app.product_photos import (
    ImageTooLarge,
    PhotoRedirect,
    ProductPhotoRecord,
    ProductPhotoService,
    UnsupportedImage,
    get_product_photo_service,
)

product_photos_router = APIRouter(prefix="/v1", tags=["product-photos"])

_RESOLVE_CACHE = "private, max-age=600"


def _require_member(household_id: str, uid: str) -> None:
    try:
        assert_household_member(household_id, uid)
    except KeyError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Household not found") from exc
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden") from exc


def _unsupported() -> HTTPException:
    return HTTPException(status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, detail="unsupported_media_type")


async def _read_upload(request: Request) -> bytes:
    content_type = request.headers.get("content-type", "")
    if content_type.startswith("multipart/form-data"):
        form = await request.form()
        upload = form.get("file")
        if not isinstance(upload, UploadFile):
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="file_required")
        if not (upload.content_type or "").startswith("image/"):
            raise _unsupported()
        return await upload.read()
    if content_type.startswith("application/json"):
        try:
            payload = ProductPhotoUploadJson.model_validate_json(await request.body())
        except ValidationError as exc:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="image_base64_required") from exc
        try:
            return base64.b64decode(payload.image_base64, validate=True)
        except (binascii.Error, ValueError) as exc:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid_base64") from exc
    raise _unsupported()


def _to_response(record: ProductPhotoRecord) -> ProductPhotoResponse:
    return ProductPhotoResponse(
        photo_id=record.photo_id,
        image_url=record.image_url,
        width=record.width,
        height=record.height,
        bytes=record.bytes,
        created_at=record.created_at,
        expires_at=record.expires_at,
    )


@product_photos_router.post(
    "/households/{household_id}/product-photos",
    response_model=ProductPhotoResponse,
    status_code=status.HTTP_201_CREATED,
)
async def upload_product_photo(
    household_id: str,
    request: Request,
    user: AuthUser = Depends(verify_bearer_token),
    photos: ProductPhotoService = Depends(get_product_photo_service),
) -> ProductPhotoResponse:
    """
    Satisfies: REQ-RCP-021 AC1, AC2, AC6; REQ-RCP-020 AC5
    Spec version: 1.0

    Accepts multipart `file` or JSON `image_base64`. The photo is re-encoded as
    JPEG without EXIF/GPS, capped at 1600 px, and becomes shareable with a
    product only when a capture references it.
    """
    _require_member(household_id, user.uid)
    data = await _read_upload(request)
    try:
        record = photos.upload(household_id, user.uid, data)
    except ImageTooLarge as exc:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="payload_too_large") from exc
    except UnsupportedImage as exc:
        raise _unsupported() from exc
    return _to_response(record)


@product_photos_router.delete(
    "/households/{household_id}/product-photos/{photo_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_product_photo(
    household_id: str,
    photo_id: str,
    user: AuthUser = Depends(verify_bearer_token),
    photos: ProductPhotoService = Depends(get_product_photo_service),
    catalog: CatalogRepository = Depends(get_catalog_repository),
) -> Response:
    """
    Satisfies: REQ-RCP-021 AC5
    Spec version: 1.0

    Only the uploading household can delete. Shared products using the photo
    lose it and fall back to the category placeholder.
    """
    _require_member(household_id, user.uid)
    if not photos.delete(household_id, photo_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    catalog.release_user_photo(photo_id.lower())
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@product_photos_router.get("/product-photos/{photo_id}")
def get_product_photo(
    photo_id: str,
    user: AuthUser = Depends(verify_bearer_token),
    photos: ProductPhotoService = Depends(get_product_photo_service),
) -> Response:
    """
    Satisfies: REQ-RCP-021 AC3
    Spec version: 1.0

    Any signed-in user. With Cloud Storage this redirects to a signed URL
    valid for 15 minutes; locally the bytes are served directly. Neither
    reveals the bucket path or the uploading household.
    """
    _ = user
    resolved = photos.resolve(photo_id)
    if resolved is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    if isinstance(resolved, PhotoRedirect):
        return RedirectResponse(resolved.url, status_code=status.HTTP_302_FOUND, headers={"Cache-Control": _RESOLVE_CACHE})
    return Response(content=resolved.jpeg, media_type="image/jpeg", headers={"Cache-Control": _RESOLVE_CACHE})
