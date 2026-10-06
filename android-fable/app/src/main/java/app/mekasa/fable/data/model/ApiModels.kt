package app.mekasa.fable.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/*
 * Wire models for the Mekasa Cloud Run API (backend/app/models.py).
 * Field names follow the Python snake_case contract via @SerialName; unknown
 * keys (timestamps, audit uids) are ignored by the JSON config.
 */

@Serializable
data class HealthResponse(
    val status: String,
    val service: String? = null,
    val environment: String? = null,
    val persistence: String? = null,
)

@Serializable
data class UserProfile(
    val uid: String,
    val email: String? = null,
    val name: String? = null,
)

@Serializable
data class Household(
    val id: String,
    val name: String? = null,
    @SerialName("photo_url") val photoUrl: String? = null,
    @SerialName("owner_uid") val ownerUid: String,
    val address: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    @SerialName("store_ids") val storeIds: List<String> = emptyList(),
) {
    val hasAddress: Boolean get() = !address.isNullOrBlank()
    val hasStores: Boolean get() = storeIds.isNotEmpty()
}

@Serializable
data class HouseholdCreateRequest(
    val name: String? = null,
    @SerialName("photo_url") val photoUrl: String? = null,
)

@Serializable
data class AddressUpdateRequest(
    val address: String,
    val latitude: Double? = null,
    val longitude: Double? = null,
)

@Serializable
data class HouseholdNameUpdateRequest(val name: String? = null)

@Serializable
data class StoreSelectionRequest(@SerialName("store_ids") val storeIds: List<String>)

@Serializable
data class Store(
    val id: String,
    val name: String,
    val address: String = "",
    val latitude: Double = 0.0,
    val longitude: Double = 0.0,
    @SerialName("distance_miles") val distanceMiles: Double = 0.0,
    val provider: String = "stub",
)

@Serializable
data class StoreSearchResponse(
    @SerialName("household_id") val householdId: String? = null,
    @SerialName("radius_miles") val radiusMiles: Double = 0.0,
    val stores: List<Store> = emptyList(),
)

// ---------------------------------------------------------------- inventory

@Serializable
data class InventoryItem(
    val id: String,
    @SerialName("household_id") val householdId: String,
    val name: String,
    val category: String = "Other",
    val quantity: Int = 0,
    @SerialName("low_stock_threshold") val lowStockThreshold: Int = 1,
    @SerialName("price_paid") val pricePaid: Double? = null,
    val barcode: String? = null,
    @SerialName("image_url") val imageUrl: String? = null,
    /** Shared catalog product (UPC, `plu:<code>` or `llm:<sha1>`) linked by a capture (REQ-RCP-020 AC6, AC15). */
    @SerialName("product_id") val productId: String? = null,
    val source: String = "manual",
    val deleted: Boolean = false,
    /** When `image_url` last changed (REQ-INV-021 AC2); null on older rows, which fall back to [updatedAt]. */
    @SerialName("image_updated_at") val imageUpdatedAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
) {
    val isLowStock: Boolean get() = quantity <= lowStockThreshold
    val hasImage: Boolean get() = !imageUrl.isNullOrBlank()

    /** No code yet: a barcode or PLU can still be added from item detail (REQ-RCP-020 AC15). */
    val canAddCode: Boolean get() = barcode.isNullOrBlank() && (productId == null || productId.startsWith("llm:"))
}

@Serializable
data class InventoryListResponse(
    @SerialName("household_id") val householdId: String? = null,
    val items: List<InventoryItem> = emptyList(),
)

/** Why items were grouped as duplicates, strongest first (REQ-INV-021 AC1). */
@Serializable
enum class DuplicateReason(val label: String) {
    @SerialName("same_barcode") SameBarcode("Same barcode"),
    @SerialName("same_product") SameProduct("Same product"),
    @SerialName("same_name") SameName("Same name"),
}

/** One duplicate group; [keepId] survives a merge (REQ-INV-021 AC2). */
@Serializable
data class DuplicateGroup(
    val reason: DuplicateReason,
    @SerialName("keep_id") val keepId: String,
    val items: List<InventoryItem>,
) {
    val id: String get() = items.map { it.id }.sorted().joinToString("|")
    val survivor: InventoryItem? get() = items.firstOrNull { it.id == keepId }
    val others: List<InventoryItem> get() = items.filter { it.id != keepId }

    /** Changes whenever any item in the group changes, so "Not duplicates" lapses (AC5). */
    val signature: String get() = items.map { "${it.id}@${it.updatedAt.orEmpty()}" }.sorted().joinToString("|")
}

/** `GET /v1/households/{id}/inventory/duplicates` (REQ-INV-021 AC1). */
@Serializable
data class InventoryDuplicatesResponse(
    @SerialName("household_id") val householdId: String? = null,
    val groups: List<DuplicateGroup> = emptyList(),
)

@Serializable
data class InventoryMergeRequest(@SerialName("item_ids") val itemIds: List<String>)

/** `POST /v1/households/{id}/inventory/merge` (REQ-INV-021 AC3). */
@Serializable
data class InventoryMergeResponse(
    @SerialName("household_id") val householdId: String? = null,
    val item: InventoryItem,
    @SerialName("removed_ids") val removedIds: List<String> = emptyList(),
    @SerialName("shopping_list_items") val shoppingListItems: List<ShoppingItem> = emptyList(),
)

@Serializable
data class InventoryItemCreateRequest(
    val name: String,
    val category: String = "Other",
    val quantity: Int = 1,
    @SerialName("low_stock_threshold") val lowStockThreshold: Int = 1,
    @SerialName("price_paid") val pricePaid: Double? = null,
    val barcode: String? = null,
    @SerialName("image_url") val imageUrl: String? = null,
    val source: String = "manual",
)

/** `POST /v1/households/{id}/product-photos` result (REQ-RCP-021 AC1): shared with the captured product. */
@Serializable
data class ProductPhotoUpload(
    @SerialName("photo_id") val photoId: String,
    @SerialName("image_url") val imageUrl: String,
)

/** `POST …/inventory/{id}/capture` body (REQ-RCP-020 AC2, AC6, AC7, AC15). */
@Serializable
data class ProductCaptureRequest(
    val upc: String? = null,
    @SerialName("plu_code") val pluCode: String? = null,
    @SerialName("photo_id") val photoId: String? = null,
    @SerialName("receipt_text") val receiptText: String? = null,
    @SerialName("store_chain_id") val storeChainId: String? = null,
)

@Serializable
data class ProductCaptureResponse(
    val outcome: String,
    @SerialName("photo_applied_as") val photoAppliedAs: String? = null,
    @SerialName("inventory_item") val inventoryItem: InventoryItem? = null,
)

/** `POST /v1/households/{id}/item-photos` result (REQ-INV-019 AC1). */
@Serializable
data class ItemPhotoUpload(
    @SerialName("photo_id") val photoId: String,
    val url: String,
)

@Serializable
data class InventoryItemPatch(
    val name: String? = null,
    val category: String? = null,
    val quantity: Int? = null,
    @SerialName("low_stock_threshold") val lowStockThreshold: Int? = null,
    @SerialName("price_paid") val pricePaid: Double? = null,
    val barcode: String? = null,
    @SerialName("image_url") val imageUrl: String? = null,
)

@Serializable
data class ConsumeRequest(val amount: Int = 1)

@Serializable
data class ConsumeByBarcodeRequest(val barcode: String, val amount: Int = 1)

@Serializable
data class UnknownBarcodeEvent(
    val id: String,
    @SerialName("household_id") val householdId: String,
    val barcode: String,
    @SerialName("scanned_by_uid") val scannedByUid: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
)

@Serializable
data class ConsumeByBarcodeResult(
    val found: Boolean = false,
    val item: InventoryItem? = null,
    @SerialName("unknown_event") val unknownEvent: UnknownBarcodeEvent? = null,
)

// ------------------------------------------------------------ shopping list

@Serializable
data class ShoppingItem(
    val id: String,
    @SerialName("household_id") val householdId: String,
    val name: String,
    val quantity: Int = 1,
    @SerialName("quantity_label") val quantityLabel: String? = null,
    @SerialName("is_checked") val isChecked: Boolean = false,
    @SerialName("needs_approval") val needsApproval: Boolean = false,
    @SerialName("requested_by") val requestedBy: String? = null,
    @SerialName("inventory_item_id") val inventoryItemId: String? = null,
    val kind: String = "custom",
)

@Serializable
data class ShoppingListResponse(
    @SerialName("household_id") val householdId: String? = null,
    val items: List<ShoppingItem> = emptyList(),
)

@Serializable
data class ShoppingSyncResponse(
    @SerialName("household_id") val householdId: String? = null,
    val added: List<ShoppingItem> = emptyList(),
    val items: List<ShoppingItem> = emptyList(),
)

@Serializable
data class ShoppingItemCreateRequest(
    val name: String,
    val quantity: Int = 1,
    @SerialName("quantity_label") val quantityLabel: String? = null,
    @SerialName("is_checked") val isChecked: Boolean = false,
    @SerialName("needs_approval") val needsApproval: Boolean = false,
    @SerialName("requested_by") val requestedBy: String? = null,
    val kind: String = "custom",
)

@Serializable
data class ShoppingItemPatch(
    val name: String? = null,
    val quantity: Int? = null,
    @SerialName("is_checked") val isChecked: Boolean? = null,
    @SerialName("needs_approval") val needsApproval: Boolean? = null,
    val kind: String? = null,
)

// ----------------------------------------------------------------- spending

@Serializable
data class SpendingCategoryTotal(val category: String, val total: Double = 0.0)

@Serializable
data class SpendingReport(
    val period: String,
    val total: Double = 0.0,
    val currency: String = "USD",
    @SerialName("by_category") val byCategory: List<SpendingCategoryTotal> = emptyList(),
    @SerialName("household_id") val householdId: String? = null,
)

// ------------------------------------------------------- members & invites

@Serializable
data class HouseholdMember(
    val uid: String,
    @SerialName("household_id") val householdId: String,
    val name: String? = null,
    val email: String? = null,
    val phone: String? = null,
    val role: String = "member",
    val status: String = "active",
    val permissions: List<String> = emptyList(),
) {
    val isOwner: Boolean get() = role == "owner"
    val displayLabel: String get() = name ?: email ?: uid
}

@Serializable
data class HouseholdMembersResponse(
    @SerialName("household_id") val householdId: String? = null,
    val members: List<HouseholdMember> = emptyList(),
)

@Serializable
data class HouseholdInvite(
    val id: String,
    @SerialName("household_id") val householdId: String,
    val name: String,
    val email: String? = null,
    val phone: String? = null,
    val role: String = "member",
    val token: String,
    val status: String = "pending",
    @SerialName("invited_by_uid") val invitedByUid: String? = null,
    @SerialName("invite_link") val inviteLink: String? = null,
) {
    val shareLink: String get() = inviteLink ?: "mekasa://invite?token=$token"
}

@Serializable
data class HouseholdInvitesResponse(
    @SerialName("household_id") val householdId: String? = null,
    val invites: List<HouseholdInvite> = emptyList(),
)

@Serializable
data class InviteCreateRequest(
    val name: String,
    val email: String? = null,
    val phone: String? = null,
    val role: String = "member",
)

@Serializable
data class InviteAcceptRequest(val token: String)

@Serializable
data class MemberRoleUpdateRequest(val role: String)

// ------------------------------------------------------- catalog & receipts

@Serializable
data class BarcodeLookup(
    val barcode: String,
    val found: Boolean = false,
    val name: String? = null,
    val brand: String? = null,
    val category: String? = null,
    val quantity: Int = 1,
    @SerialName("image_url") val imageUrl: String? = null,
    val source: String = "none",
)

@Serializable
data class ProductHit(
    val barcode: String? = null,
    val name: String,
    val brand: String? = null,
    val category: String = "Other",
    @SerialName("image_url") val imageUrl: String? = null,
    val source: String = "openfoodfacts",
)

@Serializable
data class ProductSearchResponse(
    val query: String = "",
    val results: List<ProductHit> = emptyList(),
)

@Serializable
data class ReceiptLine(
    val name: String,
    val category: String = "Other",
    val quantity: Int = 1,
    @SerialName("price_paid") val pricePaid: Double? = null,
    val barcode: String? = null,
    @SerialName("image_url") val imageUrl: String? = null,
    val identified: Boolean = false,
    /** Line text as printed; a capture sends it as the alias (REQ-RCP-020 AC6). */
    @SerialName("receipt_text") val receiptText: String? = null,
)

@Serializable
data class ReceiptScanRequest(
    @SerialName("image_base64") val imageBase64: String? = null,
    @SerialName("raw_text") val rawText: String? = null,
)

@Serializable
data class ReceiptScanResponse(
    @SerialName("household_id") val householdId: String? = null,
    val engine: String = "demo",
    val items: List<ReceiptLine> = emptyList(),
    @SerialName("store_name") val storeName: String? = null,
    /** Chain the printed store matched (REQ-RCP-007 AC5); scopes capture aliases. */
    @SerialName("store_chain_id") val storeChainId: String? = null,
)
