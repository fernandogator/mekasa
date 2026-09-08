"""HTTP routers for health, onboarding, and inventory."""

from fastapi import APIRouter, Depends, HTTPException, status

from app.auth import AuthUser, verify_bearer_token
from app.barcode_lookup import lookup_barcode
from app.config import Settings, get_settings
from app.inventory_repository import InventoryRepository, get_inventory_repository
from app.models import (
    AddressUpdateRequest,
    BarcodeLookupResponse,
    HealthResponse,
    HouseholdCreateRequest,
    HouseholdResponse,
    InventoryConsumeByBarcodeRequest,
    InventoryConsumeRequest,
    InventoryItemCreateRequest,
    InventoryItemResponse,
    InventoryItemUpdateRequest,
    InventoryListResponse,
    ShoppingListItemCreateRequest,
    ShoppingListItemResponse,
    ShoppingListItemUpdateRequest,
    ShoppingListResponse,
    ShoppingListSyncResponse,
    StoreSearchResponse,
    StoreSelectionRequest,
    UserProfile,
)
from app.repository import (
    HouseholdRepository,
    get_household_repository,
    stub_nearby_stores,
)
from app.shopping_list_repository import (
    ShoppingListRepository,
    get_shopping_list_repository,
)

health_router = APIRouter(tags=["health"])
api_router = APIRouter(prefix="/v1", tags=["onboarding"])
inventory_router = APIRouter(prefix="/v1", tags=["inventory"])
shopping_list_router = APIRouter(prefix="/v1", tags=["shopping-list"])
barcode_router = APIRouter(prefix="/v1", tags=["barcode"])


@health_router.get("/health", response_model=HealthResponse)
def health(settings: Settings = Depends(get_settings)) -> HealthResponse:
    """Liveness check for Cloud Run."""
    from app.repository import resolve_persistence_mode

    mode = resolve_persistence_mode(settings)
    return HealthResponse(
        status="ok",
        service=settings.app_name,
        environment=settings.environment,
        persistence=mode,
        firestore_database=settings.firestore_database_id if mode == "firestore" else None,
    )


@api_router.get("/me", response_model=UserProfile)
def me(user: AuthUser = Depends(verify_bearer_token)) -> UserProfile:
    """
    Satisfies: REQ-001
    Acceptance criteria: AC1, AC2, AC3
    Spec version: 1.0
    """
    return UserProfile(uid=user.uid, email=user.email, name=user.name)


@api_router.post(
    "/households",
    response_model=HouseholdResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_household(
    payload: HouseholdCreateRequest,
    user: AuthUser = Depends(verify_bearer_token),
    repo: HouseholdRepository = Depends(get_household_repository),
) -> HouseholdResponse:
    """
    Satisfies: REQ-001, REQ-002
    Acceptance criteria: AC1, AC2, AC3
    Spec version: 1.0
    """
    return repo.create(user.uid, payload)


@api_router.get("/households/current", response_model=HouseholdResponse)
def get_current_household(
    user: AuthUser = Depends(verify_bearer_token),
    repo: HouseholdRepository = Depends(get_household_repository),
) -> HouseholdResponse:
    """
    Satisfies: REQ-001
    Acceptance criteria: AC1
    Spec version: 1.0
    """
    household = repo.get_for_owner(user.uid)
    if household is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No household")
    return household


@api_router.put("/households/{household_id}/address", response_model=HouseholdResponse)
def update_address(
    household_id: str,
    payload: AddressUpdateRequest,
    user: AuthUser = Depends(verify_bearer_token),
    repo: HouseholdRepository = Depends(get_household_repository),
) -> HouseholdResponse:
    """
    Satisfies: REQ-003
    Acceptance criteria: AC1, AC2, AC3
    Spec version: 1.0
    """
    try:
        return repo.update_address(household_id, user.uid, payload)
    except KeyError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found") from exc
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden") from exc


@api_router.get(
    "/households/{household_id}/stores/nearby",
    response_model=StoreSearchResponse,
)
def list_nearby_stores(
    household_id: str,
    user: AuthUser = Depends(verify_bearer_token),
    repo: HouseholdRepository = Depends(get_household_repository),
    settings: Settings = Depends(get_settings),
) -> StoreSearchResponse:
    """
    Satisfies: REQ-003
    Acceptance criteria: AC4
    Spec version: 1.0
    """
    household = repo.get(household_id)
    if household is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    if household.owner_uid != user.uid:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
    stores = stub_nearby_stores(
        latitude=household.latitude,
        longitude=household.longitude,
        radius_miles=settings.store_search_radius_miles,
    )
    return StoreSearchResponse(
        household_id=household_id,
        radius_miles=settings.store_search_radius_miles,
        stores=stores,
    )


@api_router.put("/households/{household_id}/stores", response_model=HouseholdResponse)
def select_stores(
    household_id: str,
    payload: StoreSelectionRequest,
    user: AuthUser = Depends(verify_bearer_token),
    repo: HouseholdRepository = Depends(get_household_repository),
) -> HouseholdResponse:
    """
    Satisfies: REQ-003
    Acceptance criteria: AC5
    Spec version: 1.0
    """
    try:
        return repo.set_stores(household_id, user.uid, payload.store_ids)
    except KeyError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found") from exc
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden") from exc


def _map_inventory_errors(exc: Exception) -> HTTPException:
    if isinstance(exc, KeyError):
        return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    if isinstance(exc, PermissionError):
        return HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
    raise exc


@inventory_router.get(
    "/households/{household_id}/inventory",
    response_model=InventoryListResponse,
)
def list_inventory(
    household_id: str,
    user: AuthUser = Depends(verify_bearer_token),
    repo: InventoryRepository = Depends(get_inventory_repository),
) -> InventoryListResponse:
    """
    Satisfies: REQ-006
    Spec version: 1.0
    """
    try:
        items = repo.list_items(household_id, user.uid)
    except (KeyError, PermissionError) as exc:
        raise _map_inventory_errors(exc) from exc
    return InventoryListResponse(household_id=household_id, items=items)


@inventory_router.post(
    "/households/{household_id}/inventory",
    response_model=InventoryItemResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_inventory_item(
    household_id: str,
    payload: InventoryItemCreateRequest,
    user: AuthUser = Depends(verify_bearer_token),
    repo: InventoryRepository = Depends(get_inventory_repository),
) -> InventoryItemResponse:
    """
    Satisfies: REQ-004, REQ-005, REQ-006, REQ-007
    Spec version: 1.0
    """
    try:
        return repo.create(household_id, user.uid, payload)
    except (KeyError, PermissionError) as exc:
        raise _map_inventory_errors(exc) from exc


@inventory_router.get(
    "/households/{household_id}/inventory/{item_id}",
    response_model=InventoryItemResponse,
)
def get_inventory_item(
    household_id: str,
    item_id: str,
    user: AuthUser = Depends(verify_bearer_token),
    repo: InventoryRepository = Depends(get_inventory_repository),
) -> InventoryItemResponse:
    """
    Satisfies: REQ-006
    Spec version: 1.0
    """
    try:
        item = repo.get(household_id, item_id, user.uid)
    except (KeyError, PermissionError) as exc:
        raise _map_inventory_errors(exc) from exc
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    return item


@inventory_router.patch(
    "/households/{household_id}/inventory/{item_id}",
    response_model=InventoryItemResponse,
)
def update_inventory_item(
    household_id: str,
    item_id: str,
    payload: InventoryItemUpdateRequest,
    user: AuthUser = Depends(verify_bearer_token),
    repo: InventoryRepository = Depends(get_inventory_repository),
) -> InventoryItemResponse:
    """
    Satisfies: REQ-006, REQ-009
    Spec version: 1.0
    """
    try:
        return repo.update(household_id, item_id, user.uid, payload)
    except (KeyError, PermissionError) as exc:
        raise _map_inventory_errors(exc) from exc


@inventory_router.delete(
    "/households/{household_id}/inventory/{item_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_inventory_item(
    household_id: str,
    item_id: str,
    user: AuthUser = Depends(verify_bearer_token),
    repo: InventoryRepository = Depends(get_inventory_repository),
) -> None:
    """
    Satisfies: REQ-006
    Spec version: 1.0
    """
    try:
        repo.delete(household_id, item_id, user.uid)
    except (KeyError, PermissionError) as exc:
        raise _map_inventory_errors(exc) from exc


@inventory_router.post(
    "/households/{household_id}/inventory/{item_id}/consume",
    response_model=InventoryItemResponse,
)
def consume_inventory_item(
    household_id: str,
    item_id: str,
    payload: InventoryConsumeRequest,
    user: AuthUser = Depends(verify_bearer_token),
    repo: InventoryRepository = Depends(get_inventory_repository),
) -> InventoryItemResponse:
    """
    Satisfies: REQ-008
    Acceptance criteria: AC2
    Spec version: 1.0
    """
    try:
        return repo.consume(household_id, item_id, user.uid, payload)
    except (KeyError, PermissionError) as exc:
        raise _map_inventory_errors(exc) from exc


@inventory_router.post(
    "/households/{household_id}/inventory/consume-by-barcode",
    response_model=InventoryItemResponse,
)
def consume_inventory_by_barcode(
    household_id: str,
    payload: InventoryConsumeByBarcodeRequest,
    user: AuthUser = Depends(verify_bearer_token),
    repo: InventoryRepository = Depends(get_inventory_repository),
) -> InventoryItemResponse:
    """
    Satisfies: REQ-008
    Acceptance criteria: AC2, AC3
    Spec version: 1.0

    Unknown barcodes return 404 (no negative quantity).
    """
    try:
        return repo.consume_by_barcode(household_id, user.uid, payload)
    except (KeyError, PermissionError) as exc:
        raise _map_inventory_errors(exc) from exc


@shopping_list_router.get(
    "/households/{household_id}/shopping-list",
    response_model=ShoppingListResponse,
)
def list_shopping_list(
    household_id: str,
    user: AuthUser = Depends(verify_bearer_token),
    repo: ShoppingListRepository = Depends(get_shopping_list_repository),
) -> ShoppingListResponse:
    """
    Satisfies: REQ-011–REQ-014
    Spec version: 1.0
    """
    try:
        items = repo.list_items(household_id, user.uid)
    except (KeyError, PermissionError) as exc:
        raise _map_inventory_errors(exc) from exc
    return ShoppingListResponse(household_id=household_id, items=items)


@shopping_list_router.post(
    "/households/{household_id}/shopping-list",
    response_model=ShoppingListItemResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_shopping_list_item(
    household_id: str,
    payload: ShoppingListItemCreateRequest,
    user: AuthUser = Depends(verify_bearer_token),
    repo: ShoppingListRepository = Depends(get_shopping_list_repository),
) -> ShoppingListItemResponse:
    """
    Satisfies: REQ-011, REQ-012
    Spec version: 1.0
    """
    try:
        return repo.create(household_id, user.uid, payload)
    except (KeyError, PermissionError) as exc:
        raise _map_inventory_errors(exc) from exc


@shopping_list_router.get(
    "/households/{household_id}/shopping-list/{item_id}",
    response_model=ShoppingListItemResponse,
)
def get_shopping_list_item(
    household_id: str,
    item_id: str,
    user: AuthUser = Depends(verify_bearer_token),
    repo: ShoppingListRepository = Depends(get_shopping_list_repository),
) -> ShoppingListItemResponse:
    try:
        item = repo.get(household_id, item_id, user.uid)
    except (KeyError, PermissionError) as exc:
        raise _map_inventory_errors(exc) from exc
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    return item


@shopping_list_router.patch(
    "/households/{household_id}/shopping-list/{item_id}",
    response_model=ShoppingListItemResponse,
)
def update_shopping_list_item(
    household_id: str,
    item_id: str,
    payload: ShoppingListItemUpdateRequest,
    user: AuthUser = Depends(verify_bearer_token),
    repo: ShoppingListRepository = Depends(get_shopping_list_repository),
) -> ShoppingListItemResponse:
    """
    Satisfies: REQ-011, REQ-014
    Spec version: 1.0
    """
    try:
        return repo.update(household_id, item_id, user.uid, payload)
    except (KeyError, PermissionError) as exc:
        raise _map_inventory_errors(exc) from exc


@shopping_list_router.delete(
    "/households/{household_id}/shopping-list/{item_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_shopping_list_item(
    household_id: str,
    item_id: str,
    user: AuthUser = Depends(verify_bearer_token),
    repo: ShoppingListRepository = Depends(get_shopping_list_repository),
) -> None:
    try:
        repo.delete(household_id, item_id, user.uid)
    except (KeyError, PermissionError) as exc:
        raise _map_inventory_errors(exc) from exc


@shopping_list_router.post(
    "/households/{household_id}/shopping-list/{item_id}/approve",
    response_model=ShoppingListItemResponse,
)
def approve_shopping_list_item(
    household_id: str,
    item_id: str,
    user: AuthUser = Depends(verify_bearer_token),
    repo: ShoppingListRepository = Depends(get_shopping_list_repository),
) -> ShoppingListItemResponse:
    """
    Satisfies: REQ-013 AC1
    Spec version: 1.0
    """
    try:
        return repo.approve(household_id, item_id, user.uid)
    except (KeyError, PermissionError) as exc:
        raise _map_inventory_errors(exc) from exc


@shopping_list_router.post(
    "/households/{household_id}/shopping-list/{item_id}/reject",
    status_code=status.HTTP_204_NO_CONTENT,
)
def reject_shopping_list_item(
    household_id: str,
    item_id: str,
    user: AuthUser = Depends(verify_bearer_token),
    repo: ShoppingListRepository = Depends(get_shopping_list_repository),
) -> None:
    """
    Satisfies: REQ-013 AC2
    Spec version: 1.0
    """
    try:
        repo.reject(household_id, item_id, user.uid)
    except (KeyError, PermissionError) as exc:
        raise _map_inventory_errors(exc) from exc


@shopping_list_router.post(
    "/households/{household_id}/shopping-list/sync-from-inventory",
    response_model=ShoppingListSyncResponse,
)
def sync_shopping_list_from_inventory(
    household_id: str,
    user: AuthUser = Depends(verify_bearer_token),
    repo: ShoppingListRepository = Depends(get_shopping_list_repository),
    inventory: InventoryRepository = Depends(get_inventory_repository),
) -> ShoppingListSyncResponse:
    """
    Satisfies: REQ-011
    Spec version: 1.0

    Auto-adds low-stock inventory rows onto the shopping list.
    """
    try:
        added, items = repo.sync_from_inventory(household_id, user.uid, inventory)
    except (KeyError, PermissionError) as exc:
        raise _map_inventory_errors(exc) from exc
    return ShoppingListSyncResponse(household_id=household_id, added=added, items=items)


@barcode_router.get("/barcode/{code}", response_model=BarcodeLookupResponse)
async def lookup_barcode_endpoint(
    code: str,
    user: AuthUser = Depends(verify_bearer_token),
) -> BarcodeLookupResponse:
    """
    Satisfies: REQ-004
    Acceptance criteria: AC1, AC2
    Spec version: 1.0

    Looks up a UPC/EAN via Open Food Facts. Unknown codes return found=false
    so the client can fall back to manual entry.
    """
    _ = user
    return await lookup_barcode(code)
