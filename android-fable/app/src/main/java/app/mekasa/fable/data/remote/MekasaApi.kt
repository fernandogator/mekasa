package app.mekasa.fable.data.remote

import app.mekasa.fable.data.model.BarcodeLookup
import app.mekasa.fable.data.model.ConsumeByBarcodeResult
import app.mekasa.fable.data.model.HealthResponse
import app.mekasa.fable.data.model.Household
import app.mekasa.fable.data.model.HouseholdInvite
import app.mekasa.fable.data.model.HouseholdInvitesResponse
import app.mekasa.fable.data.model.HouseholdMember
import app.mekasa.fable.data.model.HouseholdMembersResponse
import app.mekasa.fable.data.model.InventoryItem
import app.mekasa.fable.data.model.InventoryItemCreateRequest
import app.mekasa.fable.data.model.InventoryItemPatch
import app.mekasa.fable.data.model.InventoryListResponse
import app.mekasa.fable.data.model.InviteCreateRequest
import app.mekasa.fable.data.model.ProductSearchResponse
import app.mekasa.fable.data.model.ReceiptScanResponse
import app.mekasa.fable.data.model.ShoppingItem
import app.mekasa.fable.data.model.ShoppingItemCreateRequest
import app.mekasa.fable.data.model.ShoppingItemPatch
import app.mekasa.fable.data.model.ShoppingListResponse
import app.mekasa.fable.data.model.ShoppingSyncResponse
import app.mekasa.fable.data.model.SpendingReport
import app.mekasa.fable.data.model.StoreSearchResponse
import app.mekasa.fable.data.model.UnknownBarcodeEvent
import app.mekasa.fable.data.model.UserProfile

/**
 * One method per Cloud Run route. Every authenticated call takes the Firebase
 * ID token (or `test:<uid>` in debug) as [token]; it is sent as `Authorization: Bearer`.
 */
interface MekasaApi {
    suspend fun health(): HealthResponse
    suspend fun me(token: String): UserProfile

    // Household / onboarding
    suspend fun createHousehold(token: String, name: String?): Household
    suspend fun currentHousehold(token: String): Household
    suspend fun updateAddress(token: String, householdId: String, address: String): Household
    suspend fun renameHousehold(token: String, householdId: String, name: String?): Household
    suspend fun uploadHouseholdPhoto(
        token: String,
        householdId: String,
        bytes: ByteArray,
        mimeType: String,
        filename: String,
    ): Household
    suspend fun nearbyStores(token: String, householdId: String): StoreSearchResponse
    suspend fun selectStores(token: String, householdId: String, storeIds: List<String>): Household

    // Inventory
    suspend fun listInventory(token: String, householdId: String): InventoryListResponse
    suspend fun createInventoryItem(token: String, householdId: String, body: InventoryItemCreateRequest): InventoryItem
    suspend fun patchInventoryItem(token: String, householdId: String, itemId: String, patch: InventoryItemPatch): InventoryItem
    suspend fun refreshInventoryImage(token: String, householdId: String, itemId: String): InventoryItem
    suspend fun consumeInventoryItem(token: String, householdId: String, itemId: String, amount: Int): InventoryItem
    suspend fun consumeByBarcode(token: String, householdId: String, barcode: String, amount: Int): ConsumeByBarcodeResult
    suspend fun listUnknownScans(token: String, householdId: String): List<UnknownBarcodeEvent>

    // Shopping list
    suspend fun listShopping(token: String, householdId: String): ShoppingListResponse
    suspend fun createShoppingItem(token: String, householdId: String, body: ShoppingItemCreateRequest): ShoppingItem
    suspend fun patchShoppingItem(token: String, householdId: String, itemId: String, patch: ShoppingItemPatch): ShoppingItem
    suspend fun deleteShoppingItem(token: String, householdId: String, itemId: String)
    suspend fun approveShoppingItem(token: String, householdId: String, itemId: String): ShoppingItem
    suspend fun rejectShoppingItem(token: String, householdId: String, itemId: String): ShoppingItem
    suspend fun syncShoppingFromInventory(token: String, householdId: String): ShoppingSyncResponse

    // Spending
    suspend fun spending(token: String, householdId: String, period: String): SpendingReport

    // Members & invites
    suspend fun listMembers(token: String, householdId: String): HouseholdMembersResponse
    suspend fun listInvites(token: String, householdId: String): HouseholdInvitesResponse
    suspend fun createInvite(token: String, householdId: String, body: InviteCreateRequest): HouseholdInvite
    suspend fun acceptInvite(token: String, inviteToken: String): HouseholdMember
    suspend fun updateMemberRole(token: String, householdId: String, memberUid: String, role: String): HouseholdMember

    // Catalog & receipts
    suspend fun lookupBarcode(token: String, code: String): BarcodeLookup
    suspend fun searchProducts(token: String, query: String, limit: Int = 8): ProductSearchResponse
    suspend fun scanReceipt(token: String, householdId: String, rawText: String?, imageBase64: String?): ReceiptScanResponse

    fun close()
}
