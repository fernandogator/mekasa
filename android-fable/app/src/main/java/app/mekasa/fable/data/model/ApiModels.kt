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
    val source: String = "manual",
    val deleted: Boolean = false,
) {
    val isLowStock: Boolean get() = quantity <= lowStockThreshold
    val hasImage: Boolean get() = !imageUrl.isNullOrBlank()
}

@Serializable
data class InventoryListResponse(
    @SerialName("household_id") val householdId: String? = null,
    val items: List<InventoryItem> = emptyList(),
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
)
