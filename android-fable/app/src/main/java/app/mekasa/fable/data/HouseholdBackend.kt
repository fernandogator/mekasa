package app.mekasa.fable.data

import app.mekasa.fable.data.model.BarcodeLookup
import app.mekasa.fable.data.model.ConsumeByBarcodeResult
import app.mekasa.fable.data.model.Household
import app.mekasa.fable.data.model.HouseholdInvite
import app.mekasa.fable.data.model.HouseholdMember
import app.mekasa.fable.data.model.InventoryItem
import app.mekasa.fable.data.model.ProductHit
import app.mekasa.fable.data.model.ReceiptScanResponse
import app.mekasa.fable.data.model.ShoppingItem
import app.mekasa.fable.data.model.SpendingReport
import app.mekasa.fable.data.model.Store
import app.mekasa.fable.data.model.UnknownBarcodeEvent
import app.mekasa.fable.data.model.UserProfile

/** What the UI collects before an inventory row is created (scan, search, voice, receipt). */
data class InventoryDraft(
    val name: String,
    val category: String = "Other",
    val quantity: Int = 1,
    val barcode: String? = null,
    val imageUrl: String? = null,
    val source: String = "manual",
    val pricePaid: Double? = null,
)

/**
 * Everything the app can do once a user is signed in, independent of transport.
 * [RemoteBackend] talks to Cloud Run; [app.mekasa.fable.data.demo.DemoBackend]
 * keeps everything in memory for the offline "Browse UI" preview and unit tests.
 * The session layer therefore has a single code path for both modes.
 */
interface HouseholdBackend {
    val isDemo: Boolean

    suspend fun profile(): UserProfile?
    suspend fun currentHousehold(): Household?
    suspend fun createHousehold(name: String?): Household
    suspend fun updateAddress(householdId: String, address: String): Household
    suspend fun nearbyStores(householdId: String): List<Store>
    suspend fun selectStores(householdId: String, storeIds: List<String>): Household
    suspend fun renameHousehold(householdId: String, name: String?): Household
    suspend fun uploadHomePhoto(householdId: String, jpeg: ByteArray): Household

    suspend fun inventory(householdId: String): List<InventoryItem>
    suspend fun addInventory(householdId: String, draft: InventoryDraft): InventoryItem
    suspend fun updateInventory(householdId: String, itemId: String, quantity: Int?, threshold: Int?): InventoryItem
    suspend fun consume(householdId: String, itemId: String, amount: Int): InventoryItem
    suspend fun consumeByBarcode(householdId: String, barcode: String, amount: Int): ConsumeByBarcodeResult
    suspend fun refreshImage(householdId: String, itemId: String): InventoryItem
    suspend fun unknownScans(householdId: String): List<UnknownBarcodeEvent>

    suspend fun shoppingList(householdId: String): List<ShoppingItem>
    suspend fun addShoppingItem(householdId: String, name: String, quantity: Int): ShoppingItem
    suspend fun setShoppingChecked(householdId: String, itemId: String, checked: Boolean): ShoppingItem
    suspend fun deleteShoppingItem(householdId: String, itemId: String)
    suspend fun approveShoppingItem(householdId: String, itemId: String): ShoppingItem
    suspend fun rejectShoppingItem(householdId: String, itemId: String): ShoppingItem
    suspend fun syncShoppingFromInventory(householdId: String): List<ShoppingItem>

    suspend fun spending(householdId: String, period: String): SpendingReport

    suspend fun members(householdId: String): List<HouseholdMember>
    suspend fun invites(householdId: String): List<HouseholdInvite>
    suspend fun createInvite(householdId: String, name: String, email: String?, role: String): HouseholdInvite
    suspend fun acceptInvite(inviteToken: String): HouseholdMember
    suspend fun updateMemberRole(householdId: String, memberUid: String, role: String): HouseholdMember

    suspend fun lookupBarcode(code: String): BarcodeLookup
    suspend fun searchProducts(query: String): List<ProductHit>
    suspend fun scanReceipt(householdId: String, rawText: String?, imageBase64: String?): ReceiptScanResponse
}
