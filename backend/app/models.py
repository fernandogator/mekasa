"""Pydantic models for the thin onboarding API."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, model_validator

from app.categories import Category, OptionalCategory


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


class HouseholdNameUpdateRequest(BaseModel):
    """
    Satisfies: REQ-002
    Acceptance criteria: AC1
    Spec version: 1.0

    Optional household display name (e.g. "The Guerrero Home").
    Empty / null clears the name.
    """

    name: str | None = Field(default=None, max_length=80)


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

HealthGrade = Literal["A", "B", "C", "D", "E"]
AdditiveConcern = Literal["none", "low", "moderate", "high", "unknown"]


class AdditiveInfo(BaseModel):
    """One food additive found on a product (REQ-021)."""

    code: str = Field(max_length=8)
    name: str = Field(max_length=80)
    concern: AdditiveConcern = "unknown"


class ProductHealth(BaseModel):
    """
    Satisfies: REQ-021 (health grade + allergen data)
    Spec version: 1.0

    Derived from Open Food Facts; see app.product_health for the grade formula.
    """

    grade: HealthGrade | None = None
    score: int | None = Field(default=None, ge=0, le=100)
    nutriscore: Literal["A", "B", "C", "D", "E"] | None = None
    nova_group: int | None = Field(default=None, ge=1, le=4)
    additives: list[AdditiveInfo] = Field(default_factory=list)
    allergens: list[str] = Field(default_factory=list)
    traces: list[str] = Field(default_factory=list)
    ingredients_text: str | None = Field(default=None, max_length=2000)
    # e.g. "Palm oil" from OFF ingredient analysis
    flags: list[str] = Field(default_factory=list)


class MemberWarning(BaseModel):
    """A household member who avoids something this product contains (REQ-021 AC2)."""

    member_uid: str
    member_name: str
    matched: list[str]


class AvoidanceOption(BaseModel):
    """Catalog entry a member can pick from ("I'm allergic to…")."""

    key: str
    label: str
    terms: list[str] = Field(default_factory=list)


class AvoidancesResponse(BaseModel):
    options: list[AvoidanceOption]


class MemberAvoidUpdateRequest(BaseModel):
    """
    Satisfies: REQ-021 AC1
    Spec version: 1.0

    Replace the member's avoid list. Entries are catalog keys/labels or free text.
    """

    avoid: list[str] = Field(default_factory=list, max_length=40)


class InventoryItemCreateRequest(BaseModel):
    """
    Satisfies: REQ-004, REQ-005, REQ-006, REQ-007
    Acceptance criteria: REQ-006 AC1–AC2; confirm-before-save for scan/voice
    Spec version: 1.0
    """

    name: str = Field(min_length=1, max_length=120)
    category: Category = Field(default="Other", min_length=1, max_length=60)
    quantity: int = Field(default=1, ge=0, le=9999)
    low_stock_threshold: int = Field(default=1, ge=0, le=9999)
    price_paid: float | None = Field(default=None, ge=0)
    barcode: str | None = Field(default=None, max_length=64)
    image_url: str | None = Field(default=None, max_length=2048)
    source: InventorySource = "manual"
    health: ProductHealth | None = None


class InventoryItemUpdateRequest(BaseModel):
    """
    Satisfies: REQ-006, REQ-009
    Spec version: 1.0
    """

    name: str | None = Field(default=None, min_length=1, max_length=120)
    category: OptionalCategory = Field(default=None, min_length=1, max_length=60)
    quantity: int | None = Field(default=None, ge=0, le=9999)
    low_stock_threshold: int | None = Field(default=None, ge=0, le=9999)
    price_paid: float | None = Field(default=None, ge=0)
    barcode: str | None = Field(default=None, max_length=64)
    image_url: str | None = Field(default=None, max_length=2048)
    health: ProductHealth | None = None


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
    # When image_url last changed (REQ-INV-021 AC2); older rows have none and fall back to updated_at.
    image_updated_at: datetime | None = None
    # Shared catalog product linked by a product capture (REQ-RCP-020 AC6): UPC or plu:<code>.
    product_id: str | None = None
    source: InventorySource
    created_by_uid: str
    updated_by_uid: str
    created_at: datetime
    updated_at: datetime
    # REQ-INV-016 soft-delete (absent/false = visible)
    deleted: bool = False
    deleted_at: datetime | None = None
    # REQ-021: health grade data (barcode items) + members who avoid an ingredient
    health: ProductHealth | None = None
    warnings: list[MemberWarning] = Field(default_factory=list)

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


DuplicateReason = Literal["same_barcode", "same_product", "same_name"]


class InventoryDuplicateGroup(BaseModel):
    """
    Satisfies: REQ-INV-021 AC1, AC2
    Spec version: 1.0

    Items that look like the same product; `keep_id` survives a merge.
    """

    reason: DuplicateReason
    keep_id: str
    items: list[InventoryItemResponse]


class InventoryDuplicatesResponse(BaseModel):
    household_id: str
    groups: list[InventoryDuplicateGroup]


class InventoryMergeRequest(BaseModel):
    """REQ-INV-021 AC3: ids of one duplicate group."""

    model_config = {"extra": "forbid"}

    item_ids: list[str] = Field(min_length=2, max_length=20)


class InventoryMergeResponse(BaseModel):
    household_id: str
    item: InventoryItemResponse
    removed_ids: list[str]
    shopping_list_items: list[ShoppingListItemResponse] = Field(default_factory=list)


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
    category: OptionalCategory = None
    quantity: int = 1
    image_url: str | None = None
    source: Literal[
        "openfoodfacts", "openproductsfacts", "openbeautyfacts", "openpetfoodfacts", "none"
    ] = "none"
    health: ProductHealth | None = None
    # Filled when the lookup is scoped to a household (?household_id=…)
    warnings: list[MemberWarning] = Field(default_factory=list)


class ProductSearchHit(BaseModel):
    """One product variant from a name search (REQ-006 / REQ-007 AC2)."""

    barcode: str | None = None
    name: str
    brand: str | None = None
    category: Category
    image_url: str | None = None
    source: Literal["openfoodfacts"] = "openfoodfacts"
    health: ProductHealth | None = None


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
    category: Category = Field(default="Other", min_length=1, max_length=60)
    quantity: int = Field(default=1, ge=1, le=9999)
    price_paid: float | None = Field(default=None, ge=0)
    barcode: str | None = Field(default=None, max_length=64)
    image_url: str | None = Field(default=None, max_length=2048)
    identified: bool = False
    # Line text as printed (before abbreviation expansion) and any item code
    # printed on the line; both feed the shared catalog's aliases (ADR-008).
    receipt_text: str | None = Field(default=None, max_length=200)
    receipt_code: str | None = Field(default=None, max_length=64)
    # Shared catalog product and how the line matched it (REQ-RCP-007 AC5).
    matched_product_id: str | None = Field(default=None, max_length=64)
    match_method: Literal["upc", "plu", "alias", "plu_standard", "open_food_facts"] | None = None


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
    # Printed store brand ("Walmart #1234"); shown in capture guidance (REQ-RCP-020).
    store_name: str | None = None
    # `store_chains.chain_id` for store_name; clients send it back on capture (REQ-RCP-007 AC5).
    store_chain_id: str = "unknown"


class ItemPhotoUploadResponse(BaseModel):
    """
    Satisfies: REQ-INV-019 (Replace an Item Picture With a Private Photo)
    Acceptance criteria: AC1
    Spec version: 1.0

    `url` is the household-scoped API path; it needs the member's bearer token.
    """

    photo_id: str
    url: str


class ProductPhotoUploadJson(BaseModel):
    """
    Satisfies: REQ-RCP-021 AC1
    Spec version: 1.0

    JSON form of the product photo upload; multipart `file` is also accepted.
    """

    image_base64: str = Field(min_length=1)
    content_type: Literal["image/jpeg", "image/png", "image/heic"] = "image/jpeg"


class ProductPhotoResponse(BaseModel):
    """
    Satisfies: REQ-RCP-021 AC1, AC4
    Spec version: 1.0

    `image_url` is the stable `/v1/product-photos/{photo_id}` path that a
    capture stores on the product; `expires_at` stays set until a capture
    references the photo.
    """

    photo_id: str
    image_url: str
    width: int
    height: int
    bytes: int
    created_at: datetime
    expires_at: datetime | None = None


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
    # REQ-021 AC1: ingredients / allergens this member avoids (catalog keys or free text)
    avoid: list[str] = Field(default_factory=list)
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
    category: Category = Field(min_length=1, max_length=60)
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

    category: OptionalCategory = Field(default=None, min_length=1, max_length=60)
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



# ---------------------------------------------------------------------------
# Shared product catalog (docs/api/receipt-parser.openapi.yaml `products` tag, /v1/catalog)
# ---------------------------------------------------------------------------

CatalogProductStatus = Literal["unverified", "pending", "verified"]
CatalogProductSource = Literal["user_scan", "store_api", "gs1_registry", "llm_ocr"]
CatalogImageSource = Literal["user_photo", "store_api", "openfoodfacts", "gs1_registry", "placeholder"]


class CatalogProductResponse(BaseModel):
    """
    Satisfies: REQ-RCP-011
    Spec version: 1.0

    OpenAPI `Product` (served under `/v1/catalog/products`). Any signed-in user may read it; it carries no household data.
    """

    id: str
    code_kind: Literal["upc", "plu", "llm"] = "upc"
    upc: str | None = None
    plu_code: str | None = None
    store_chain_id: str
    name: str
    brand: str | None = None
    category: str
    unit_size: str | None = None
    image_url: str | None = None
    image_source: CatalogImageSource | None = None
    source: CatalogProductSource
    confidence_score: float = Field(ge=0, le=1)
    confirmation_count: int = Field(ge=0)
    status: CatalogProductStatus
    superseded_by: str | None = None


class CatalogSearchResponse(BaseModel):
    query: str
    results: list[CatalogProductResponse]


class ProductConflictResponse(BaseModel):
    """OpenAPI `ProductConflict` (REQ-RCP-014, REQ-RCP-019 AC3)."""

    id: str
    product_id: str
    field: Literal["name", "brand", "unit_size", "category", "upc", "image_url"]
    verified_value: str
    observed_value: str
    status: Literal["open", "dismissed", "accepted"]


class ProductCorrectionSourceLine(BaseModel):
    receipt_id: str
    line_item_id: str


class ProductCorrectionRequest(BaseModel):
    """
    Satisfies: REQ-RCP-019 AC3–AC5
    Spec version: 1.0

    `household_id` is hashed server-side before anything touches the catalog.
    """

    household_id: str = Field(min_length=1)
    name: str | None = Field(default=None, min_length=1, max_length=120)
    brand: str | None = Field(default=None, max_length=80)
    category: OptionalCategory = Field(default=None, min_length=1, max_length=60)
    unit_size: str | None = Field(default=None, max_length=40)
    upc: str | None = Field(default=None, pattern=r"^[0-9]{8,14}$")
    source_line_item: ProductCorrectionSourceLine | None = None


class ProductCorrectionResponse(BaseModel):
    """OpenAPI `ProductCorrectionResponse`."""

    applied: bool
    product: CatalogProductResponse
    conflicts: list[ProductConflictResponse] = Field(default_factory=list)
    status_reset: bool = False


class ProductCaptureRequest(BaseModel):
    """
    Satisfies: REQ-RCP-020 AC2, AC6, AC7, AC9
    Spec version: 1.0

    Exactly one of `upc` (scanned barcode) or `plu_code` (typed from a produce
    sticker), an optional photo from `POST …/product-photos`, and the
    new-product card's name/category. Missing attributes fall back to the item.
    Code shapes are checked by the catalog so the API returns
    `invalid_upc` / `invalid_plu` instead of a generic validation error.
    """

    model_config = {"extra": "forbid"}

    upc: str | None = Field(default=None, max_length=32)
    plu_code: str | None = Field(default=None, max_length=16)
    photo_id: str | None = None
    name: str | None = Field(default=None, min_length=1, max_length=120)
    brand: str | None = Field(default=None, max_length=80)
    category: str | None = Field(default=None, min_length=1, max_length=60)
    unit_size: str | None = Field(default=None, max_length=40)
    # Receipt line the item came from; written as an alias (REQ-RCP-020 AC6).
    receipt_text: str | None = Field(default=None, max_length=200)
    store_chain_id: str | None = Field(default=None, max_length=40)

    @model_validator(mode="after")
    def _strip(self) -> "ProductCaptureRequest":
        for key in ("upc", "plu_code", "name", "brand", "unit_size", "receipt_text", "store_chain_id"):
            value = getattr(self, key)
            if isinstance(value, str):
                setattr(self, key, value.strip() or None)
        return self


class ProductCaptureResponse(BaseModel):
    """
    Satisfies: REQ-RCP-020 AC2–AC7
    Spec version: 1.0

    OpenAPI `ProductCaptureResponse`; the inventory variant also returns the
    updated item so clients need not refetch it.
    """

    outcome: Literal["linked", "created", "rekeyed"]
    product: CatalogProductResponse
    inventory_item_id: str | None = None
    inventory_item: InventoryItemResponse | None = None
    scan_event_id: str
    confirmation_counted: bool
    enrichment_job_id: str | None = None
    photo_applied_as: Literal["product_image", "line_image", "correction_proposed", "none"] = "none"
    conflict: ProductConflictResponse | None = None
