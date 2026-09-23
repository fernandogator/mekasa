package app.mekasa.android.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

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
)

@Serializable
data class Store(
    val id: String,
    val name: String,
    val address: String,
    val latitude: Double = 0.0,
    val longitude: Double = 0.0,
    @SerialName("distance_miles") val distanceMiles: Double = 0.0,
    val provider: String = "stub",
)

@Serializable
data class StoreSearchResponse(
    @SerialName("household_id") val householdId: String,
    @SerialName("radius_miles") val radiusMiles: Double = 0.0,
    val stores: List<Store> = emptyList(),
)

@Serializable
data class InventoryItemDto(
    val id: String,
    @SerialName("household_id") val householdId: String,
    val name: String,
    val category: String,
    val quantity: Int,
    @SerialName("low_stock_threshold") val lowStockThreshold: Int = 1,
    @SerialName("price_paid") val pricePaid: Double? = null,
    val barcode: String? = null,
    @SerialName("image_url") val imageUrl: String? = null,
    val source: String = "manual",
)

@Serializable
data class InventoryListResponse(
    val items: List<InventoryItemDto> = emptyList(),
)

@Serializable
data class ShoppingListItemDto(
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
    val items: List<ShoppingListItemDto> = emptyList(),
)

@Serializable
data class ShoppingListSyncResponse(
    @SerialName("household_id") val householdId: String? = null,
    val added: List<ShoppingListItemDto> = emptyList(),
    val items: List<ShoppingListItemDto> = emptyList(),
)

@Serializable
data class ShoppingListItemCreateRequest(
    val name: String,
    val quantity: Int = 1,
    @SerialName("is_checked") val isChecked: Boolean = false,
    @SerialName("needs_approval") val needsApproval: Boolean = false,
    val kind: String = "custom",
)

@Serializable
data class ShoppingListItemUpdateRequest(
    val name: String? = null,
    val quantity: Int? = null,
    @SerialName("is_checked") val isChecked: Boolean? = null,
    @SerialName("needs_approval") val needsApproval: Boolean? = null,
    val kind: String? = null,
)

@Serializable
data class SpendingReportDto(
    val period: String,
    @SerialName("total_spent") val totalSpent: Double = 0.0,
    val categories: List<SpendingCategoryDto> = emptyList(),
)

@Serializable
data class SpendingCategoryDto(
    val category: String,
    val total: Double,
)

@Serializable
data class ProductSearchHit(
    val barcode: String? = null,
    val name: String,
    val brand: String? = null,
    val category: String = "Other",
    @SerialName("image_url") val imageUrl: String? = null,
    val source: String = "openfoodfacts",
)

@Serializable
data class ProductSearchResponse(
    val query: String,
    val results: List<ProductSearchHit> = emptyList(),
)

@Serializable
data class BarcodeLookupResponse(
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
data class HealthResponse(
    val status: String,
    val service: String? = null,
    val environment: String? = null,
    val persistence: String? = null,
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
data class InventoryConsumeRequest(
    val amount: Int = 1,
)
