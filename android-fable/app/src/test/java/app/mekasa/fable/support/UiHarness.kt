package app.mekasa.fable.support

import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.SemanticsNodeInteractionCollection
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.ComposeContentTestRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeUp
import androidx.test.core.app.ApplicationProvider
import app.mekasa.fable.data.demo.DemoBackend
import app.mekasa.fable.data.model.Household
import app.mekasa.fable.data.model.HouseholdMember
import app.mekasa.fable.data.model.ShoppingItem
import app.mekasa.fable.data.model.StoreSearchResponse
import app.mekasa.fable.data.model.UserProfile
import app.mekasa.fable.session.InMemoryEmailMemory
import app.mekasa.fable.session.SessionViewModel
import app.mekasa.fable.ui.MekasaRoot
import app.mekasa.fable.ui.home.Routes
import app.mekasa.fable.ui.theme.MekasaTheme
import coil.Coil
import coil.ImageLoader
import coil.test.FakeImageLoaderEngine

/**
 * Shared fixtures for the Layer 1 (structural) and Layer 2 (snapshot) Robolectric tests.
 *
 * Screens are always driven through the production [SessionViewModel] + [MekasaRoot] path:
 * "Browse UI offline" installs the same [DemoBackend] the app uses, so the tests exercise the
 * real composables against deterministic demo fixtures (no separate mock UI).
 */
object UiHarness {
    /** Robolectric device used for every capture so baselines are deterministic. */
    const val DEVICE = "w411dp-h914dp-normal-long-notround-any-420dpi-keyshidden-nonav"

    const val WAIT_MS = 10_000L

    /** Demo fixture ids (see [DemoBackend.seedSampleHousehold]); ids are assigned from 100 in seed order. */
    const val DIET_COKE_ID = "inv-100" // qty 2 → swipe shows Use 1 (REQ-INV-014)
    const val WHOLE_MILK_ID = "inv-101" // qty 1 → swipe shows Remove (REQ-INV-015)
    const val SOURDOUGH_ID = "inv-102"
    const val PAPER_TOWELS_ID = "inv-103"
    const val AUTO_SHOPPING_ID = "shop-104" // Diet Coke, kind=auto
    const val REQUEST_SHOPPING_ID = "shop-105" // Avocados, needs approval

    /**
     * Coil must never touch the network under Robolectric: every image request resolves to
     * a flat sage swatch so thumbnails render the same on every run.
     */
    fun installFakeImageLoader() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val engine = FakeImageLoaderEngine.Builder()
            .default(ColorDrawable(Color.parseColor("#B7C6C2")))
            .build()
        Coil.setImageLoader(ImageLoader.Builder(context).components { add(engine) }.build())
    }

    /** Signed-out ViewModel with Firebase "not configured", mirroring the CI stub build. */
    fun signedOutSession(
        api: FakeApi = FakeApi(),
        auth: FakeAuthGateway = FakeAuthGateway(isConfigured = false),
        undoWindowMillis: Long = SessionViewModel.UNDO_WINDOW_MILLIS,
    ): SessionViewModel = SessionViewModel(
        api = api,
        auth = auth,
        emailMemory = InMemoryEmailMemory(),
        allowTestTokenSignIn = true,
        undoWindowMillis = undoWindowMillis,
    )

    /** The offline-preview session: Stage.Home, owner, demo household seeded by [DemoBackend]. */
    fun demoSession(undoWindowMillis: Long = SessionViewModel.UNDO_WINDOW_MILLIS): SessionViewModel =
        signedOutSession(undoWindowMillis = undoWindowMillis).also { it.browseOffline() }

    /**
     * Signed-in session where the account is a *member* of someone else's household, so the
     * REQ-014 purchase gate and owner-only affordances can be asserted. Runs through the
     * production RemoteBackend path against [MemberApi].
     */
    fun memberSession(): SessionViewModel {
        val vm = signedOutSession(api = MemberApi())
        vm.signInWithTestToken("mateo@example.com")
        return vm
    }

    /** A fresh account with no household yet, so [MekasaRoot] shows the onboarding stages. */
    fun onboardingSession(): SessionViewModel {
        val api = OnboardingApi()
        val vm = signedOutSession(api = api)
        vm.signInWithTestToken("ana@example.com")
        return vm
    }

    /** Composes the app root exactly as [app.mekasa.fable.MainActivity] does. */
    fun ComposeContentTestRule.setApp(session: SessionViewModel, startRoute: String = Routes.DASHBOARD) {
        setContent {
            MekasaTheme {
                MekasaRoot(session = session, startRoute = startRoute)
            }
        }
    }

    /**
     * Tag lookups always use the unmerged tree: tags nested inside clickable containers
     * (e.g. the edit button on the hero band) are folded away in the merged tree.
     */
    fun ComposeContentTestRule.node(tag: String): SemanticsNodeInteraction = onNodeWithTag(tag, useUnmergedTree = true)

    fun ComposeContentTestRule.nodes(tag: String): SemanticsNodeInteractionCollection =
        onAllNodesWithTag(tag, useUnmergedTree = true)

    /** Waits until a node with [tag] exists, then returns it. */
    fun ComposeContentTestRule.awaitTag(tag: String, timeoutMs: Long = WAIT_MS): SemanticsNodeInteraction {
        waitUntil(timeoutMs) { onAllNodesWithTagCount(tag) > 0 }
        return node(tag)
    }

    fun ComposeContentTestRule.awaitDisplayed(tag: String, timeoutMs: Long = WAIT_MS): SemanticsNodeInteraction =
        awaitTag(tag, timeoutMs).also { it.assertIsDisplayed() }

    fun ComposeContentTestRule.awaitGone(tag: String, timeoutMs: Long = WAIT_MS) {
        waitUntil(timeoutMs) { onAllNodesWithTagCount(tag) == 0 }
    }

    /**
     * Flings a scrolling screen to its end. `performScrollTo()` only brings a node to the edge
     * of the viewport, which on tab screens is underneath the floating pill nav; the content's
     * bottom padding clears it once the list is fully scrolled.
     */
    fun ComposeContentTestRule.scrollToBottom(containerTag: String) {
        repeat(3) { node(containerTag).performTouchInput { swipeUp() } }
        waitForIdle()
    }

    private fun ComposeContentTestRule.onAllNodesWithTagCount(tag: String): Int =
        onAllNodes(hasTestTag(tag), useUnmergedTree = true).fetchSemanticsNodes().size
}

/**
 * [FakeApi] variant where the signed-in profile (`uid-1`) is a plain member of a household
 * owned by `uid-owner`. Shopping fixtures mirror the demo list: one auto row, one request.
 */
class MemberApi : FakeApi() {
    init {
        household = Household(
            id = "hh-1",
            name = "The Guerrero Home",
            ownerUid = "uid-owner",
            address = "123 Peachtree St, Atlanta, GA",
            storeIds = listOf("publix-midtown"),
        )
        members.clear()
        members += HouseholdMember(uid = "uid-owner", householdId = "hh-1", name = "Ana", role = "owner")
        members += HouseholdMember(uid = "uid-1", householdId = "hh-1", name = "Mateo", role = "member")
        shopping.clear()
        shopping += ShoppingItem(
            id = UiHarness.AUTO_SHOPPING_ID, householdId = "hh-1", name = "Diet Coke", quantity = 1, kind = "auto",
        )
        shopping += ShoppingItem(
            id = UiHarness.REQUEST_SHOPPING_ID, householdId = "hh-1", name = "Avocados", quantity = 3,
            kind = "request", needsApproval = true, requestedBy = "Mateo",
        )
    }

    override suspend fun me(token: String): UserProfile {
        calls += "me:$token"
        return UserProfile(uid = "uid-1", email = "mateo@example.com", name = "Mateo")
    }
}

/**
 * [FakeApi] variant for the onboarding flow: no household until [createHousehold], and the
 * demo stores come back from `/stores/nearby` so the store picker has rows to render.
 */
class OnboardingApi : FakeApi() {
    init {
        household = null
    }

    override suspend fun createHousehold(token: String, name: String?): Household {
        calls += "createHousehold"
        return Household(id = "hh-1", name = name, ownerUid = "uid-1").also { household = it }
    }

    override suspend fun nearbyStores(token: String, householdId: String): StoreSearchResponse {
        calls += "nearbyStores"
        return StoreSearchResponse(stores = DemoBackend.SAMPLE_STORES)
    }
}
