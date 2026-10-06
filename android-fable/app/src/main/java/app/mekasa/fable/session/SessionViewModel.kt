package app.mekasa.fable.session

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.mekasa.fable.auth.AuthError
import app.mekasa.fable.auth.AuthGateway
import app.mekasa.fable.auth.SignedInUser
import app.mekasa.fable.data.CatalogCapture
import app.mekasa.fable.data.CatalogCode
import app.mekasa.fable.data.HouseholdBackend
import app.mekasa.fable.data.InventoryDraft
import app.mekasa.fable.data.InventoryDuplicates
import app.mekasa.fable.data.LineCapture
import app.mekasa.fable.data.demo.DemoBackend
import app.mekasa.fable.data.model.BarcodeLookup
import app.mekasa.fable.data.model.DuplicateGroup
import app.mekasa.fable.data.model.InventoryItem
import app.mekasa.fable.data.model.InventoryMergeResponse
import app.mekasa.fable.data.model.ProductHit
import app.mekasa.fable.data.model.ReceiptScanResponse
import app.mekasa.fable.data.model.ShoppingItem
import app.mekasa.fable.data.remote.ApiException
import app.mekasa.fable.data.remote.ImageAuth
import app.mekasa.fable.data.remote.MekasaApi
import app.mekasa.fable.data.remote.RemoteBackend
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Single source of truth for auth, onboarding routing, and household data.
 *
 * Transport is hidden behind [HouseholdBackend]: after sign-in a [RemoteBackend]
 * is installed; "Browse UI offline" installs a [DemoBackend]. Every mutation runs
 * through [guarded], which owns error reporting and REQ-022 session expiry (one
 * token refresh + retry on 401, then forced sign-out with a notice).
 */
class SessionViewModel(
    private val api: MekasaApi,
    private val auth: AuthGateway,
    private val emailMemory: EmailMemory = InMemoryEmailMemory(),
    allowTestTokenSignIn: Boolean = false,
    private val demoBackendFactory: () -> HouseholdBackend = { DemoBackend() },
    /** REQ-INV-016 AC3 / REQ-INV-018: how long Undo stays available before the purge. */
    private val undoWindowMillis: Long = UNDO_WINDOW_MILLIS,
) : ViewModel() {

    private val _state = MutableStateFlow(
        SessionState(
            firebaseConfigured = auth.isConfigured,
            allowTestTokenSignIn = allowTestTokenSignIn,
            rememberedEmail = emailMemory.load(),
        ),
    )
    val state: StateFlow<SessionState> = _state.asStateFlow()

    val authGateway: AuthGateway get() = auth

    private var idToken: String? = null
        set(value) {
            field = value
            // REQ-INV-019 AC8: private item photos load with the current token.
            ImageAuth.token = value
        }
    private var backend: HouseholdBackend? = null
    private var authWatcher: Job? = null
    private var purgeJob: Job? = null

    private val current: SessionState get() = _state.value

    init {
        restoreCachedSession()
    }

    // ------------------------------------------------------------- auth

    /** Firebase keeps the user across launches; resume without showing Welcome when possible. */
    private fun restoreCachedSession() {
        if (auth.currentUid == null) return
        viewModelScope.launch {
            val user = runCatching { auth.restore() }.getOrNull() ?: return@launch
            enterSignedIn(user)
        }
    }

    fun signInWithEmail(email: String, password: String, createAccount: Boolean) = guarded(busy = true) {
        val user = if (createAccount) auth.signUpWithEmail(email, password) else auth.signInWithEmail(email, password)
        enterSignedIn(user)
    }

    /** Debug builds only: Cloud Run accepts `test:<uid>` bearers when ALLOW_TEST_AUTH is on. */
    fun signInWithTestToken(email: String) = guarded(busy = true) {
        check(current.allowTestTokenSignIn) { "Test-token sign-in is disabled in this build." }
        val cleaned = email.trim().lowercase()
        val uid = "fable-" + cleaned.hashCode().toUInt().toString(16)
        enterSignedIn(
            SignedInUser(uid = uid, idToken = "test:$uid", email = cleaned, displayName = cleaned.substringBefore('@')),
        )
    }

    /** Called by the Welcome screen once the Google activity result has been exchanged for a Firebase user. */
    fun completeExternalSignIn(user: SignedInUser) = guarded(busy = true) { enterSignedIn(user) }

    fun browseOffline() {
        val demo = demoBackendFactory()
        idToken = null
        backend = demo
        val uid = (demo as? DemoBackend)?.uid ?: DemoBackend.DEMO_UID
        _state.update {
            it.copy(
                stage = Stage.Home,
                isDemo = true,
                account = Account(uid = uid, email = DemoBackend.DEMO_EMAIL, displayName = "Preview"),
                busy = false,
                error = null,
                notice = null,
                kioskMode = false,
            )
        }
        guarded {
            val household = demo.currentHousehold()
            _state.update { it.copy(household = household) }
            reloadAll()
        }
    }

    fun signOut() = endSession(notice = null)

    private fun endSession(notice: String?) {
        authWatcher?.cancel()
        authWatcher = null
        purgeJob?.cancel()
        purgeJob = null
        runCatching { auth.signOut() }
        val remembered = current.account?.email?.takeIf { !current.isDemo } ?: current.rememberedEmail
        emailMemory.save(remembered)
        idToken = null
        backend = null
        _state.value = SessionState(
            firebaseConfigured = auth.isConfigured,
            allowTestTokenSignIn = current.allowTestTokenSignIn,
            rememberedEmail = remembered,
            pendingInviteToken = current.pendingInviteToken,
            notice = notice,
        )
    }

    private suspend fun enterSignedIn(user: SignedInUser) {
        idToken = user.idToken
        val remote = RemoteBackend(api) { idToken ?: user.idToken }
        backend = remote

        val profile = runCatching { remote.profile() }.getOrNull()
        val household = remote.currentHousehold()
        val account = Account(
            uid = profile?.uid ?: user.uid,
            email = profile?.email ?: user.email,
            displayName = profile?.name ?: user.displayName,
        )
        emailMemory.save(account.email)
        _state.update {
            it.copy(
                stage = Stage.forHousehold(household),
                account = account,
                household = household,
                isDemo = false,
                rememberedEmail = account.email ?: it.rememberedEmail,
                notice = null,
                error = null,
                busy = false,
                data = HouseholdData(),
            )
        }
        watchFirebaseAuthState()
        if (current.stage == Stage.Home) reloadAll()
        acceptPendingInviteIfPossible()
    }

    /** REQ-022 AC4: Firebase dropping the user mid-session returns us to Welcome. */
    private fun watchFirebaseAuthState() {
        authWatcher?.cancel()
        if (!auth.isConfigured) return
        authWatcher = viewModelScope.launch {
            auth.authenticatedChanges.collect { authenticated ->
                if (!authenticated && current.isSignedIn && !current.isDemo) {
                    endSession(notice = SESSION_EXPIRED)
                }
            }
        }
    }

    // ------------------------------------------------------- onboarding

    fun createHousehold(name: String) = guarded(busy = true) {
        val household = require().createHousehold(name.trim().ifBlank { null })
        _state.update { it.copy(household = household, stage = Stage.ConfirmAddress) }
    }

    fun saveAddress(address: String) = guarded(busy = true) {
        val backend = require()
        val id = householdId()
        val household = backend.updateAddress(id, address.trim())
        val stores = runCatching { backend.nearbyStores(id) }.getOrDefault(emptyList())
        _state.update {
            it.copy(
                household = household,
                nearbyStores = stores,
                selectedStoreIds = stores.take(2).map { s -> s.id }.toSet(),
                stage = Stage.PickStores,
            )
        }
    }

    fun toggleStore(storeId: String) = _state.update {
        val next = it.selectedStoreIds.toMutableSet()
        if (!next.add(storeId)) next.remove(storeId)
        it.copy(selectedStoreIds = next)
    }

    fun finishStoreSelection() = guarded(busy = true) {
        val ids = current.selectedStoreIds.toList()
        val household = if (ids.isEmpty()) current.household else require().selectStores(householdId(), ids)
        _state.update { it.copy(household = household, stage = Stage.Home) }
        reloadAll()
    }

    // ------------------------------------------------------ household data

    fun refreshAll() = guarded { reloadAll() }

    private suspend fun reloadAll() {
        val backend = require()
        val id = householdId()
        val inventory = backend.inventory(id)
        val shopping = backend.shoppingList(id)
        val spending = runCatching { backend.spending(id, current.data.spendingPeriod) }.getOrNull()
        val members = runCatching { backend.members(id) }.getOrDefault(emptyList())
        val invites = runCatching { backend.invites(id) }.getOrDefault(emptyList())
        _state.update {
            it.copy(
                data = it.data.copy(
                    inventory = inventory,
                    shopping = shopping,
                    spending = spending ?: it.data.spending,
                    members = members,
                    invites = invites,
                ),
            )
        }
    }

    fun refreshFamily() = guarded {
        val backend = require()
        val id = householdId()
        val members = backend.members(id)
        val invites = backend.invites(id)
        _state.update { it.copy(data = it.data.copy(members = members, invites = invites)) }
    }

    fun selectSpendingPeriod(period: String) {
        _state.update { it.copy(data = it.data.copy(spendingPeriod = period)) }
        guarded {
            val report = require().spending(householdId(), period)
            _state.update { it.copy(data = it.data.copy(spending = report)) }
        }
    }

    // -------------------------------------------------------- home photo

    /**
     * REQ-002: rename and/or replace the hero photo. Only the owner may upload;
     * the check happens client-side too so members see a clear message rather than a 403.
     */
    fun saveHomeDetails(
        name: String?,
        jpeg: ByteArray?,
        onDone: (Boolean) -> Unit = {},
    ) {
        val nameChanged = name != null && name.trim() != current.household?.name.orEmpty().trim()
        if (!nameChanged && jpeg == null) {
            onDone(true)
            return
        }
        if (!current.isOwner) {
            fail(OWNER_ONLY_PHOTO)
            onDone(false)
            return
        }
        guarded(busy = true, onFailure = { onDone(false) }) {
            val backend = require()
            val id = householdId()
            var household = current.household
            if (nameChanged) {
                household = backend.renameHousehold(id, name?.trim()?.ifBlank { null })
            }
            if (jpeg != null) {
                when {
                    jpeg.isEmpty() -> throw IllegalStateException("The photo was empty.")
                    jpeg.size > MAX_PHOTO_BYTES -> throw IllegalStateException("Photo is too large (max 5 MB).")
                }
                household = backend.uploadHomePhoto(id, jpeg)
            }
            _state.update { it.copy(household = household) }
            onDone(true)
        }
    }

    // ----------------------------------------------------------- inventory

    suspend fun lookupBarcode(code: String): BarcodeLookup = require().lookupBarcode(code.trim())

    suspend fun searchProducts(query: String): List<ProductHit> = require().searchProducts(query)

    fun addInventory(draft: InventoryDraft, onDone: () -> Unit = {}) = addInventory(listOf(draft), onDone)

    fun addInventory(drafts: List<InventoryDraft>, onDone: () -> Unit = {}) {
        if (drafts.isEmpty()) {
            onDone()
            return
        }
        guarded(busy = true) {
            val backend = require()
            val id = householdId()
            var captureFailed: String? = null
            for (draft in drafts) {
                var created = backend.addInventory(id, draft)
                draft.capture?.let { capture ->
                    try {
                        created = sendCapture(backend, id, created, capture)
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: Exception) {
                        if (e is ApiException && e.isUnauthorized) throw e
                        captureFailed = "Saved ${created.name}, but couldn't add it to the shared catalog."
                    }
                }
                _state.update { it.copy(data = it.data.copy(inventory = it.data.inventory.upsert(created))) }
            }
            captureFailed?.let(::fail)
            onDone()
        }
    }

    /**
     * REQ-RCP-020 AC6, AC15: upload the photo to the shared product photos when the
     * capture shares it (a code, or receipt text with no code), then link the item.
     */
    private suspend fun sendCapture(
        backend: HouseholdBackend,
        householdId: String,
        item: InventoryItem,
        capture: LineCapture,
    ): InventoryItem {
        val photoId = capture.photoJpeg
            ?.takeIf { capture.sharesPhoto && it.isNotEmpty() && it.size <= MAX_PHOTO_BYTES }
            ?.let { backend.uploadProductPhoto(householdId, it).photoId }
        val request = CatalogCapture.request(capture, photoId) ?: return item
        return backend.captureProduct(householdId, item.id, request)
    }

    /**
     * REQ-RCP-020 AC15: add a barcode or PLU to a saved item that has none. A UPC
     * then refreshes the health grade (REQ-021 AC4). [onDone] gets an error to show
     * inline, or null on success.
     */
    fun addCode(itemId: String, raw: String, onDone: (String?) -> Unit) {
        val code = CatalogCode.parse(raw) ?: run {
            onDone(CatalogCapture.errorMessage(if (raw.trim().length in 4..5) "invalid_plu" else "invalid_upc"))
            return
        }
        viewModelScope.launch {
            try {
                val backend = require()
                val id = householdId()
                var updated = backend.captureProduct(id, itemId, CatalogCapture.codeRequest(code))
                if (code is CatalogCode.Upc) {
                    updated = runCatching { backend.refreshHealth(id, itemId) }.getOrDefault(updated)
                }
                replaceInventory(updated)
                onDone(null)
            } catch (e: CancellationException) {
                throw e
            } catch (e: ApiException) {
                if (e.isUnauthorized && !current.isDemo) {
                    endSession(notice = SESSION_EXPIRED)
                    onDone(null)
                } else {
                    onDone(CatalogCapture.errorMessage(e.detail))
                }
            } catch (e: Exception) {
                onDone(CatalogCapture.errorMessage(null))
            }
        }
    }

    fun updateInventory(itemId: String, quantity: Int? = null, threshold: Int? = null) = guarded {
        val updated = require().updateInventory(householdId(), itemId, quantity, threshold)
        replaceInventory(updated)
    }

    fun consume(itemId: String, amount: Int = 1) = guarded {
        val before = current.data.inventory.firstOrNull { it.id == itemId }
        if (before != null && before.quantity <= 0) return@guarded
        val updated = require().consume(householdId(), itemId, amount)
        replaceInventory(updated)
        logScan(updated, amount)
    }

    fun refreshItemImage(itemId: String) = guarded {
        val updated = require().refreshImage(householdId(), itemId)
        replaceInventory(updated)
    }

    /**
     * REQ-INV-019: replace an item's picture with the member's own photo. Any member may
     * do this; the photo stays private to the household.
     */
    fun replaceItemPhoto(itemId: String, jpeg: ByteArray, onDone: (Boolean) -> Unit = {}) {
        when {
            jpeg.isEmpty() -> { fail("The photo was empty."); onDone(false); return }
            jpeg.size > MAX_PHOTO_BYTES -> { fail("Photo is too large (max 5 MB)."); onDone(false); return }
        }
        guarded(busy = true, onFailure = { onDone(false) }) {
            val updated = require().replaceItemPhoto(householdId(), itemId, jpeg)
            replaceInventory(updated)
            onDone(true)
        }
    }

    /**
     * REQ-INV-015/016: Remove hides the row at once, soft-deletes it server-side and starts
     * the undo window. Only one removal is undoable at a time; starting another purges the
     * previous one immediately.
     */
    fun removeInventoryItem(itemId: String) {
        val inventory = current.data.inventory
        val index = inventory.indexOfFirst { it.id == itemId }
        if (index < 0) return
        val item = inventory[index]

        purgeJob?.cancel()
        current.pendingRemoval?.let { previous -> guarded { require().purgeInventory(householdId(), previous.item.id) } }

        _state.update {
            it.copy(
                data = it.data.copy(inventory = it.data.inventory.filterNot { row -> row.id == itemId }),
                pendingRemoval = PendingRemoval(item, index),
            )
        }
        guarded(onFailure = { cancelRemoval(item, index) }) {
            require().softDeleteInventory(householdId(), itemId)
        }
        purgeJob = viewModelScope.launch {
            delay(undoWindowMillis)
            if (current.pendingRemoval?.item?.id != itemId) return@launch
            _state.update { it.copy(pendingRemoval = null) }
            guarded { require().purgeInventory(householdId(), itemId) }
        }
    }

    /** REQ-INV-017: Undo within the window restores the item at its original position. */
    fun undoInventoryRemove() {
        val pending = current.pendingRemoval ?: return
        purgeJob?.cancel()
        purgeJob = null
        cancelRemoval(pending.item, pending.index)
        guarded {
            val restored = require().restoreInventory(householdId(), pending.item.id)
            replaceInventory(restored)
        }
    }

    private fun cancelRemoval(item: InventoryItem, index: Int) = _state.update {
        val rows = it.data.inventory
        val restored = if (rows.any { row -> row.id == item.id }) {
            rows
        } else {
            rows.toMutableList().apply { add(index.coerceIn(0, size), item) }
        }
        it.copy(data = it.data.copy(inventory = restored), pendingRemoval = null)
    }

    /** REQ-INV-021 AC1: the API's duplicate groups (the demo backend runs the same rules locally). */
    fun findDuplicates(onDone: (DuplicatesOutcome) -> Unit) {
        viewModelScope.launch {
            try {
                onDone(DuplicatesOutcome(require().inventoryDuplicates(householdId()), null))
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                if (e is ApiException && e.isUnauthorized && !current.isDemo) {
                    endSession(notice = SESSION_EXPIRED)
                    onDone(DuplicatesOutcome(null, null))
                } else {
                    onDone(DuplicatesOutcome(null, DUPLICATES_FAILED))
                }
            }
        }
    }

    /**
     * REQ-INV-021 AC3, AC6: merges each group in turn and updates inventory and the shopping
     * list from each response, so no reload is needed. A group that fails is left for review.
     */
    fun mergeDuplicates(groups: List<DuplicateGroup>, onDone: (MergeOutcome) -> Unit) {
        viewModelScope.launch {
            val merged = mutableListOf<DuplicateGroup>()
            var error: String? = null
            for (group in groups) {
                try {
                    applyMerge(require().mergeInventory(householdId(), group.items.map { it.id }))
                    merged += group
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    if (e is ApiException && e.isUnauthorized && !current.isDemo) {
                        endSession(notice = SESSION_EXPIRED)
                        onDone(MergeOutcome(merged, null, null))
                        return@launch
                    }
                    error = if (e is ApiException && e.status in setOf(404, 409)) DUPLICATES_CHANGED else MERGE_FAILED
                }
            }
            onDone(MergeOutcome(merged, InventoryDuplicates.bulkConfirmation(merged), error))
        }
    }

    private fun applyMerge(response: InventoryMergeResponse) = _state.update {
        val survivor = response.item
        val removed = response.removedIds.toSet()
        val rows = it.data.inventory
        val position = rows.indexOfFirst { row -> row.id == survivor.id || row.id in removed }.coerceAtLeast(0)
        val inventory = rows.filterNot { row -> row.id == survivor.id || row.id in removed }.toMutableList()
        inventory.add(position.coerceAtMost(inventory.size), survivor)
        val updatedRows = response.shoppingListItems.associateBy { row -> row.id }
        val shopping = it.data.shopping.map { row ->
            updatedRows[row.id] ?: if (row.inventoryItemId in removed) row.copy(inventoryItemId = survivor.id) else row
        }
        it.copy(data = it.data.copy(inventory = inventory, shopping = shopping))
    }

    fun consumeByBarcode(barcode: String, amount: Int = 1, onResult: (ConsumeOutcome) -> Unit = {}) {
        val code = barcode.trim()
        if (code.isEmpty()) {
            onResult(ConsumeOutcome.Failed("No barcode"))
            return
        }
        guarded(onFailure = { onResult(ConsumeOutcome.Failed(it)) }) {
            val result = require().consumeByBarcode(householdId(), code, amount)
            val item = result.item
            if (!result.found || item == null) {
                result.unknownEvent?.let { event ->
                    _state.update {
                        it.copy(data = it.data.copy(unknownScans = listOf(event) + it.data.unknownScans.filter { e -> e.id != event.id }))
                    }
                }
                pushScanEvent("Unknown barcode $code", ScanEvent.Tone.Unknown)
                onResult(ConsumeOutcome.Unknown(code))
            } else {
                replaceInventory(item)
                logScan(item, amount)
                onResult(if (item.quantity <= 0) ConsumeOutcome.Depleted(item) else ConsumeOutcome.Used(item))
            }
        }
    }

    fun refreshUnknownScans() = guarded(swallowForbidden = true) {
        val events = require().unknownScans(householdId())
        _state.update { it.copy(data = it.data.copy(unknownScans = events)) }
    }

    fun setKioskMode(enabled: Boolean) {
        _state.update { it.copy(kioskMode = enabled) }
        if (enabled) refreshUnknownScans()
    }

    private fun replaceInventory(updated: InventoryItem) = _state.update {
        it.copy(data = it.data.copy(inventory = it.data.inventory.upsert(updated)))
    }

    private fun logScan(item: InventoryItem, amount: Int) {
        val tone = if (item.quantity <= 0) ScanEvent.Tone.Depleted else ScanEvent.Tone.Used
        pushScanEvent("${item.name} −$amount · ${item.quantity} left", tone)
    }

    private fun pushScanEvent(message: String, tone: ScanEvent.Tone) = _state.update {
        val event = ScanEvent(id = "scan-${System.nanoTime()}", message = message, tone = tone)
        it.copy(data = it.data.copy(scanFeed = (listOf(event) + it.data.scanFeed).take(SCAN_FEED_LIMIT)))
    }

    // ------------------------------------------------------- shopping list

    fun addShoppingItem(name: String, quantity: Int = 1) {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return
        guarded(busy = true) {
            val created = require().addShoppingItem(householdId(), trimmed, quantity.coerceAtLeast(1))
            _state.update { it.copy(data = it.data.copy(shopping = listOf(created) + it.data.shopping)) }
        }
    }

    /** REQ-014: checking (marking purchased) is gated; un-checking is always allowed. */
    fun toggleShoppingPurchased(itemId: String) {
        val item = current.data.shopping.firstOrNull { it.id == itemId } ?: return
        val next = !item.isChecked
        if (next && !current.canMarkPurchased) {
            fail(OWNER_ONLY_PURCHASE)
            return
        }
        guarded {
            val updated = require().setShoppingChecked(householdId(), itemId, next)
            replaceShopping(updated)
        }
    }

    fun removeShoppingItem(itemId: String) = guarded {
        require().deleteShoppingItem(householdId(), itemId)
        _state.update { it.copy(data = it.data.copy(shopping = it.data.shopping.filterNot { s -> s.id == itemId })) }
    }

    fun approveShoppingItem(itemId: String) = guarded {
        val updated = require().approveShoppingItem(householdId(), itemId)
        replaceShopping(updated)
    }

    fun rejectShoppingItem(itemId: String) = guarded {
        require().rejectShoppingItem(householdId(), itemId)
        _state.update { it.copy(data = it.data.copy(shopping = it.data.shopping.filterNot { s -> s.id == itemId })) }
    }

    fun syncShoppingFromInventory() = guarded(busy = true) {
        val items = require().syncShoppingFromInventory(householdId())
        _state.update { it.copy(data = it.data.copy(shopping = items)) }
    }

    private fun replaceShopping(updated: ShoppingItem) = _state.update {
        it.copy(data = it.data.copy(shopping = it.data.shopping.map { s -> if (s.id == updated.id) updated else s }))
    }

    // ------------------------------------------------------------- family

    fun createInvite(name: String, email: String?, role: String = "member") {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return
        guarded(busy = true) {
            val invite = require().createInvite(householdId(), trimmed, email?.trim()?.ifBlank { null }, role)
            _state.update { it.copy(data = it.data.copy(invites = listOf(invite) + it.data.invites)) }
        }
    }

    fun promoteToOwner(memberUid: String) = guarded {
        val updated = require().updateMemberRole(householdId(), memberUid, "owner")
        _state.update {
            it.copy(data = it.data.copy(members = it.data.members.map { m -> if (m.uid == updated.uid) updated else m }))
        }
    }

    fun onInviteLink(link: String?) {
        val token = InviteLink.tokenFrom(link) ?: return
        _state.update { it.copy(pendingInviteToken = token) }
        acceptPendingInviteIfPossible()
    }

    fun acceptPendingInviteIfPossible() {
        val token = current.pendingInviteToken ?: return
        if (!current.isSignedIn || current.isDemo) return
        guarded(busy = true) {
            val backend = require()
            backend.acceptInvite(token)
            _state.update { it.copy(pendingInviteToken = null) }
            val household = backend.currentHousehold()
            _state.update { it.copy(household = household, stage = Stage.forHousehold(household)) }
            if (current.stage == Stage.Home) reloadAll()
        }
    }

    // ------------------------------------------------------------ receipts

    fun scanReceipt(rawText: String? = null, imageBase64: String? = null, onResult: (ReceiptScanResponse) -> Unit) =
        guarded(busy = true) {
            onResult(require().scanReceipt(householdId(), rawText, imageBase64))
        }

    // ------------------------------------------------------------ feedback

    fun dismissError() = _state.update { it.copy(error = null) }

    fun dismissNotice() = _state.update { it.copy(notice = null) }

    fun fail(message: String?) = _state.update { it.copy(busy = false, error = message) }

    // ------------------------------------------------------------ plumbing

    private fun require(): HouseholdBackend = backend ?: throw IllegalStateException("Not signed in")

    private fun householdId(): String = current.household?.id ?: throw IllegalStateException("No household yet")

    /**
     * Runs [block] on the ViewModel scope with unified error handling.
     * A 401 triggers one forced token refresh + retry; a second failure ends the session (REQ-022).
     */
    private fun guarded(
        busy: Boolean = false,
        swallowForbidden: Boolean = false,
        onFailure: (String) -> Unit = {},
        block: suspend () -> Unit,
    ): Job = viewModelScope.launch {
        if (busy) _state.update { it.copy(busy = true, error = null) }
        try {
            try {
                block()
            } catch (e: ApiException) {
                if (!e.isUnauthorized || current.isDemo) throw e
                val refreshed = auth.refreshIdToken()
                if (refreshed == null || refreshed == idToken) throw e
                idToken = refreshed
                block()
            }
            if (busy) _state.update { it.copy(busy = false) }
        } catch (e: CancellationException) {
            throw e
        } catch (e: ApiException) {
            when {
                e.isUnauthorized && !current.isDemo -> endSession(notice = SESSION_EXPIRED)
                e.isForbidden && swallowForbidden -> _state.update { it.copy(busy = false) }
                else -> {
                    fail(e.userMessage)
                    onFailure(e.userMessage)
                }
            }
        } catch (e: AuthError.Cancelled) {
            _state.update { it.copy(busy = false) }
        } catch (e: Exception) {
            val message = e.message?.takeIf { it.isNotBlank() } ?: "Something went wrong"
            fail(message)
            onFailure(message)
        }
    }

    override fun onCleared() {
        api.close()
        super.onCleared()
    }

    companion object {
        const val SESSION_EXPIRED = "Your session expired. Please sign in again."
        const val OWNER_ONLY_PURCHASE = "Only household owners can mark items as purchased."
        const val OWNER_ONLY_PHOTO = "Only the household owner can change the home name or photo."
        const val DUPLICATES_FAILED = "Couldn’t check for duplicates. Try again."
        const val DUPLICATES_CHANGED = "Those items changed. Check for duplicates again."
        const val MERGE_FAILED = "Couldn’t merge those items. Try again."
        private const val MAX_PHOTO_BYTES = 5_000_000
        private const val SCAN_FEED_LIMIT = 20
        const val UNDO_WINDOW_MILLIS = 5_000L
    }
}

private fun List<InventoryItem>.upsert(item: InventoryItem): List<InventoryItem> =
    if (any { it.id == item.id }) map { if (it.id == item.id) item else it } else listOf(item) + this
