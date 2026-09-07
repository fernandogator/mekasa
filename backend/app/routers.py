"""HTTP routers for health and onboarding."""

from fastapi import APIRouter, Depends, HTTPException, status

from app.auth import AuthUser, verify_bearer_token
from app.config import Settings, get_settings
from app.models import (
    AddressUpdateRequest,
    HealthResponse,
    HouseholdCreateRequest,
    HouseholdResponse,
    StoreSearchResponse,
    StoreSelectionRequest,
    UserProfile,
)
from app.repository import (
    HouseholdRepository,
    get_household_repository,
    stub_nearby_stores,
)

health_router = APIRouter(tags=["health"])
api_router = APIRouter(prefix="/v1", tags=["onboarding"])


@health_router.get("/health", response_model=HealthResponse)
def health(settings: Settings = Depends(get_settings)) -> HealthResponse:
    """Liveness check for Cloud Run."""
    return HealthResponse(
        status="ok",
        service=settings.app_name,
        environment=settings.environment,
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
