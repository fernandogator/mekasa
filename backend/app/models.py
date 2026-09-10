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


ShoppingListKind = Literal["auto", "custom", "request"]


class ShoppingListItemCreateRequest(BaseModel):
    """
    Satisfies: REQ-011, REQ-012
    Spec version: 1.0
    """

    name: str = Field(min_length=1, max_length=120)
    quantity: int = Field(default=1, ge=1, le=9999)
    quantity_label: str | None = Field(default=None, max_length=40)
    is_checked: bool = False
    needs_approval: bool = False
    requested_by: str | None = Field(default=None, max_length=80)
    inventory_item_id: str | None = Field(default=None, max_length=64)
    kind: ShoppingListKind = "custom"


class ShoppingListItemUpdateRequest(BaseModel):
    """
    Satisfies: REQ-011, REQ-013, REQ-014
    Spec version: 1.0
    """

    name: str | None = Field(default=None, min_length=1, max_length=120)
    quantity: int | None = Field(default=None, ge=1, le=9999)
    quantity_label: str | None = Field(default=None, max_length=40)
    is_checked: bool | None = None
    needs_approval: bool | None = None
    requested_by: str | None = Field(default=None, max_length=80)
    inventory_item_id: str | None = Field(default=None, max_length=64)
    kind: ShoppingListKind | None = None


class ShoppingListItemResponse(BaseModel):
    """Household shopping list row."""

    id: str
    household_id: str
    name: str
    quantity: int
    quantity_label: str | None = None
    is_checked: bool = False
    needs_approval: bool = False
    requested_by: str | None = None
    inventory_item_id: str | None = None
    kind: ShoppingListKind
    created_by_uid: str
    updated_by_uid: str
    created_at: datetime
    updated_at: datetime


class ShoppingListResponse(BaseModel):
    """List wrapper for shopping list items."""

    household_id: str
    items: list[ShoppingListItemResponse]


class ShoppingListSyncResponse(BaseModel):
    """Result of syncing low-stock inventory onto the shopping list."""

    household_id: str
    added: list[ShoppingListItemResponse]
    items: list[ShoppingListItemResponse]


class BarcodeLookupResponse(BaseModel):
    """
    Satisfies: REQ-004, ADR-006 (image step 1 + placeholder)
    Acceptance criteria: AC1, AC2
    Spec version: 1.0
    """

    barcode: str
    found: bool
    name: str | None = None
    brand: str | None = None
    category: str | None = None
    quantity: int = 1
    image_url: str | None = None
    source: Literal["openfoodfacts", "none"] = "none"


MemberRole = Literal["owner", "member"]


class ReceiptLineItem(BaseModel):
    """Parsed receipt line awaiting user confirmation (REQ-005)."""

    name: str = Field(min_length=1, max_length=120)
    category: str = Field(default="Other", min_length=1, max_length=60)
    quantity: int = Field(default=1, ge=1, le=9999)
    price_paid: float | None = Field(default=None, ge=0)


class ReceiptScanRequest(BaseModel):
    """
    Satisfies: REQ-005
    Acceptance criteria: AC1
    Spec version: 1.0

    Provide either image_base64 or raw_text (tests / fallbacks).
    """

    image_base64: str | None = None
    raw_text: str | None = None


class ReceiptScanResponse(BaseModel):
    """OCR result for client review."""

    household_id: str
    engine: str
    items: list[ReceiptLineItem]


class HouseholdPhotoResponse(BaseModel):
    """Photo upload result (REQ-002)."""

    household_id: str
    photo_url: str


class HouseholdInviteCreateRequest(BaseModel):
    """
    Satisfies: REQ-019
    Acceptance criteria: AC1, AC3
    Spec version: 1.0
    """

    name: str = Field(min_length=1, max_length=80)
    email: str | None = Field(default=None, max_length=120)
    phone: str | None = Field(default=None, max_length=40)
    role: MemberRole = "member"


class HouseholdInviteResponse(BaseModel):
    """Pending or accepted household invite."""

    id: str
    household_id: str
    name: str
    email: str | None = None
    phone: str | None = None
    role: MemberRole
    token: str
    status: Literal["pending", "accepted", "revoked"] = "pending"
    invited_by_uid: str
    created_at: datetime
    updated_at: datetime
    invite_link: str | None = None


class HouseholdInviteAcceptRequest(BaseModel):
    """Accept an invite token for the authenticated user."""

    token: str = Field(min_length=8, max_length=128)


class HouseholdMemberResponse(BaseModel):
    """Household member row (REQ-019)."""

    uid: str
    household_id: str
    name: str | None = None
    email: str | None = None
    phone: str | None = None
    role: MemberRole
    status: Literal["active", "invited", "removed"] = "active"
    created_at: datetime
    updated_at: datetime


class HouseholdMemberRoleUpdateRequest(BaseModel):
    """
    Satisfies: REQ-019 AC3
    Spec version: 1.0
    """

    role: MemberRole


class HouseholdMembersResponse(BaseModel):
    """Members list wrapper."""

    household_id: str
    members: list[HouseholdMemberResponse]


class HouseholdInvitesResponse(BaseModel):
    """Invites list wrapper."""

    household_id: str
    invites: list[HouseholdInviteResponse]


class UnknownBarcodeEvent(BaseModel):
    """Logged unknown trash-station scan (REQ-008 AC3)."""

    id: str
    household_id: str
    barcode: str
    scanned_by_uid: str
    created_at: datetime


class InventoryConsumeByBarcodeResult(BaseModel):
    """
    Consume-by-barcode result that can represent unknown scans without negatives.
    """

    found: bool
    item: InventoryItemResponse | None = None
    unknown_event: UnknownBarcodeEvent | None = None

