package app.mekasa.fable.support

import android.app.Activity
import android.content.Intent
import app.mekasa.fable.auth.AuthGateway
import app.mekasa.fable.auth.SignedInUser
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
import app.mekasa.fable.data.remote.ApiException
import app.mekasa.fable.data.remote.MekasaApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow

/** Scripted auth: sign-in succeeds with [user]; token refresh returns [refreshedToken]. */
class FakeAuthGateway(
    override val isConfigured: Boolean = true,
    var user: SignedInUser = SignedInUser("uid-1", "token-1", "ana@example.com", "Ana"),
    var refreshedToken: String? = null,
    override var currentUid: String? = null,
) : AuthGateway {
    val authEvents = MutableSharedFlow<Boolean>(extraBufferCapacity = 4)
    var signOutCalls = 0
    var refreshCalls = 0

    override val authenticatedChanges: Flow<Boolean> get() = authEvents

    override suspend fun signInWithEmail(email: String, password: String): SignedInUser = user.copy(email = email)
    override suspend fun signUpWithEmail(email: String, password: String): SignedInUser = user.copy(email = email)
    override suspend fun restore(): SignedInUser? = if (currentUid != null) user else null
    override fun googleSignInIntent(activity: Activity, webClientId: String): Intent = throw UnsupportedOperationException()
    override suspend fun finishGoogleSignIn(data: Intent?): SignedInUser = throw UnsupportedOperationException()
    override suspend fun refreshIdToken(): String? {
        refreshCalls++
        return refreshedToken
    }

    override fun signOut() {
        signOutCalls++
    }
}

/**
 * Scripted [MekasaApi]. Every call records itself in [calls]; most routes serve
 * a small fixture. Set [failWith] to make the next inventory call throw.
 */
open class FakeApi : MekasaApi {
    val calls = mutableListOf<String>()
    var failWith: ApiException? = null
    var household: Household? = Household(
        id = "hh-1",
        name = "Test Home",
        ownerUid = "uid-1",
        address = "1 Main St",
        storeIds = listOf("s1"),
    )
    var inventory = mutableListOf(
        InventoryItem(id = "i1", householdId = "hh-1", name = "Milk", quantity = 2, lowStockThreshold = 1, barcode = "111"),
    )
    var shopping = mutableListOf(
        ShoppingItem(id = "s1", householdId = "hh-1", name = "Eggs"),
    )
    var members = mutableListOf(
        HouseholdMember(uid = "uid-1", householdId = "hh-1", name = "Ana", role = "owner"),
    )
    var closed = false

    private fun record(name: String) {
        calls += name
        failWith?.let {
            failWith = null
            throw it
        }
    }

    override suspend fun health(): HealthResponse = HealthResponse("ok")
    override suspend fun me(token: String): UserProfile {
        record("me:$token")
        return UserProfile(uid = "uid-1", email = "ana@example.com", name = "Ana")
    }

    override suspend fun createHousehold(token: String, name: String?): Household {
        record("createHousehold")
        return Household(id = "hh-1", name = name, ownerUid = "uid-1").also { household = it }
    }

    override suspend fun currentHousehold(token: String): Household {
        record("currentHousehold:$token")
        return household ?: throw ApiException(404, "household_not_found")
    }

    override suspend fun updateAddress(token: String, householdId: String, address: String): Household {
        record("updateAddress")
        return household!!.copy(address = address).also { household = it }
    }

    override suspend fun renameHousehold(token: String, householdId: String, name: String?): Household {
        record("renameHousehold")
        return household!!.copy(name = name).also { household = it }
    }

    override suspend fun uploadHouseholdPhoto(token: String, householdId: String, bytes: ByteArray, mimeType: String, filename: String): Household {
        record("uploadPhoto:${bytes.size}")
        return household!!.copy(photoUrl = "https://cdn/photo.jpg").also { household = it }
    }

    override suspend fun nearbyStores(token: String, householdId: String): StoreSearchResponse {
        record("nearbyStores")
        return StoreSearchResponse()
    }

    override suspend fun selectStores(token: String, householdId: String, storeIds: List<String>): Household {
        record("selectStores")
        return household!!.copy(storeIds = storeIds).also { household = it }
    }

    override suspend fun listInventory(token: String, householdId: String): InventoryListResponse {
        record("listInventory:$token")
        return InventoryListResponse(householdId = householdId, items = inventory.toList())
    }

    override suspend fun createInventoryItem(token: String, householdId: String, body: InventoryItemCreateRequest): InventoryItem {
        record("createInventory:${body.name}:${body.source}")
        return InventoryItem(
            id = "i${inventory.size + 1}", householdId = householdId, name = body.name, quantity = body.quantity,
            category = body.category, barcode = body.barcode, source = body.source,
        ).also { inventory.add(it) }
    }

    override suspend fun patchInventoryItem(token: String, householdId: String, itemId: String, patch: InventoryItemPatch): InventoryItem {
        record("patchInventory:$itemId:${patch.quantity}:${patch.lowStockThreshold}")
        val idx = inventory.indexOfFirst { it.id == itemId }
        val updated = inventory[idx].copy(
            quantity = patch.quantity ?: inventory[idx].quantity,
            lowStockThreshold = patch.lowStockThreshold ?: inventory[idx].lowStockThreshold,
        )
        inventory[idx] = updated
        return updated
    }

    override suspend fun refreshInventoryImage(token: String, householdId: String, itemId: String): InventoryItem {
        record("refreshImage:$itemId")
        return inventory.first { it.id == itemId }.copy(imageUrl = "https://cdn/img.jpg")
    }

    override suspend fun consumeInventoryItem(token: String, householdId: String, itemId: String, amount: Int): InventoryItem {
        record("consume:$itemId:$amount")
        val idx = inventory.indexOfFirst { it.id == itemId }
        val updated = inventory[idx].copy(quantity = (inventory[idx].quantity - amount).coerceAtLeast(0))
        inventory[idx] = updated
        return updated
    }

    override suspend fun consumeByBarcode(token: String, householdId: String, barcode: String, amount: Int): ConsumeByBarcodeResult {
        record("consumeByBarcode:$barcode")
        val idx = inventory.indexOfFirst { it.barcode == barcode }
        if (idx < 0) {
            return ConsumeByBarcodeResult(
                found = false,
                unknownEvent = UnknownBarcodeEvent(id = "u1", householdId = householdId, barcode = barcode),
            )
        }
        val updated = inventory[idx].copy(quantity = (inventory[idx].quantity - amount).coerceAtLeast(0))
        inventory[idx] = updated
        return ConsumeByBarcodeResult(found = true, item = updated)
    }

    override suspend fun listUnknownScans(token: String, householdId: String): List<UnknownBarcodeEvent> {
        record("unknownScans")
        return emptyList()
    }

    override suspend fun listShopping(token: String, householdId: String): ShoppingListResponse {
        record("listShopping")
        return ShoppingListResponse(householdId = householdId, items = shopping.toList())
    }

    override suspend fun createShoppingItem(token: String, householdId: String, body: ShoppingItemCreateRequest): ShoppingItem {
        record("createShopping:${body.name}")
        return ShoppingItem(id = "s${shopping.size + 1}", householdId = householdId, name = body.name, quantity = body.quantity)
            .also { shopping.add(it) }
    }

    override suspend fun patchShoppingItem(token: String, householdId: String, itemId: String, patch: ShoppingItemPatch): ShoppingItem {
        record("patchShopping:$itemId:${patch.isChecked}")
        val idx = shopping.indexOfFirst { it.id == itemId }
        val updated = shopping[idx].copy(isChecked = patch.isChecked ?: shopping[idx].isChecked)
        shopping[idx] = updated
        return updated
    }

    override suspend fun deleteShoppingItem(token: String, householdId: String, itemId: String) {
        record("deleteShopping:$itemId")
        shopping.removeAll { it.id == itemId }
    }

    override suspend fun approveShoppingItem(token: String, householdId: String, itemId: String): ShoppingItem {
        record("approveShopping:$itemId")
        return shopping.first { it.id == itemId }.copy(needsApproval = false)
    }

    override suspend fun rejectShoppingItem(token: String, householdId: String, itemId: String): ShoppingItem {
        record("rejectShopping:$itemId")
        return shopping.first { it.id == itemId }
    }

    override suspend fun syncShoppingFromInventory(token: String, householdId: String): ShoppingSyncResponse {
        record("syncShopping")
        return ShoppingSyncResponse(householdId = householdId, items = shopping.toList())
    }

    override suspend fun spending(token: String, householdId: String, period: String): SpendingReport {
        record("spending:$period")
        return SpendingReport(period = period, total = 12.5)
    }

    override suspend fun listMembers(token: String, householdId: String): HouseholdMembersResponse {
        record("listMembers")
        return HouseholdMembersResponse(householdId = householdId, members = members.toList())
    }

    override suspend fun listInvites(token: String, householdId: String): HouseholdInvitesResponse {
        record("listInvites")
        return HouseholdInvitesResponse(householdId = householdId)
    }

    override suspend fun createInvite(token: String, householdId: String, body: InviteCreateRequest): HouseholdInvite {
        record("createInvite:${body.name}:${body.role}")
        return HouseholdInvite(id = "inv1", householdId = householdId, name = body.name, role = body.role, token = "tok-1")
    }

    override suspend fun acceptInvite(token: String, inviteToken: String): HouseholdMember {
        record("acceptInvite:$inviteToken")
        return HouseholdMember(uid = "uid-1", householdId = "hh-1", role = "member")
    }

    override suspend fun updateMemberRole(token: String, householdId: String, memberUid: String, role: String): HouseholdMember {
        record("updateRole:$memberUid:$role")
        return members.first { it.uid == memberUid }.copy(role = role)
    }

    override suspend fun lookupBarcode(token: String, code: String): BarcodeLookup {
        record("lookupBarcode:$code")
        return BarcodeLookup(barcode = code, found = code == "111", name = "Milk".takeIf { code == "111" })
    }

    override suspend fun searchProducts(token: String, query: String, limit: Int): ProductSearchResponse {
        record("search:$query")
        return ProductSearchResponse(query = query)
    }

    override suspend fun scanReceipt(token: String, householdId: String, rawText: String?, imageBase64: String?): ReceiptScanResponse {
        record("scanReceipt")
        return ReceiptScanResponse(householdId = householdId)
    }

    override fun close() {
        closed = true
    }
}
