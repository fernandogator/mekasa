package app.mekasa.fable.ui

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.mekasa.fable.support.UiHarness
import app.mekasa.fable.support.UiHarness.awaitDisplayed
import app.mekasa.fable.support.UiHarness.awaitGone
import app.mekasa.fable.support.UiHarness.node
import app.mekasa.fable.support.UiHarness.setApp
import app.mekasa.fable.ui.home.Routes
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Verifies: REQ-013, REQ-014 (shopping list, owner purchase gate) / Design: design/baselines/android/ShoppingList_baseline.png
 *
 * Structural (Layer 1) checks for the List tab: auto vs. requested rows, approval actions
 * for owners, manual add, and the purchase lock for members.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = UiHarness.DEVICE)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ShoppingListUITest {
    @get:Rule
    val compose = createComposeRule()

    @Before
    fun setUp() = UiHarness.installFakeImageLoader()

    @Test
    fun layout_keyComposablesVisible() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.LIST)

        compose.awaitDisplayed(TestTags.SHOPPING_LIST_VIEW)
        compose.onNodeWithText("Shopping list").assertIsDisplayed()
        compose.node(TestTags.SYNC_LOW_STOCK).assertIsDisplayed()
        compose.node(TestTags.SHOPPING_ADD_TOGGLE).assertIsDisplayed()
        // Demo fixtures: one auto row (Diet Coke) and one request awaiting approval (Avocados);
        // "Needs approval" is both the section heading and the row chip.
        compose.onAllNodesWithText("Needs approval").assertCountEquals(2)
        compose.node(TestTags.shoppingRow(UiHarness.REQUEST_SHOPPING_ID)).assertIsDisplayed()
        compose.node(TestTags.approve(UiHarness.REQUEST_SHOPPING_ID)).assertIsDisplayed()
        compose.node(TestTags.reject(UiHarness.REQUEST_SHOPPING_ID)).assertIsDisplayed()
        compose.onNodeWithText("To buy").assertIsDisplayed()
        compose.node(TestTags.shoppingRow(UiHarness.AUTO_SHOPPING_ID)).assertIsDisplayed()
        compose.node(TestTags.shoppingToggle(UiHarness.AUTO_SHOPPING_ID)).assertIsDisplayed()
        compose.onNodeWithText("Auto").assertIsDisplayed()
        // Owners never see the purchase lock.
        compose.node(TestTags.PURCHASE_LOCK_NOTICE).assertDoesNotExist()
        compose.node(TestTags.SHOPPING_EMPTY).assertDoesNotExist()
        compose.node(TestTags.BOTTOM_NAV_BAR).assertIsDisplayed()
    }

    @Test
    fun interaction_tapsInputsAndNavigationTriggers() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.LIST)
        compose.awaitDisplayed(TestTags.SHOPPING_LIST_VIEW)

        // Approve moves the request out of "Needs approval" into "To buy".
        compose.node(TestTags.approve(UiHarness.REQUEST_SHOPPING_ID)).performClick()
        compose.awaitGone(TestTags.approve(UiHarness.REQUEST_SHOPPING_ID))
        compose.node(TestTags.shoppingRow(UiHarness.REQUEST_SHOPPING_ID)).assertIsDisplayed()
        compose.onNodeWithText("Needs approval").assertDoesNotExist()

        // Owner marks the auto row purchased → it drops into "Purchased".
        compose.node(TestTags.shoppingToggle(UiHarness.AUTO_SHOPPING_ID)).assertIsEnabled().performClick()
        compose.awaitDisplayed(TestTags.shoppingRow(UiHarness.AUTO_SHOPPING_ID))
        compose.waitUntil(UiHarness.WAIT_MS) { compose.onAllNodes(hasText("Purchased")).fetchSemanticsNodes().isNotEmpty() }

        // Manual add: card appears, submit is gated on a name, and the new row shows up.
        compose.node(TestTags.SHOPPING_ADD_TOGGLE).performClick()
        compose.awaitDisplayed(TestTags.ADD_SHOPPING_CARD)
        compose.node(TestTags.SHOPPING_ADD_SUBMIT).assertIsNotEnabled()
        compose.node(TestTags.SHOPPING_NAME_FIELD).performTextInput("Bananas")
        compose.node(TestTags.SHOPPING_ADD_SUBMIT).assertIsEnabled().performClick()
        compose.waitUntil(UiHarness.WAIT_MS) { compose.onAllNodes(hasText("Bananas")).fetchSemanticsNodes().isNotEmpty() }
        compose.awaitGone(TestTags.ADD_SHOPPING_CARD)
    }

    @Test
    fun flow_navigatesToNextScreen() {
        compose.setApp(UiHarness.demoSession())
        compose.awaitDisplayed(TestTags.DASHBOARD_VIEW)

        // Dashboard → List tab via the pill nav, then back Home.
        compose.node(TestTags.LIST_TAB).performClick()
        compose.awaitDisplayed(TestTags.SHOPPING_LIST_VIEW)
        compose.node(TestTags.HOME_TAB).performClick()
        compose.awaitDisplayed(TestTags.DASHBOARD_VIEW)

        // Sync low stock adds Whole Milk (qty 1 ≤ threshold 2) as an auto row.
        compose.node(TestTags.LIST_TAB).performClick()
        compose.awaitDisplayed(TestTags.SHOPPING_LIST_VIEW)
        compose.node(TestTags.SYNC_LOW_STOCK).performClick()
        compose.waitUntil(UiHarness.WAIT_MS) { compose.onAllNodes(hasText("Whole Milk")).fetchSemanticsNodes().isNotEmpty() }
    }

    @Test
    fun visual_semanticStructureMatchesBaseline() {
        // REQ-014: a member (the demo kid) sees the lock notice and disabled purchase toggles.
        compose.setApp(UiHarness.memberSession(), startRoute = Routes.LIST)
        compose.awaitDisplayed(TestTags.SHOPPING_LIST_VIEW)

        compose.awaitDisplayed(TestTags.PURCHASE_LOCK_NOTICE)
        compose.onNodeWithText("Only household owners can mark items purchased.").assertIsDisplayed()
        compose.node(TestTags.shoppingToggle(UiHarness.AUTO_SHOPPING_ID)).assertIsNotEnabled()
        // Members cannot approve requests either; the pending row is still listed.
        compose.node(TestTags.shoppingRow(UiHarness.REQUEST_SHOPPING_ID)).assertIsDisplayed()
        compose.node(TestTags.approve(UiHarness.REQUEST_SHOPPING_ID)).assertDoesNotExist()
        compose.node(TestTags.reject(UiHarness.REQUEST_SHOPPING_ID)).assertDoesNotExist()
        compose.onNodeWithText("1 TO BUY").assertIsDisplayed()
    }
}
