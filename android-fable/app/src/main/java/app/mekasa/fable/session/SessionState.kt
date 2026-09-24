package app.mekasa.fable.session

import app.mekasa.fable.data.model.Household
import app.mekasa.fable.data.model.HouseholdInvite
import app.mekasa.fable.data.model.HouseholdMember
import app.mekasa.fable.data.model.InventoryItem
import app.mekasa.fable.data.model.ShoppingItem
import app.mekasa.fable.data.model.SpendingReport
import app.mekasa.fable.data.model.Store
import app.mekasa.fable.data.model.UnknownBarcodeEvent

/** Where the person is in the app. Onboarding stages are derived from the household record. */
enum class Stage {
    SignedOut,
    NameHousehold,
    ConfirmAddress,
    PickStores,
    Home,
    ;

    val isOnboarding: Boolean get() = this == NameHousehold || this == ConfirmAddress || this == PickStores

    /** Progress for the onboarding sticky bar (Welcome counts as the first of six beats). */
    val progress: Float
        get() = when (this) {
            SignedOut -> 1f / 6f
            NameHousehold -> 2f / 6f
            ConfirmAddress -> 3f / 6f
            PickStores -> 4f / 6f
            Home -> 1f
        }

    companion object {
        fun forHousehold(household: Household?): Stage = when {
            household == null -> NameHousehold
            !household.hasAddress -> ConfirmAddress
            !household.hasStores -> PickStores
            else -> Home
        }
    }
}

/** Who is signed in (never carries the ID token; that stays inside the ViewModel). */
data class Account(
    val uid: String,
    val email: String?,
    val displayName: String?,
) {
    val shortName: String get() = displayName?.takeIf { it.isNotBlank() } ?: email?.substringBefore('@') ?: "You"
}

/** One line in the trash-station activity feed. */
data class ScanEvent(
    val id: String,
    val message: String,
    val tone: Tone,
) {
    enum class Tone { Used, Depleted, Unknown, Failed }
}

/** Result of a trash-station scan, reported back to the screen for its toast. */
sealed interface ConsumeOutcome {
    data class Used(val item: InventoryItem) : ConsumeOutcome
    data class Depleted(val item: InventoryItem) : ConsumeOutcome
    data class Unknown(val barcode: String) : ConsumeOutcome
    data class Failed(val message: String) : ConsumeOutcome
}

/** Everything fetched for the current household. Kept separate so refreshes replace it wholesale. */
data class HouseholdData(
    val inventory: List<InventoryItem> = emptyList(),
    val shopping: List<ShoppingItem> = emptyList(),
    val spending: SpendingReport? = null,
    val spendingPeriod: String = "week",
    val members: List<HouseholdMember> = emptyList(),
    val invites: List<HouseholdInvite> = emptyList(),
    val unknownScans: List<UnknownBarcodeEvent> = emptyList(),
    val scanFeed: List<ScanEvent> = emptyList(),
) {
    val lowStock: List<InventoryItem> get() = inventory.filter { it.isLowStock }
    val pendingApprovals: List<ShoppingItem> get() = shopping.filter { it.needsApproval }
    val openShopping: List<ShoppingItem> get() = shopping.filter { !it.isChecked && !it.needsApproval }
    val purchased: List<ShoppingItem> get() = shopping.filter { it.isChecked }
}

data class SessionState(
    val stage: Stage = Stage.SignedOut,
    val account: Account? = null,
    val household: Household? = null,
    val data: HouseholdData = HouseholdData(),
    val isDemo: Boolean = false,
    val firebaseConfigured: Boolean = false,
    val allowTestTokenSignIn: Boolean = false,
    val rememberedEmail: String? = null,
    val pendingInviteToken: String? = null,
    val nearbyStores: List<Store> = emptyList(),
    val selectedStoreIds: Set<String> = emptySet(),
    val kioskMode: Boolean = false,
    val busy: Boolean = false,
    val error: String? = null,
    /** Non-error banner shown on Welcome, e.g. "Your session expired". */
    val notice: String? = null,
) {
    val isSignedIn: Boolean get() = stage != Stage.SignedOut

    /** Owner of the household by record, or by member role (REQ-014 / REQ-002). */
    val isOwner: Boolean
        get() {
            val me = account?.uid ?: return false
            val hh = household ?: return false
            if (hh.ownerUid == me) return true
            return data.members.any { it.uid == me && it.isOwner }
        }

    /** REQ-014: owners mark items purchased; a future "buyer" permission is honoured without a schema change. */
    val canMarkPurchased: Boolean
        get() {
            if (isOwner) return true
            val me = account?.uid ?: return false
            return data.members.firstOrNull { it.uid == me }?.permissions?.contains("buyer") == true
        }
}
