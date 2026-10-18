package app.mekasa.fable.ui

import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.mekasa.fable.support.FakeApi
import app.mekasa.fable.support.UiHarness
import app.mekasa.fable.support.UiHarness.awaitDisplayed
import app.mekasa.fable.support.UiHarness.awaitGone
import app.mekasa.fable.support.UiHarness.node
import app.mekasa.fable.support.UiHarness.setApp
import app.mekasa.fable.ui.home.Routes
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Verifies: REQ-024 AC7, REQ-003 AC11
 *
 * Structural (Layer 1) checks for the per-store shopping lists and the Grocery stores
 * settings. The demo household saves Publix and Costco; the Avocados request is on Costco
 * and the auto Diet Coke row is on "Any store".
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = UiHarness.DEVICE)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ShoppingStoresUITest {
    @get:Rule
    val compose = createComposeRule()

    @Before
    fun setUp() = UiHarness.installFakeImageLoader()

    @Test
    fun storeSelector_filtersRowsAndShowsStoreNamesOnAll() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.LIST)
        compose.awaitDisplayed(TestTags.SHOPPING_STORE_SELECTOR)

        listOf("all", PUBLIX, COSTCO, "any").forEach { compose.node(TestTags.storeChip(it)).assertExists() }
        compose.node(TestTags.storeChip("all")).assertIsSelected()
        compose.node(TestTags.shoppingRowStore(UiHarness.REQUEST_SHOPPING_ID)).assertTextEquals("Costco")
        compose.node(TestTags.shoppingRowStore(UiHarness.AUTO_SHOPPING_ID)).assertTextEquals("Any store")

        compose.node(TestTags.storeChip(COSTCO)).performClick()
        compose.awaitGone(TestTags.shoppingRow(UiHarness.AUTO_SHOPPING_ID))
        compose.node(TestTags.shoppingRow(UiHarness.REQUEST_SHOPPING_ID)).assertIsDisplayed()
        compose.node(TestTags.shoppingRowStore(UiHarness.REQUEST_SHOPPING_ID)).assertDoesNotExist()

        compose.node(TestTags.storeChip("any")).performClick()
        compose.awaitGone(TestTags.shoppingRow(UiHarness.REQUEST_SHOPPING_ID))
        compose.node(TestTags.shoppingRow(UiHarness.AUTO_SHOPPING_ID)).assertIsDisplayed()

        compose.node(TestTags.storeChip(PUBLIX)).performClick()
        compose.awaitDisplayed(TestTags.SHOPPING_EMPTY)
    }

    @Test
    fun addFromStoreList_savesToThatStore() {
        val session = UiHarness.demoSession()
        compose.setApp(session, startRoute = Routes.LIST)
        compose.awaitDisplayed(TestTags.SHOPPING_STORE_SELECTOR)

        compose.node(TestTags.storeChip(PUBLIX)).performClick()
        compose.node(TestTags.SHOPPING_ADD_TOGGLE).performClick()
        compose.awaitDisplayed(TestTags.ADD_SHOPPING_CARD)
        compose.onNodeWithText("Goes on the Publix list.").assertIsDisplayed()
        compose.node(TestTags.SHOPPING_NAME_FIELD).performTextInput("Bananas")
        compose.node(TestTags.SHOPPING_ADD_SUBMIT).performClick()

        compose.waitUntil(UiHarness.WAIT_MS) { session.state.value.data.shopping.any { it.name == "Bananas" } }
        assertEquals(PUBLIX, session.state.value.data.shopping.first { it.name == "Bananas" }.storeId)
        compose.waitUntil(UiHarness.WAIT_MS) { compose.onAllNodes(hasText("Bananas")).fetchSemanticsNodes().isNotEmpty() }
    }

    @Test
    fun moveTo_movesRowToAnotherStore() {
        val session = UiHarness.demoSession()
        compose.setApp(session, startRoute = Routes.LIST)
        compose.awaitDisplayed(TestTags.shoppingMove(UiHarness.AUTO_SHOPPING_ID))

        compose.node(TestTags.shoppingMove(UiHarness.AUTO_SHOPPING_ID)).performClick()
        compose.awaitDisplayed(TestTags.shoppingMoveTo(UiHarness.AUTO_SHOPPING_ID, PUBLIX))
        compose.node(TestTags.shoppingMoveTo(UiHarness.AUTO_SHOPPING_ID, "any")).assertIsDisplayed()
        compose.node(TestTags.shoppingMoveTo(UiHarness.AUTO_SHOPPING_ID, PUBLIX)).performClick()

        compose.waitUntil(UiHarness.WAIT_MS) {
            session.state.value.data.shopping.first { it.id == UiHarness.AUTO_SHOPPING_ID }.storeId == PUBLIX
        }
        compose.node(TestTags.shoppingRowStore(UiHarness.AUTO_SHOPPING_ID)).assertTextEquals("Publix")
    }

    @Test
    fun ownerWithoutStores_seesOneListAndTheSettingsHint() {
        val session = UiHarness.signedOutSession(api = FakeApi())
        session.signInWithTestToken("ana@example.com")
        compose.setApp(session, startRoute = Routes.LIST)
        compose.awaitDisplayed(TestTags.SHOPPING_LIST_VIEW)

        compose.awaitDisplayed(TestTags.SHOPPING_STORES_HINT)
        compose.onNodeWithText("Want a list per store? Choose your grocery stores in Family settings.").assertIsDisplayed()
        compose.node(TestTags.SHOPPING_STORE_SELECTOR).assertDoesNotExist()
        compose.node(TestTags.shoppingMove("s1")).assertDoesNotExist()
    }

    @Test
    fun member_seesNoSelectorHintOrStorePicker() {
        val session = UiHarness.memberSession()
        compose.setApp(session, startRoute = Routes.LIST)
        compose.awaitDisplayed(TestTags.SHOPPING_LIST_VIEW)
        compose.node(TestTags.SHOPPING_STORES_HINT).assertDoesNotExist()
        compose.node(TestTags.SHOPPING_STORE_SELECTOR).assertDoesNotExist()

        compose.node(TestTags.FAMILY_TAB).performClick()
        compose.awaitDisplayed(TestTags.FAMILY_VIEW)
        // MemberApi saved a bare store ID only, so there are no store details to list.
        compose.node(TestTags.GROCERY_STORES_EMPTY).performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("No stores saved yet. Add where you shop to keep a shopping list for each store.").assertExists()
        compose.node(TestTags.CHOOSE_STORES_BUTTON).assertDoesNotExist()
    }

    @Test
    fun groceryStores_listsSavedStoresAndChangeStoresSavesThePicker() {
        val session = UiHarness.demoSession()
        compose.setApp(session, startRoute = Routes.FAMILY)
        compose.awaitDisplayed(TestTags.FAMILY_VIEW)

        compose.node(TestTags.GROCERY_STORES_SECTION).performScrollTo()
        compose.node(TestTags.savedStore(PUBLIX)).assertExists()
        compose.node(TestTags.savedStore(COSTCO)).assertExists()
        compose.onNodeWithText("950 W Peachtree St NW, Atlanta · 0.8 mi").assertExists()
        compose.node(TestTags.CHOOSE_STORES_BUTTON).performScrollTo()
        compose.onNodeWithText("Change stores").assertExists()

        compose.node(TestTags.CHOOSE_STORES_BUTTON).performSemanticsAction(SemanticsActions.OnClick)
        compose.awaitDisplayed(TestTags.STORE_PICKER)
        compose.awaitTagInPicker(TestTags.storeRow(KROGER))
        compose.onNodeWithText("Where do you shop?").assertIsDisplayed()
        compose.onNodeWithText("We'll look within 15 miles of 123 Peachtree St, Atlanta, GA").assertIsDisplayed()

        // Search narrows the rows by name or address.
        compose.node(TestTags.STORE_PICKER_SEARCH).performTextInput("ponce")
        compose.awaitGone(TestTags.storeRow(PUBLIX))
        compose.node(TestTags.storeRow(KROGER)).performClick()

        compose.node(TestTags.STORE_PICKER_CONFIRM).performClick()
        compose.awaitGone(TestTags.STORE_PICKER)
        compose.waitUntil(UiHarness.WAIT_MS) { session.state.value.household?.stores?.size == 3 }
        assertEquals(listOf(PUBLIX, KROGER, COSTCO), session.state.value.household?.storeIds)
        compose.node(TestTags.savedStore(KROGER)).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun storePicker_cancelKeepsStoresAndConfirmNeedsOneStore() {
        val session = UiHarness.demoSession()
        compose.setApp(session, startRoute = Routes.FAMILY)
        compose.awaitDisplayed(TestTags.FAMILY_VIEW)
        compose.node(TestTags.CHOOSE_STORES_BUTTON).performScrollTo().performSemanticsAction(SemanticsActions.OnClick)
        compose.awaitTagInPicker(TestTags.storeRow(PUBLIX))

        compose.node(TestTags.storeRow(PUBLIX)).performClick()
        compose.node(TestTags.storeRow(COSTCO)).performClick()
        compose.node(TestTags.STORE_PICKER_CONFIRM).assertIsNotEnabled()

        compose.node(TestTags.STORE_PICKER_CANCEL).performClick()
        compose.awaitGone(TestTags.STORE_PICKER)
        assertEquals(listOf(PUBLIX, COSTCO), session.state.value.household?.storeIds)
    }

    private fun androidx.compose.ui.test.junit4.ComposeContentTestRule.awaitTagInPicker(tag: String) {
        waitUntil(UiHarness.WAIT_MS) { onAllNodes(androidx.compose.ui.test.hasTestTag(tag), useUnmergedTree = true).fetchSemanticsNodes().isNotEmpty() }
    }

    private companion object {
        const val PUBLIX = "publix-midtown"
        const val COSTCO = "costco-brookhaven"
        const val KROGER = "kroger-ponce"
    }
}
