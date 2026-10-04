"""
Shared product catalog routes (OpenAPI tag `products`, `/v1/catalog/products`).

Satisfies: REQ-RCP-007, REQ-RCP-011, REQ-RCP-019 AC3–AC5
Spec version: 1.0
"""

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.auth import AuthUser, verify_bearer_token
from app.catalog_repository import (
    CatalogConflict,
    CatalogProduct,
    CatalogRepository,
    NoChanges,
    ProductNotFound,
    UpcTaken,
    get_catalog_repository,
    household_hash,
)
from app.household_access import assert_household_member
from app.models import (
    ProductConflictResponse,
    ProductCorrectionRequest,
    ProductCorrectionResponse,
    CatalogProductResponse,
    CatalogSearchResponse,
)

# Namespaced under /v1/catalog: /v1/products/search is the existing Open Food
# Facts name search used by manual entry (REQ-006/007) and stays as it is.
products_router = APIRouter(prefix="/v1/catalog/products", tags=["products"])


def product_to_response(product: CatalogProduct) -> CatalogProductResponse:
    return CatalogProductResponse(
        id=product.id, code_kind=product.code_kind, upc=product.upc, plu_code=product.plu_code,
        store_chain_id=product.store_chain_id, name=product.name,
        brand=product.brand, category=product.category, unit_size=product.unit_size,
        image_url=product.image_url, image_source=product.image_source, source=product.source,
        confidence_score=product.confidence_score, confirmation_count=product.confirmation_count,
        status=product.status, superseded_by=product.superseded_by,
    )


def conflict_to_response(conflict: CatalogConflict) -> ProductConflictResponse:
    return ProductConflictResponse(**conflict.model_dump())


@products_router.get("/search", response_model=CatalogSearchResponse)
def search_catalog_products(
    q: str = Query(min_length=2, max_length=120),
    store_chain_id: str | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status", pattern="^(unverified|pending|verified)$"),
    limit: int = Query(default=8, ge=1, le=20),
    _: AuthUser = Depends(verify_bearer_token),
    repo: CatalogRepository = Depends(get_catalog_repository),
) -> CatalogSearchResponse:
    """
    Satisfies: REQ-RCP-007, REQ-006 AC4
    Spec version: 1.0
    """
    results = repo.search(q, store_chain_id=store_chain_id, status=status_filter, limit=limit)
    return CatalogSearchResponse(query=q, results=[product_to_response(p) for p in results])


@products_router.get("/{product_id}", response_model=CatalogProductResponse)
def get_catalog_product(
    product_id: str,
    _: AuthUser = Depends(verify_bearer_token),
    repo: CatalogRepository = Depends(get_catalog_repository),
) -> CatalogProductResponse:
    """
    Satisfies: REQ-RCP-011
    Spec version: 1.0

    Follows `superseded_by` so stale `llm:` ids keep resolving (REQ-RCP-010 AC2).
    """
    product = repo.get_product(product_id)
    if product is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    return product_to_response(product)


@products_router.post("/{product_id}/corrections", response_model=ProductCorrectionResponse)
def correct_catalog_product(
    product_id: str,
    payload: ProductCorrectionRequest,
    user: AuthUser = Depends(verify_bearer_token),
    repo: CatalogRepository = Depends(get_catalog_repository),
) -> ProductCorrectionResponse:
    """
    Satisfies: REQ-RCP-019 AC3–AC5, REQ-RCP-014
    Spec version: 1.0

    Applied directly on unverified/pending products; filed as
    `product_conflicts` on verified ones. Only `household_hash` reaches the
    catalog (NFR-002 AC1).
    """
    try:
        assert_household_member(payload.household_id, user.uid)
    except KeyError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Household not found") from exc
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden") from exc

    changes = payload.model_dump(exclude_unset=True, include={"name", "brand", "category", "unit_size", "upc"})
    source = payload.source_line_item
    try:
        result = repo.correct(
            product_id=product_id,
            hh=household_hash(payload.household_id),
            changes=changes,
            receipt_id=source.receipt_id if source else None,
            line_item_id=source.line_item_id if source else None,
        )
    except ProductNotFound as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found") from exc
    except NoChanges as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="no_changes") from exc
    except UpcTaken as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="upc_taken") from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return ProductCorrectionResponse(
        applied=result.applied,
        product=product_to_response(result.product),
        conflicts=[conflict_to_response(c) for c in result.conflicts],
        status_reset=result.status_reset,
    )
