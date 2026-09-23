package app.mekasa.android.session

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.mekasa.android.data.Household
import app.mekasa.android.data.InventoryItemDto
import app.mekasa.android.data.MekasaApiClient
import app.mekasa.android.data.MekasaApiException
import app.mekasa.android.data.ShoppingListItemDto
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
)

class AppSession(
    private val api: MekasaApiClient = MekasaApiClient(),
) : ViewModel() {
    private val _state = MutableStateFlow(AppUiState())
    val state: StateFlow<AppUiState> = _state.asStateFlow()

    fun clearError() = _state.update { it.copy(lastError = null) }

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
                        app.mekasa.android.data.SpendingCategoryDto("Groceries", 54.10),
                        app.mekasa.android.data.SpendingCategoryDto("Beverages", 18.20),
                        app.mekasa.android.data.SpendingCategoryDto("Household", 14.12),
                    ),
                ),
                step = OnboardingStep.Done,
                lastError = null,
            )
        }
    }

    /**
     * Dev / UI path: use Cloud Run test bearer when the backend allows it.
     * Production builds should use a Firebase ID token instead.
     */
    fun signInWithTestToken(email: String, uid: String = "android-${email.hashCode()}") {
        viewModelScope.launch {
            _state.update { it.copy(isBusy = true, lastError = null) }
            val token = "test:$uid"
            try {
                val profile = runCatching { api.me(token) }.getOrNull()
                val household = runCatching { api.currentHousehold(token) }.getOrNull()
                _state.update {
                    it.copy(
                        isBusy = false,
                        idToken = token,
                        email = profile?.email ?: email,
                        displayName = profile?.name ?: email.substringBefore("@"),
                        userUid = profile?.uid ?: uid,
                        lastSignedInEmail = email,
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
            } catch (e: Exception) {
                handleFailure(e)
            }
        }
    }

    fun signOut() {
        val email = _state.value.email ?: _state.value.lastSignedInEmail
        _state.value = AppUiState(lastSignedInEmail = email)
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

    private fun handleFailure(error: Throwable) {
        if (error is MekasaApiException && error.isUnauthorized) {
            signOut()
            return
        }
        _state.update {
            it.copy(isBusy = false, lastError = error.message ?: "Something went wrong")
        }
    }

    override fun onCleared() {
        api.close()
        super.onCleared()
    }
}
