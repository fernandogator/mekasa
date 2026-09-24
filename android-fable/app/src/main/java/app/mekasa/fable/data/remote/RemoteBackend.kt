package app.mekasa.fable.data.remote

import app.mekasa.fable.data.HouseholdBackend
import app.mekasa.fable.data.InventoryDraft
import app.mekasa.fable.data.model.BarcodeLookup
import app.mekasa.fable.data.model.ConsumeByBarcodeResult
import app.mekasa.fable.data.model.Household
import app.mekasa.fable.data.model.HouseholdInvite
import app.mekasa.fable.data.model.HouseholdMember
import app.mekasa.fable.data.model.InventoryItem
import app.mekasa.fable.data.model.InventoryItemCreateRequest
import app.mekasa.fable.data.model.InventoryItemPatch
import app.mekasa.fable.data.model.InviteCreateRequest
import app.mekasa.fable.data.model.ProductHit
import app.mekasa.fable.data.model.ReceiptScanResponse
import app.mekasa.fable.data.model.ShoppingItem
import app.mekasa.fable.data.model.ShoppingItemCreateRequest
import app.mekasa.fable.data.model.ShoppingItemPatch
import app.mekasa.fable.data.model.SpendingReport
import app.mekasa.fable.data.model.Store
import app.mekasa.fable.data.model.UnknownBarcodeEvent
import app.mekasa.fable.data.model.UserProfile

/**
 * [HouseholdBackend] over the Cloud Run API. [token] is read on every call so a
 * refreshed Firebase ID token is picked up without rebuilding the backend.
 */
class RemoteBackend(
    private val api: MekasaApi,
    private val token: () -> String,
) : HouseholdBackend {

    override val isDemo: Boolean = false

    override suspend fun profile(): UserProfile? = api.me(token())

    override suspend fun currentHousehold(): Household? = try {
        api.currentHousehold(token())
    } catch (e: ApiException) {
        if (e.isNotFound) null else throw e
    }

    override suspend fun createHousehold(name: String?): Household = api.createHousehold(token(), name)

    override suspend fun updateAddress(householdId: String, address: String): Household =
        api.updateAddress(token(), householdId, address)

    override suspend fun nearbyStores(householdId: String): List<Store> =
        api.nearbyStores(token(), householdId).stores

    override suspend fun selectStores(householdId: String, storeIds: List<String>): Household =
        api.selectStores(token(), householdId, storeIds)

    override suspend fun renameHousehold(householdId: String, name: String?): Household =
        api.renameHousehold(token(), householdId, name)

    override suspend fun uploadHomePhoto(householdId: String, jpeg: ByteArray): Household =
        api.uploadHouseholdPhoto(token(), householdId, jpeg, "image/jpeg", "home.jpg")

    override suspend fun inventory(householdId: String): List<InventoryItem> =
        api.listInventory(token(), householdId).items.filterNot { it.deleted }

    override suspend fun addInventory(householdId: String, draft: InventoryDraft): InventoryItem =
        api.createInventoryItem(
            token(),
            householdId,
            InventoryItemCreateRequest(
                name = draft.name,
                category = draft.category,
                quantity = draft.quantity,
                barcode = draft.barcode,
                imageUrl = draft.imageUrl,
                source = draft.source,
                pricePaid = draft.pricePaid,
            ),
        )

    override suspend fun updateInventory(
        householdId: String,
        itemId: String,
        quantity: Int?,
        threshold: Int?,
    ): InventoryItem = api.patchInventoryItem(
        token(),
        householdId,
        itemId,
        InventoryItemPatch(quantity = quantity, lowStockThreshold = threshold),
    )

    override suspend fun consume(householdId: String, itemId: String, amount: Int): InventoryItem =
        api.consumeInventoryItem(token(), householdId, itemId, amount)

    override suspend fun consumeByBarcode(householdId: String, barcode: String, amount: Int): ConsumeByBarcodeResult =
        api.consumeByBarcode(token(), householdId, barcode, amount)

    override suspend fun refreshImage(householdId: String, itemId: String): InventoryItem =
        api.refreshInventoryImage(token(), householdId, itemId)

    override suspend fun unknownScans(householdId: String): List<UnknownBarcodeEvent> =
        api.listUnknownScans(token(), householdId)

    override suspend fun shoppingList(householdId: String): List<ShoppingItem> =
        api.listShopping(token(), householdId).items

    override suspend fun addShoppingItem(householdId: String, name: String, quantity: Int): ShoppingItem =
        api.createShoppingItem(token(), householdId, ShoppingItemCreateRequest(name = name, quantity = quantity))

    override suspend fun setShoppingChecked(householdId: String, itemId: String, checked: Boolean): ShoppingItem =
        api.patchShoppingItem(token(), householdId, itemId, ShoppingItemPatch(isChecked = checked))

    override suspend fun deleteShoppingItem(householdId: String, itemId: String) =
        api.deleteShoppingItem(token(), householdId, itemId)

    override suspend fun approveShoppingItem(householdId: String, itemId: String): ShoppingItem =
        api.approveShoppingItem(token(), householdId, itemId)

    override suspend fun rejectShoppingItem(householdId: String, itemId: String): ShoppingItem =
        api.rejectShoppingItem(token(), householdId, itemId)

    override suspend fun syncShoppingFromInventory(householdId: String): List<ShoppingItem> =
        api.syncShoppingFromInventory(token(), householdId).items

    override suspend fun spending(householdId: String, period: String): SpendingReport =
        api.spending(token(), householdId, period)

    override suspend fun members(householdId: String): List<HouseholdMember> =
        api.listMembers(token(), householdId).members

    override suspend fun invites(householdId: String): List<HouseholdInvite> =
        api.listInvites(token(), householdId).invites

    override suspend fun createInvite(householdId: String, name: String, email: String?, role: String): HouseholdInvite =
        api.createInvite(token(), householdId, InviteCreateRequest(name = name, email = email, role = role))

    override suspend fun acceptInvite(inviteToken: String): HouseholdMember = api.acceptInvite(token(), inviteToken)

    override suspend fun updateMemberRole(householdId: String, memberUid: String, role: String): HouseholdMember =
        api.updateMemberRole(token(), householdId, memberUid, role)

    override suspend fun lookupBarcode(code: String): BarcodeLookup = api.lookupBarcode(token(), code)

    override suspend fun searchProducts(query: String): List<ProductHit> =
        api.searchProducts(token(), query).results

    override suspend fun scanReceipt(householdId: String, rawText: String?, imageBase64: String?): ReceiptScanResponse =
        api.scanReceipt(token(), householdId, rawText, imageBase64)
}
