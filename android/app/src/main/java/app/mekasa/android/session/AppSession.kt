package app.mekasa.android.session

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.mekasa.android.auth.AuthException
import app.mekasa.android.auth.AuthResult
import app.mekasa.android.auth.AuthService
import app.mekasa.android.data.BarcodeLookupResponse
import app.mekasa.android.data.Household
import app.mekasa.android.data.InventoryItemCreateRequest
import app.mekasa.android.data.InventoryItemDto
import app.mekasa.android.data.MekasaApiClient
import app.mekasa.android.data.MekasaApiException
import app.mekasa.android.data.ProductSearchHit
import app.mekasa.android.data.ShoppingListItemDto
import app.mekasa.android.data.SpendingCategoryDto
import app.mekasa.android.data.SpendingReportDto
import app.mekasa.android.data.Store
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
                        category = "Beverages",
                        quantity = 1,
                        needsApproval = false,
                    ),
                    ShoppingListItemDto(
                        id = "s2",
                        householdId = "preview-home",
                        name = "Avocados",
                        category = "Produce",
                        quantity = 3,
                        needsApproval = true,
                        requestedByUid = "kid",
                    ),
                ),
                spending = SpendingReportDto(
                    period = "week",
                    totalSpent = 86.42,
                    categories = listOf(
                        SpendingCategoryDto("Groceries", 54.10),
                        SpendingCategoryDto("Beverages", 18.20),
                        SpendingCategoryDto("Household", 14.12),
                    ),
                ),
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
        _state.value = AppUiState(
            lastSignedInEmail = email,
            firebaseConfigured = auth.isFirebaseConfigured,
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
                val spending = runCatching { api.spending(householdId, "week", token) }.getOrNull()
                _state.update {
                    it.copy(
                        inventory = inventory,
                        shoppingList = shopping,
                        spending = spending,
                    )
                }
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
            if (error is MekasaApiException && error.isUnauthorized) {
                val refreshed = auth.refreshIdToken(force = true)
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
        }
    }

    override fun onCleared() {
        api.close()
        super.onCleared()
    }
}
