package app.mekasa.fable.support

import android.app.Activity
import android.content.Intent
import app.mekasa.fable.auth.AuthGateway
import app.mekasa.fable.auth.SignedInUser
import app.mekasa.fable.data.InventoryDuplicates
import app.mekasa.fable.data.model.BarcodeLookup
import app.mekasa.fable.data.model.ConsumeByBarcodeResult
import app.mekasa.fable.data.model.HealthResponse
import app.mekasa.fable.data.model.Household
import app.mekasa.fable.data.model.HouseholdInvite
import app.mekasa.fable.data.model.HouseholdInvitesResponse
import app.mekasa.fable.data.model.HouseholdMember
import app.mekasa.fable.data.model.HouseholdMembersResponse
import app.mekasa.fable.data.model.InventoryDuplicatesResponse
import app.mekasa.fable.data.model.InventoryItem
import app.mekasa.fable.data.model.InventoryItemCreateRequest
import app.mekasa.fable.data.model.InventoryItemPatch
import app.mekasa.fable.data.model.InventoryListResponse
import app.mekasa.fable.data.model.InventoryMergeRequest
import app.mekasa.fable.data.model.InventoryMergeResponse
import app.mekasa.fable.data.model.InviteCreateRequest
import app.mekasa.fable.data.model.ItemPhotoUpload
import app.mekasa.fable.data.model.ProductCaptureRequest
import app.mekasa.fable.data.model.ProductCaptureResponse
import app.mekasa.fable.data.model.ProductPhotoUpload
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
import app.mekasa.fable.data.remote.CorrelationId
import app.mekasa.fable.data.remote.MekasaApi
import app.mekasa.fable.diagnostics.ClientDiagnosticsResponse
import app.mekasa.fable.diagnostics.ClientDiagnosticsUpload
import app.mekasa.fable.diagnostics.ClientErrorBatch
import app.mekasa.fable.diagnostics.ClientErrorBatchResponse
import kotlinx.coroutines.currentCoroutineContext
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
    /** The receipt flow each call ran in, in call order (NFR-006 AC7). */
    val correlations = mutableListOf<Pair<String, String?>>()

    private suspend fun record(name: String) {
        calls += name
        correlations += name to currentCoroutineContext()[CorrelationId]?.value
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
            imageUrl = patch.imageUrl ?: inventory[idx].imageUrl,
        )
        inventory[idx] = updated
        return updated
    }

    override suspend fun uploadItemPhoto(token: String, householdId: String, bytes: ByteArray, mimeType: String, filename: String): ItemPhotoUpload {
        record("uploadItemPhoto:${bytes.size}")
        val id = "0b5c7e4e-7f3e-4d0c-9c1e-6d2b8a9f1c22"
        return ItemPhotoUpload(photoId = id, url = "https://api.test/v1/households/$householdId/item-photos/$id")
    }

    override suspend fun refreshInventoryImage(token: String, householdId: String, itemId: String): InventoryItem {
        record("refreshImage:$itemId")
        return inventory.first { it.id == itemId }.copy(imageUrl = "https://cdn/img.jpg")
    }

    override suspend fun refreshInventoryHealth(token: String, householdId: String, itemId: String): InventoryItem {
        record("refreshHealth:$itemId")
        return inventory.first { it.id == itemId }
    }

    val captures = mutableListOf<ProductCaptureRequest>()

    override suspend fun uploadProductPhoto(token: String, householdId: String, bytes: ByteArray): ProductPhotoUpload {
        record("uploadProductPhoto:${bytes.size}")
        val id = "7a2b3c4d-1111-4c5d-9e7f-0a1b2c3d4e5f"
        return ProductPhotoUpload(photoId = id, imageUrl = "/v1/product-photos/$id")
    }

    override suspend fun captureInventoryItem(
        token: String,
        householdId: String,
        itemId: String,
        body: ProductCaptureRequest,
    ): ProductCaptureResponse {
        record("capture:$itemId")
        captures += body
        val idx = inventory.indexOfFirst { it.id == itemId }
        val productId = body.upc ?: body.pluCode?.let { "plu:$it" } ?: "llm:${"a".repeat(40)}"
        val updated = inventory[idx].copy(
            barcode = body.upc ?: inventory[idx].barcode,
            productId = productId,
            imageUrl = body.photoId?.let { "/v1/product-photos/$it" } ?: inventory[idx].imageUrl,
        )
        inventory[idx] = updated
        return ProductCaptureResponse(outcome = "created", inventoryItem = updated)
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

    override suspend fun deleteInventoryItem(token: String, householdId: String, itemId: String) {
        record("deleteInventory:$itemId")
        val idx = inventory.indexOfFirst { it.id == itemId }
        inventory[idx] = inventory[idx].copy(deleted = true)
    }

    override suspend fun restoreInventoryItem(token: String, householdId: String, itemId: String): InventoryItem {
        record("restoreInventory:$itemId")
        val idx = inventory.indexOfFirst { it.id == itemId }
        return inventory[idx].copy(deleted = false).also { inventory[idx] = it }
    }

    override suspend fun purgeInventoryItem(token: String, householdId: String, itemId: String) {
        record("purgeInventory:$itemId")
        inventory.removeAll { it.id == itemId }
    }

    override suspend fun listInventoryDuplicates(token: String, householdId: String): InventoryDuplicatesResponse {
        record("listDuplicates")
        return InventoryDuplicatesResponse(householdId, InventoryDuplicates.findGroups(inventory.filterNot { it.deleted }))
    }

    override suspend fun mergeInventory(token: String, householdId: String, body: InventoryMergeRequest): InventoryMergeResponse {
        record("mergeInventory:${body.itemIds.joinToString(",")}")
        val selected = body.itemIds.map { id -> inventory.firstOrNull { it.id == id } ?: throw ApiException(404, "not_found") }
        val group = InventoryDuplicates.findGroups(selected).singleOrNull() ?: throw ApiException(409, "not_duplicates")
        val survivor = InventoryDuplicates.merged(group)!!
        val removed = group.others.map { it.id }
        inventory.replaceAll { if (it.id == survivor.id) survivor else it }
        inventory.removeAll { it.id in removed }
        val relinked = shopping.filter { it.inventoryItemId in removed }.map { it.copy(inventoryItemId = survivor.id) }
        shopping.replaceAll { row -> relinked.firstOrNull { it.id == row.id } ?: row }
        return InventoryMergeResponse(householdId, survivor, removed, relinked)
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

    val errorBatches = mutableListOf<ClientErrorBatch>()
    val diagnosticsUploads = mutableListOf<ClientDiagnosticsUpload>()

    override suspend fun reportClientErrors(token: String, batch: ClientErrorBatch): ClientErrorBatchResponse {
        record("reportClientErrors")
        errorBatches += batch
        return ClientErrorBatchResponse(accepted = batch.reports.size)
    }

    override suspend fun uploadDiagnostics(token: String, upload: ClientDiagnosticsUpload): ClientDiagnosticsResponse {
        record("uploadDiagnostics")
        diagnosticsUploads += upload
        return ClientDiagnosticsResponse(diagnosticsId = "3f9a12c7deadbeef", reference = "3F9A12C7", entries = upload.entries.size)
    }

    override fun close() {
        closed = true
    }
}
