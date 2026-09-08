"""Pydantic models for the thin onboarding API."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    """Liveness payload."""

    status: Literal["ok"] = "ok"
    service: str
    environment: str
    persistence: str | None = None
    firestore_database: str | None = None


class UserProfile(BaseModel):
    """Authenticated user profile."""

    uid: str
    email: str | None = None
    name: str | None = None


class HouseholdCreateRequest(BaseModel):
    """
    Satisfies: REQ-001, REQ-002
    Acceptance criteria: AC1, AC2, AC3
    Spec version: 1.0
    """

    name: str | None = Field(default=None, max_length=80)
    photo_url: str | None = None


class HouseholdResponse(BaseModel):
    """Household resource."""

    id: str
    name: str | None
    photo_url: str | None
    owner_uid: str
    address: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    store_ids: list[str] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime


class AddressUpdateRequest(BaseModel):
    """
    Satisfies: REQ-003
    Acceptance criteria: AC1, AC2, AC3
    Spec version: 1.0
    """

    address: str = Field(min_length=1, max_length=300)
    latitude: float | None = None
    longitude: float | None = None


class Store(BaseModel):
    """Nearby store candidate."""

    id: str
    name: str
    address: str
    latitude: float
    longitude: float
    distance_miles: float
    provider: Literal["places", "stub"] = "stub"


class StoreSearchResponse(BaseModel):
    """Nearby store search result."""

    household_id: str
    radius_miles: float
    stores: list[Store]


class StoreSelectionRequest(BaseModel):
    """
    Satisfies: REQ-003
    Acceptance criteria: AC5
    Spec version: 1.0
    """

    store_ids: list[str] = Field(min_length=1)


InventorySource = Literal["manual", "barcode", "receipt", "voice"]


class InventoryItemCreateRequest(BaseModel):
    """
    Satisfies: REQ-004, REQ-005, REQ-006, REQ-007
    Acceptance criteria: REQ-006 AC1–AC2; confirm-before-save for scan/voice
    Spec version: 1.0
    """

    name: str = Field(min_length=1, max_length=120)
    category: str = Field(default="Other", min_length=1, max_length=60)
    quantity: int = Field(default=1, ge=0, le=9999)
    low_stock_threshold: int = Field(default=1, ge=0, le=9999)
    price_paid: float | None = Field(default=None, ge=0)
    barcode: str | None = Field(default=None, max_length=64)
    source: InventorySource = "manual"


class InventoryItemUpdateRequest(BaseModel):
    """
    Satisfies: REQ-006, REQ-009
    Spec version: 1.0
    """

    name: str | None = Field(default=None, min_length=1, max_length=120)
    category: str | None = Field(default=None, min_length=1, max_length=60)
    quantity: int | None = Field(default=None, ge=0, le=9999)
    low_stock_threshold: int | None = Field(default=None, ge=0, le=9999)
    price_paid: float | None = Field(default=None, ge=0)
    barcode: str | None = Field(default=None, max_length=64)


class InventoryItemResponse(BaseModel):
    """Household inventory item resource."""

    id: str
    household_id: str
    name: str
    category: str
    quantity: int
    low_stock_threshold: int
    price_paid: float | None = None
    barcode: str | None = None
    source: InventorySource
    created_by_uid: str
    updated_by_uid: str
    created_at: datetime
    updated_at: datetime

    @property
    def is_low_stock(self) -> bool:
        return self.quantity <= self.low_stock_threshold


class InventoryListResponse(BaseModel):
    """List wrapper for household inventory."""

    household_id: str
    items: list[InventoryItemResponse]


class InventoryConsumeRequest(BaseModel):
    """
    Satisfies: REQ-008
    Acceptance criteria: AC2
    Spec version: 1.0
    """

    amount: int = Field(default=1, ge=1, le=999)


class InventoryConsumeByBarcodeRequest(BaseModel):
    """
    Satisfies: REQ-008
    Acceptance criteria: AC2, AC3
    Spec version: 1.0
    """

    barcode: str = Field(min_length=1, max_length=64)
    amount: int = Field(default=1, ge=1, le=999)
