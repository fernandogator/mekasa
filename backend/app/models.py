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
    image_url: str | None = Field(default=None, max_length=2048)
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
    image_url: str | None = Field(default=None, max_length=2048)


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
    image_url: str | None = None
    source: InventorySource
    created_by_uid: str
    updated_by_uid: str
    created_at: datetime
    updated_at: datetime
    # REQ-INV-016 soft-delete (absent/false = visible)
    deleted: bool = False
    deleted_at: datetime | None = None

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


class ProductSearchHit(BaseModel):
    """One product variant from a name search (REQ-006 / REQ-007 AC2)."""

    barcode: str | None = None
    name: str
    brand: str | None = None
    category: str
    image_url: str | None = None
    source: Literal["openfoodfacts"] = "openfoodfacts"


class ProductSearchResponse(BaseModel):
    """
    Satisfies: REQ-006, REQ-007 AC2
    Spec version: 1.0

    Name search for manual / voice entry — pick a concrete product variant.
    """

    query: str
    results: list[ProductSearchHit]


MemberRole = Literal["owner", "member"]


class ReceiptLineItem(BaseModel):
    """Parsed receipt line awaiting user confirmation (REQ-005)."""

    name: str = Field(min_length=1, max_length=120)
    category: str = Field(default="Other", min_length=1, max_length=60)
    quantity: int = Field(default=1, ge=1, le=9999)
    price_paid: float | None = Field(default=None, ge=0)
    barcode: str | None = Field(default=None, max_length=64)
    image_url: str | None = Field(default=None, max_length=2048)
    identified: bool = False


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
    # REQ-014 AC3: future "buyer" (and similar) without a schema migration.
    permissions: list[str] = Field(default_factory=list)
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


class DeviceRegistrationRequest(BaseModel):
    """Register an FCM device token for the authenticated user (PRD §8)."""

    fcm_token: str = Field(min_length=8, max_length=4096)
    platform: Literal["ios", "android", "web"] = "ios"


class DeviceRegistrationResponse(BaseModel):
    """Stored device registration."""

    id: str
    uid: str
    fcm_token: str
    platform: Literal["ios", "android", "web"]
    created_at: datetime
    updated_at: datetime


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


PurchaseSource = Literal["receipt", "manual", "estimated", "inventory"]
SpendingPeriod = Literal["week", "month", "year"]


class PurchaseEventCreateRequest(BaseModel):
    """
    Satisfies: REQ-015 AC1–AC3, REQ-017 AC1
    Spec version: 1.0
    """

    name: str = Field(min_length=1, max_length=120)
    category: str = Field(min_length=1, max_length=60)
    price_paid: float = Field(ge=0)
    quantity: int = Field(default=1, ge=1)
    store_id: str | None = Field(default=None, max_length=120)
    inventory_item_id: str | None = Field(default=None, max_length=80)
    source: PurchaseSource = "manual"
    purchased_at: datetime | None = None


class PurchaseEventUpdateRequest(BaseModel):
    """
    Satisfies: REQ-017 AC3
    Spec version: 1.0
    """

    category: str | None = Field(default=None, min_length=1, max_length=60)
    name: str | None = Field(default=None, min_length=1, max_length=120)
    price_paid: float | None = Field(default=None, ge=0)


class PurchaseEventResponse(BaseModel):
    """One purchase / price-paid event (REQ-015)."""

    id: str
    household_id: str
    name: str
    category: str
    price_paid: float
    quantity: int
    store_id: str | None = None
    inventory_item_id: str | None = None
    source: PurchaseSource
    purchased_at: datetime
    created_by_uid: str
    created_at: datetime
    updated_at: datetime


class SpendingCategoryTotal(BaseModel):
    """Category rollup for spending reports."""

    category: str
    total: float


class SpendingReportResponse(BaseModel):
    """
    Satisfies: REQ-017 AC2, REQ-018 AC1–AC2
    Spec version: 1.0
    """

    household_id: str
    period: SpendingPeriod
    currency: str = "USD"
    total: float
    by_category: list[SpendingCategoryTotal]
    events: list[PurchaseEventResponse]

