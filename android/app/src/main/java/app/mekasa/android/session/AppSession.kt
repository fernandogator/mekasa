package app.mekasa.android.session

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.mekasa.android.auth.AuthException
import app.mekasa.android.auth.AuthResult
import app.mekasa.android.auth.AuthService
import app.mekasa.android.data.BarcodeLookupResponse
import app.mekasa.android.data.Household
import app.mekasa.android.data.HouseholdInviteAcceptRequest
import app.mekasa.android.data.HouseholdInviteCreateRequest
import app.mekasa.android.data.HouseholdInviteDto
import app.mekasa.android.data.HouseholdMemberDto
import app.mekasa.android.data.InventoryItemCreateRequest
import app.mekasa.android.data.InventoryItemDto
import app.mekasa.android.data.MekasaApiClient
import app.mekasa.android.data.MekasaApiException
import app.mekasa.android.data.ProductSearchHit
import app.mekasa.android.data.ShoppingListItemCreateRequest
import app.mekasa.android.data.ShoppingListItemDto
import app.mekasa.android.data.ShoppingListItemUpdateRequest
import app.mekasa.android.data.SpendingCategoryDto
import app.mekasa.android.data.SpendingReportDto
import app.mekasa.android.data.Store
import app.mekasa.android.data.UnknownBarcodeEventDto
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

enum class OnboardingStep {
    Welcome,
    Household,
    Address,
    Stores,
    Done,
}

data class PendingInventoryDraft(
    val name: String,
    val category: String = "Other",
    val quantity: Int = 1,
    val barcode: String? = null,
    val imageUrl: String? = null,
    val source: String = "manual",
    val pricePaid: Double? = null,
)

data class TrashEvent(
    val id: String,
    val message: String,
    val isUnknown: Boolean = false,
)

sealed class ConsumeResult {
    data class Decremented(val item: InventoryItemDto) : ConsumeResult()
    data class Depleted(val item: InventoryItemDto) : ConsumeResult()
    data class Unknown(val barcode: String) : ConsumeResult()
    data class Failed(val message: String) : ConsumeResult()
}

data class AppUiState(
    val step: OnboardingStep = OnboardingStep.Welcome,
    val idToken: String? = null,
    val email: String? = null,
    val displayName: String? = null,
    val userUid: String? = null,
    val household: Household? = null,
    val inventory: List<InventoryItemDto> = emptyList(),
    val shoppingList: List<ShoppingListItemDto> = emptyList(),
    val spending: SpendingReportDto? = null,
    val spendingPeriod: String = "week",
    val members: List<HouseholdMemberDto> = emptyList(),
    val invites: List<HouseholdInviteDto> = emptyList(),
    val pendingInviteToken: String? = null,
    val isTrashKioskMode: Boolean = false,
    val trashEvents: List<TrashEvent> = emptyList(),
    val unknownTrashScans: List<UnknownBarcodeEventDto> = emptyList(),
    val nearbyStores: List<Store> = emptyList(),
    val selectedStoreIds: Set<String> = emptySet(),
    val isBusy: Boolean = false,
    val lastError: String? = null,
    val isOfflinePreview: Boolean = false,
    val lastSignedInEmail: String? = null,
    val firebaseConfigured: Boolean = false,
)

class AppSession(
    private val api: MekasaApiClient = MekasaApiClient(),
    private val auth: AuthService = AuthService(),
) : ViewModel() {
    private val _state = MutableStateFlow(
        AppUiState(firebaseConfigured = auth.isFirebaseConfigured),
    )
    val state: StateFlow<AppUiState> = _state.asStateFlow()

    val authService: AuthService get() = auth

    fun clearError() = _state.update { it.copy(lastError = null) }

    fun reportError(message: String?) {
        _state.update { it.copy(isBusy = false, lastError = message) }
    }

    fun startOfflinePreview() {
        _state.update {
            it.copy(
                isOfflinePreview = true,
                idToken = "preview",
                email = "preview@mekasa.local",
                displayName = "Preview",
                userUid = "preview-user",
                household = Household(
                    id = "preview-home",
                    name = "The Guerrero Home",
                    ownerUid = "preview-user",
                    address = "123 Peachtree St, Atlanta, GA",
                    storeIds = listOf("publix-stub", "kroger-stub"),
                ),
                inventory = listOf(
                    InventoryItemDto(
                        id = "1",
                        householdId = "preview-home",
                        name = "Diet Coke",
                        category = "Beverages",
                        quantity = 2,
                        lowStockThreshold = 3,
                        barcode = "049000028911",
                        imageUrl = "https://images.openfoodfacts.org/images/products/004/900/002/8911/front_en.jpg",
                    ),
                    InventoryItemDto(
                        id = "2",
                        householdId = "preview-home",
                        name = "Whole Milk",
                        category = "Dairy",
                        quantity = 1,
                        lowStockThreshold = 2,
                    ),
                    InventoryItemDto(
                        id = "3",
                        householdId = "preview-home",
                        name = "Sourdough Bread",
                        category = "Pantry",
                        quantity = 4,
                        lowStockThreshold = 1,
                    ),
                ),
                shoppingList = listOf(
                    ShoppingListItemDto(
                        id = "s1",
                        householdId = "preview-home",
                        name = "Diet Coke",
                        quantity = 1,
                        needsApproval = false,
                        kind = "auto",
                    ),
                    ShoppingListItemDto(
                        id = "s2",
                        householdId = "preview-home",
                        name = "Avocados",
                        quantity = 3,
                        needsApproval = true,
                        requestedBy = "kid",
                        kind = "request",
                    ),
                ),
                spending = SpendingReportDto(
                    period = "week",
                    total = 86.42,
                    byCategory = listOf(
                        SpendingCategoryDto("Groceries", 54.10),
                        SpendingCategoryDto("Beverages", 18.20),
                        SpendingCategoryDto("Household", 14.12),
                    ),
                ),
                members = listOf(
                    HouseholdMemberDto(
                        uid = "preview-user",
                        householdId = "preview-home",
                        name = "Preview",
                        email = "preview@mekasa.local",
                        role = "owner",
                    ),
                ),
                invites = emptyList(),
                spendingPeriod = "week",
                step = OnboardingStep.Done,
                lastError = null,
            )
        }
    }

    fun applyAuth(result: AuthResult) {
        viewModelScope.launch {
            _state.update { it.copy(isBusy = true, lastError = null) }
            try {
                resumeAfterAuth(
                    token = result.token,
                    email = result.email,
                    displayName = result.displayName,
                    uid = result.uid,
                )
            } catch (e: Exception) {
                handleFailure(e)
            }
        }
    }

    fun signInWithEmail(email: String, password: String, isSignUp: Boolean) {
        viewModelScope.launch {
            _state.update { it.copy(isBusy = true, lastError = null) }
            try {
                val result = if (isSignUp) {
                    auth.signUp(email, password)
                } else {
                    auth.signIn(email, password)
                }
                resumeAfterAuth(
                    token = result.token,
                    email = result.email ?: email,
                    displayName = result.displayName,
                    uid = result.uid,
                )
            } catch (e: Exception) {
                handleFailure(e)
            }
        }
    }

    /**
     * Dev fallback when Firebase is not configured and Cloud Run allows test auth.
     */
    fun signInWithTestToken(email: String, uid: String = "android-${email.hashCode()}") {
        viewModelScope.launch {
            _state.update { it.copy(isBusy = true, lastError = null) }
            try {
                resumeAfterAuth(
                    token = "test:$uid",
                    email = email,
                    displayName = email.substringBefore("@"),
                    uid = uid,
                )
            } catch (e: Exception) {
                handleFailure(e)
            }
        }
    }

    fun signOut() {
        auth.signOut()
        val email = _state.value.email ?: _state.value.lastSignedInEmail
        val pending = _state.value.pendingInviteToken
        _state.value = AppUiState(
            lastSignedInEmail = email,
            firebaseConfigured = auth.isFirebaseConfigured,
            pendingInviteToken = pending,
        )
    }

    fun createHousehold(name: String) {
        val token = _state.value.idToken ?: return
        viewModelScope.launch {
            _state.update { it.copy(isBusy = true, lastError = null) }
            try {
                val household = api.createHousehold(name.ifBlank { null }, token)
                _state.update {
                    it.copy(isBusy = false, household = household, step = OnboardingStep.Address)
                }
            } catch (e: Exception) {
                handleFailure(e)
            }
        }
    }

    val isHouseholdOwner: Boolean
        get() {
            val hh = _state.value.household ?: return false
            val uid = _state.value.userUid ?: return false
            return hh.ownerUid == uid
        }

    /**
     * Persist house name and/or home hero JPEG (REQ-002 / UI-004).
     * [imageJpeg] is multipart-uploaded when [imageChanged] is true.
     */
    fun saveHomePhotoEdits(
        name: String?,
        imageJpeg: ByteArray?,
        nameChanged: Boolean,
        imageChanged: Boolean,
        onDone: (Boolean) -> Unit = {},
    ) {
        if (!nameChanged && !imageChanged) {
            onDone(true)
            return
        }
        viewModelScope.launch {
            _state.update { it.copy(isBusy = true, lastError = null) }
            try {
                if (_state.value.isOfflinePreview) {
                    val trimmed = name?.trim()?.takeIf { it.isNotEmpty() }
                    val current = _state.value.household
                    val photoUrl = if (imageChanged && imageJpeg != null) {
                        val b64 = java.util.Base64.getEncoder().encodeToString(imageJpeg)
                        "data:image/jpeg;base64,$b64"
                    } else {
                        current?.photoUrl
                    }
                    val updated = (current ?: Household(
                        id = "preview-home",
                        name = trimmed,
                        ownerUid = _state.value.userUid ?: "preview-user",
                    )).copy(
                        name = if (nameChanged) trimmed else current?.name,
                        photoUrl = photoUrl,
                    )
                    _state.update { it.copy(isBusy = false, household = updated) }
                    onDone(true)
                    return@launch
                }
                if (!isHouseholdOwner) {
                    _state.update {
                        it.copy(
                            isBusy = false,
                            lastError = "Only household owners can update the home photo.",
                        )
                    }
                    onDone(false)
                    return@launch
                }
                val token = _state.value.idToken
                    ?: run {
                        _state.update { it.copy(isBusy = false, lastError = "Not signed in.") }
                        onDone(false)
                        return@launch
                    }
                val householdId = _state.value.household?.id
                    ?: run {
                        _state.update { it.copy(isBusy = false, lastError = "No household.") }
                        onDone(false)
                        return@launch
                    }
                var household = _state.value.household
                if (nameChanged) {
                    val trimmed = name?.trim()?.takeIf { it.isNotEmpty() }
                    household = api.updateHouseholdName(householdId, trimmed, token)
                }
                if (imageChanged) {
                    val bytes = imageJpeg
                        ?: run {
                            _state.update {
                                it.copy(isBusy = false, lastError = "Couldn’t encode that photo.")
                            }
                            onDone(false)
                            return@launch
                        }
                    if (bytes.isEmpty() || bytes.size > 5_000_000) {
                        _state.update {
                            it.copy(
                                isBusy = false,
                                lastError = if (bytes.isEmpty()) {
                                    "Empty photo"
                                } else {
                                    "Photo is too large (max 5 MB)."
                                },
                            )
                        }
                        onDone(false)
                        return@launch
                    }
                    household = api.uploadHouseholdPhoto(
                        householdId = householdId,
                        imageBytes = bytes,
                        token = token,
                    )
                }
                _state.update { it.copy(isBusy = false, household = household) }
                onDone(true)
            } catch (e: Exception) {
                handleFailure(e)
                onDone(false)
            }
        }
    }

    fun saveAddress(address: String) {
        val token = _state.value.idToken ?: return
        val householdId = _state.value.household?.id ?: return
        viewModelScope.launch {
            _state.update { it.copy(isBusy = true, lastError = null) }
            try {
                val household = api.updateAddress(householdId, address, null, null, token)
                val nearby = runCatching { api.nearbyStores(householdId, token).stores }.getOrDefault(emptyList())
                _state.update {
                    it.copy(
                        isBusy = false,
                        household = household,
                        nearbyStores = nearby,
                        selectedStoreIds = nearby.take(2).map { s -> s.id }.toSet(),
                        step = OnboardingStep.Stores,
                    )
                }
            } catch (e: Exception) {
                handleFailure(e)
            }
        }
    }

    fun toggleStore(storeId: String) {
        _state.update {
            val next = it.selectedStoreIds.toMutableSet()
            if (!next.add(storeId)) next.remove(storeId)
            it.copy(selectedStoreIds = next)
        }
    }

    fun saveStores() {
        val token = _state.value.idToken ?: return
        val householdId = _state.value.household?.id ?: return
        val ids = _state.value.selectedStoreIds.toList()
        viewModelScope.launch {
            _state.update { it.copy(isBusy = true, lastError = null) }
            try {
                val household = api.selectStores(householdId, ids, token)
                _state.update { it.copy(isBusy = false, household = household, step = OnboardingStep.Done) }
                refreshDashboard()
            } catch (e: Exception) {
                handleFailure(e)
            }
        }
    }

    fun refreshDashboard() {
        val token = _state.value.idToken ?: return
        val householdId = _state.value.household?.id ?: return
        if (_state.value.isOfflinePreview) return
        viewModelScope.launch {
            try {
                val inventory = api.listInventory(householdId, token).items
                val shopping = api.listShoppingList(householdId, token).items
                val period = _state.value.spendingPeriod
                val spending = runCatching { api.spending(householdId, period, token) }.getOrNull()
                val members = runCatching { api.listMembers(householdId, token).members }.getOrDefault(emptyList())
                val invites = runCatching { api.listInvites(householdId, token).invites }.getOrDefault(emptyList())
                _state.update {
                    it.copy(
                        inventory = inventory,
                        shoppingList = shopping,
                        spending = spending,
                        members = members,
                        invites = invites,
                    )
                }
                acceptPendingInviteIfNeeded()
            } catch (e: Exception) {
                handleFailure(e)
            }
        }
    }

    fun refreshSpending(period: String) {
        _state.update { it.copy(spendingPeriod = period) }
        val token = _state.value.idToken ?: return
        val householdId = _state.value.household?.id ?: return
        if (_state.value.isOfflinePreview) {
            _state.update {
                it.copy(
                    spending = it.spending?.copy(period = period) ?: SpendingReportDto(
                        period = period,
                        total = 86.42,
                        byCategory = listOf(SpendingCategoryDto("Groceries", 54.10)),
                    ),
                )
            }
            return
        }
        viewModelScope.launch {
            try {
                val spending = api.spending(householdId, period, token)
                _state.update { it.copy(spending = spending, spendingPeriod = period) }
            } catch (e: Exception) {
                handleFailure(e)
            }
        }
    }

    fun refreshFamily() {
        val token = _state.value.idToken ?: return
        val householdId = _state.value.household?.id ?: return
        if (_state.value.isOfflinePreview) return
        viewModelScope.launch {
            try {
                val members = api.listMembers(householdId, token).members
                val invites = api.listInvites(householdId, token).invites
                _state.update { it.copy(members = members, invites = invites) }
            } catch (e: Exception) {
                handleFailure(e)
            }
        }
    }

    fun setPendingInviteToken(token: String?) {
        val cleaned = token?.trim()?.takeIf { it.isNotEmpty() }
        _state.update { it.copy(pendingInviteToken = cleaned) }
        if (cleaned != null && _state.value.idToken != null) {
            acceptPendingInviteIfNeeded()
        }
    }

    fun handleInviteDeepLink(uriString: String?) {
        if (uriString.isNullOrBlank()) return
        runCatching {
            val uri = android.net.Uri.parse(uriString)
            if (uri.scheme != "mekasa") return@runCatching
            val host = uri.host.orEmpty()
            if (host != "invite" && !uri.path.orEmpty().contains("invite")) return@runCatching
            val token = uri.getQueryParameter("token")
                ?: uri.pathSegments.firstOrNull { it.isNotBlank() && it != "invite" }
            setPendingInviteToken(token)
        }
    }

    fun createInvite(name: String, email: String?, role: String = "member") {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return
        viewModelScope.launch {
            _state.update { it.copy(isBusy = true, lastError = null) }
            try {
                if (_state.value.isOfflinePreview) {
                    val invite = HouseholdInviteDto(
                        id = "local-invite-${System.currentTimeMillis()}",
                        householdId = _state.value.household?.id ?: "preview-home",
                        name = trimmed,
                        email = email?.trim()?.ifBlank { null },
                        role = role,
                        token = "preview-token",
                        inviteLink = "mekasa://invite?token=preview-token",
                    )
                    _state.update {
                        it.copy(isBusy = false, invites = listOf(invite) + it.invites)
                    }
                    return@launch
                }
                val token = _state.value.idToken ?: return@launch
                val householdId = _state.value.household?.id ?: return@launch
                val created = api.createInvite(
                    householdId,
                    HouseholdInviteCreateRequest(
                        name = trimmed,
                        email = email?.trim()?.ifBlank { null },
                        role = role,
                    ),
                    token,
                )
                _state.update {
                    it.copy(isBusy = false, invites = listOf(created) + it.invites)
                }
            } catch (e: Exception) {
                handleFailure(e)
            }
        }
    }

    fun acceptPendingInviteIfNeeded() {
        val inviteToken = _state.value.pendingInviteToken ?: return
        val token = _state.value.idToken ?: return
        if (_state.value.isOfflinePreview) return
        viewModelScope.launch {
            _state.update { it.copy(isBusy = true, lastError = null) }
            try {
                api.acceptInvite(HouseholdInviteAcceptRequest(inviteToken), token)
                _state.update { it.copy(isBusy = false, pendingInviteToken = null) }
                val household = runCatching { api.currentHousehold(token) }.getOrNull()
                if (household != null) {
                    _state.update {
                        it.copy(
                            household = household,
                            step = when {
                                household.address.isNullOrBlank() -> OnboardingStep.Address
                                household.storeIds.isEmpty() -> OnboardingStep.Stores
                                else -> OnboardingStep.Done
                            },
                        )
                    }
                }
                refreshDashboard()
            } catch (e: Exception) {
                handleFailure(e)
            }
        }
    }

    fun promoteMemberToOwner(memberUid: String) {
        viewModelScope.launch {
            try {
                if (_state.value.isOfflinePreview) {
                    _state.update { state ->
                        state.copy(
                            members = state.members.map {
                                when (it.uid) {
                                    memberUid -> it.copy(role = "owner")
                                    state.userUid -> it.copy(role = "member")
                                    else -> it
                                }
                            },
                        )
                    }
                    return@launch
                }
                val token = _state.value.idToken ?: return@launch
                val householdId = _state.value.household?.id ?: return@launch
                api.updateMemberRole(householdId, memberUid, "owner", token)
                refreshFamily()
            } catch (e: Exception) {
                handleFailure(e)
            }
        }
    }

    suspend fun lookupBarcode(code: String): BarcodeLookupResponse {
        val token = requireTokenForApi()
        return api.lookupBarcode(code.trim(), token)
    }

    suspend fun searchProducts(query: String): List<ProductSearchHit> {
        val token = requireTokenForApi()
        return api.searchProducts(query.trim(), token = token).results
    }

    fun addInventoryItem(draft: PendingInventoryDraft, onDone: () -> Unit = {}) {
        viewModelScope.launch {
            _state.update { it.copy(isBusy = true, lastError = null) }
            try {
                if (_state.value.isOfflinePreview) {
                    val householdId = _state.value.household?.id ?: "preview-home"
                    val item = InventoryItemDto(
                        id = "local-${System.currentTimeMillis()}",
                        householdId = householdId,
                        name = draft.name,
                        category = draft.category,
                        quantity = draft.quantity,
                        barcode = draft.barcode,
                        imageUrl = draft.imageUrl,
                        source = draft.source,
                        pricePaid = draft.pricePaid,
                    )
                    _state.update {
                        it.copy(
                            isBusy = false,
                            inventory = listOf(item) + it.inventory,
                        )
                    }
                    onDone()
                    return@launch
                }
                val token = _state.value.idToken ?: return@launch
                val householdId = _state.value.household?.id ?: return@launch
                val created = api.createInventoryItem(
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
                    token,
                )
                _state.update {
                    it.copy(
                        isBusy = false,
                        inventory = listOf(created) + it.inventory.filterNot { row -> row.id == created.id },
                    )
                }
                onDone()
            } catch (e: Exception) {
                handleFailure(e)
            }
        }
    }

    fun consumeInventoryItem(itemId: String, amount: Int = 1) {
        viewModelScope.launch {
            try {
                if (_state.value.isOfflinePreview) {
                    _state.update { state ->
                        state.copy(
                            inventory = state.inventory.map { item ->
                                if (item.id != itemId) item
                                else item.copy(quantity = (item.quantity - amount).coerceAtLeast(0))
                            },
                        )
                    }
                    val item = _state.value.inventory.firstOrNull { it.id == itemId }
                    if (item != null) {
                        pushTrashEvent("${item.name} −$amount (qty ${item.quantity})")
                    }
                    return@launch
                }
                val token = _state.value.idToken ?: return@launch
                val householdId = _state.value.household?.id ?: return@launch
                val updated = api.consumeInventoryItem(householdId, itemId, amount, token)
                _state.update { state ->
                    state.copy(
                        inventory = state.inventory.map { if (it.id == updated.id) updated else it },
                    )
                }
                pushTrashEvent("${updated.name} −$amount (qty ${updated.quantity})")
            } catch (e: Exception) {
                handleFailure(e)
            }
        }
    }

    fun setTrashKioskMode(enabled: Boolean) {
        _state.update { it.copy(isTrashKioskMode = enabled) }
        if (enabled) refreshUnknownTrashScans()
    }

    fun consumeInventoryByBarcode(barcode: String, amount: Int = 1, onResult: (ConsumeResult) -> Unit = {}) {
        val code = barcode.trim()
        if (code.isEmpty()) {
            onResult(ConsumeResult.Failed("Empty barcode"))
            return
        }
        viewModelScope.launch {
            try {
                if (_state.value.isOfflinePreview) {
                    val match = _state.value.inventory.firstOrNull { it.barcode == code && it.quantity > 0 }
                    if (match == null) {
                        val event = UnknownBarcodeEventDto(
                            id = "local-unk-${System.currentTimeMillis()}",
                            householdId = _state.value.household?.id ?: "preview-home",
                            barcode = code,
                            scannedByUid = _state.value.userUid,
                        )
                        _state.update {
                            it.copy(unknownTrashScans = listOf(event) + it.unknownTrashScans)
                        }
                        pushTrashEvent("Unknown: $code", isUnknown = true)
                        onResult(ConsumeResult.Unknown(code))
                        return@launch
                    }
                    val nextQty = (match.quantity - amount).coerceAtLeast(0)
                    val updated = match.copy(quantity = nextQty)
                    _state.update { state ->
                        state.copy(
                            inventory = state.inventory.map { if (it.id == updated.id) updated else it },
                        )
                    }
                    pushTrashEvent("${updated.name} −$amount (qty $nextQty)")
                    onResult(
                        if (nextQty == 0) ConsumeResult.Depleted(updated)
                        else ConsumeResult.Decremented(updated),
                    )
                    return@launch
                }
                val token = _state.value.idToken ?: return@launch
                val householdId = _state.value.household?.id ?: return@launch
                val result = api.consumeInventoryByBarcode(householdId, code, amount, token)
                if (!result.found || result.item == null) {
                    result.unknownEvent?.let { event ->
                        _state.update {
                            it.copy(unknownTrashScans = listOf(event) + it.unknownTrashScans)
                        }
                    }
                    pushTrashEvent("Unknown: $code", isUnknown = true)
                    onResult(ConsumeResult.Unknown(code))
                    return@launch
                }
                val updated = result.item
                _state.update { state ->
                    state.copy(
                        inventory = state.inventory.map { if (it.id == updated.id) updated else it }
                            .let { list ->
                                if (list.none { it.id == updated.id }) listOf(updated) + list else list
                            },
                    )
                }
                pushTrashEvent("${updated.name} −$amount (qty ${updated.quantity})")
                onResult(
                    if (updated.quantity <= 0) ConsumeResult.Depleted(updated)
                    else ConsumeResult.Decremented(updated),
                )
                refreshUnknownTrashScans()
            } catch (e: Exception) {
                handleFailure(e)
                onResult(ConsumeResult.Failed(e.message ?: "Consume failed"))
            }
        }
    }

    fun refreshUnknownTrashScans() {
        val token = _state.value.idToken ?: return
        val householdId = _state.value.household?.id ?: return
        if (_state.value.isOfflinePreview) return
        viewModelScope.launch {
            try {
                val events = api.listUnknownTrashScans(householdId, token)
                _state.update { it.copy(unknownTrashScans = events) }
            } catch (e: MekasaApiException) {
                if (e.status == 403) return@launch
                handleFailure(e)
            } catch (e: Exception) {
                handleFailure(e)
            }
        }
    }

    private fun pushTrashEvent(message: String, isUnknown: Boolean = false) {
        val event = TrashEvent(
            id = "evt-${System.currentTimeMillis()}",
            message = message,
            isUnknown = isUnknown,
        )
        _state.update { it.copy(trashEvents = listOf(event) + it.trashEvents.take(19)) }
    }

    fun toggleShoppingChecked(itemId: String) {
        val current = _state.value.shoppingList.firstOrNull { it.id == itemId } ?: return
        val nextChecked = !current.isChecked
        viewModelScope.launch {
            try {
                if (_state.value.isOfflinePreview) {
                    replaceShoppingItem(current.copy(isChecked = nextChecked))
                    return@launch
                }
                val token = _state.value.idToken ?: return@launch
                val householdId = _state.value.household?.id ?: return@launch
                val updated = api.updateShoppingListItem(
                    householdId,
                    itemId,
                    ShoppingListItemUpdateRequest(isChecked = nextChecked),
                    token,
                )
                replaceShoppingItem(updated)
            } catch (e: Exception) {
                handleFailure(e)
            }
        }
    }

    fun approveShoppingItem(itemId: String) {
        viewModelScope.launch {
            try {
                if (_state.value.isOfflinePreview) {
                    val current = _state.value.shoppingList.firstOrNull { it.id == itemId } ?: return@launch
                    replaceShoppingItem(current.copy(needsApproval = false, kind = "custom"))
                    return@launch
                }
                val token = _state.value.idToken ?: return@launch
                val householdId = _state.value.household?.id ?: return@launch
                val updated = api.approveShoppingListItem(householdId, itemId, token)
                replaceShoppingItem(updated)
            } catch (e: Exception) {
                handleFailure(e)
            }
        }
    }

    fun rejectShoppingItem(itemId: String) {
        viewModelScope.launch {
            try {
                if (_state.value.isOfflinePreview) {
                    _state.update { it.copy(shoppingList = it.shoppingList.filterNot { row -> row.id == itemId }) }
                    return@launch
                }
                val token = _state.value.idToken ?: return@launch
                val householdId = _state.value.household?.id ?: return@launch
                api.rejectShoppingListItem(householdId, itemId, token)
                _state.update { it.copy(shoppingList = it.shoppingList.filterNot { row -> row.id == itemId }) }
            } catch (e: Exception) {
                handleFailure(e)
            }
        }
    }

    fun addShoppingListItem(name: String, quantity: Int = 1) {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return
        viewModelScope.launch {
            _state.update { it.copy(isBusy = true, lastError = null) }
            try {
                if (_state.value.isOfflinePreview) {
                    val item = ShoppingListItemDto(
                        id = "local-shop-${System.currentTimeMillis()}",
                        householdId = _state.value.household?.id ?: "preview-home",
                        name = trimmed,
                        quantity = quantity.coerceAtLeast(1),
                        kind = "custom",
                    )
                    _state.update {
                        it.copy(isBusy = false, shoppingList = listOf(item) + it.shoppingList)
                    }
                    return@launch
                }
                val token = _state.value.idToken ?: return@launch
                val householdId = _state.value.household?.id ?: return@launch
                val created = api.createShoppingListItem(
                    householdId,
                    ShoppingListItemCreateRequest(name = trimmed, quantity = quantity.coerceAtLeast(1)),
                    token,
                )
                _state.update {
                    it.copy(isBusy = false, shoppingList = listOf(created) + it.shoppingList)
                }
            } catch (e: Exception) {
                handleFailure(e)
            }
        }
    }

    fun syncShoppingFromInventory() {
        viewModelScope.launch {
            try {
                if (_state.value.isOfflinePreview) return@launch
                val token = _state.value.idToken ?: return@launch
                val householdId = _state.value.household?.id ?: return@launch
                val synced = api.syncShoppingListFromInventory(householdId, token)
                _state.update { it.copy(shoppingList = synced.items) }
            } catch (e: Exception) {
                handleFailure(e)
            }
        }
    }

    private fun replaceShoppingItem(updated: ShoppingListItemDto) {
        _state.update { state ->
            state.copy(
                shoppingList = state.shoppingList.map { if (it.id == updated.id) updated else it },
            )
        }
    }

    private suspend fun resumeAfterAuth(
        token: String,
        email: String?,
        displayName: String?,
        uid: String,
    ) {
        val profile = runCatching { api.me(token) }.getOrNull()
        val household = runCatching { api.currentHousehold(token) }.getOrNull()
        _state.update {
            it.copy(
                isBusy = false,
                idToken = token,
                email = profile?.email ?: email,
                displayName = profile?.name ?: displayName ?: email?.substringBefore("@"),
                userUid = profile?.uid ?: uid,
                lastSignedInEmail = profile?.email ?: email,
                household = household,
                step = when {
                    household == null -> OnboardingStep.Household
                    household.address.isNullOrBlank() -> OnboardingStep.Address
                    household.storeIds.isEmpty() -> OnboardingStep.Stores
                    else -> OnboardingStep.Done
                },
                isOfflinePreview = false,
            )
        }
        if (_state.value.step == OnboardingStep.Done) {
            refreshDashboard()
        }
    }

    private suspend fun requireTokenForApi(): String {
        if (_state.value.isOfflinePreview) {
            throw AuthException.Failed("Offline preview — switch to a signed-in session for live lookup")
        }
        return _state.value.idToken
            ?: throw AuthException.Failed("Not signed in")
    }

    private fun handleFailure(error: Throwable) {
        viewModelScope.launch {
            try {
                if (error is MekasaApiException && error.isUnauthorized) {
                    val refreshed = runCatching { auth.refreshIdToken(force = true) }.getOrNull()
                    if (refreshed != null && refreshed != _state.value.idToken) {
                        _state.update { it.copy(idToken = refreshed, isBusy = false) }
                        return@launch
                    }
                    signOut()
                    _state.update {
                        it.copy(lastError = null)
                    }
                    return@launch
                }
                val message = when (error) {
                    is AuthException.Cancelled -> null
                    else -> error.message ?: "Something went wrong"
                }
                _state.update {
                    it.copy(isBusy = false, lastError = message)
                }
            } catch (e: Throwable) {
                signOut()
                _state.update {
                    it.copy(isBusy = false, lastError = e.message ?: "Session expired")
                }
            }
        }
    }

    override fun onCleared() {
        runCatching { api.close() }
        super.onCleared()
    }
}
