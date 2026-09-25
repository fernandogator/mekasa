package app.mekasa.fable.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onChildren
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeLeft
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
 * Verifies: UI-006 / AC1–AC5, REQ-INV-014..018 / Design: design/baselines/android/InventoryList_baseline.png,
 * InventorySwipeUseOne_baseline.png, InventorySwipeRemove_baseline.png, InventoryUndoToast_baseline.png
 *
 * Structural (Layer 1) checks for the full inventory list: grouped rows, search, the trailing
 * swipe actions (Use 1 when qty > 1, Remove when qty ≤ 1), and the Undo toast after a removal.
 * Swipes are injected with `performTouchInput`; the resulting state is asserted through the
 * ViewModel-driven UI (quantity caption, row presence, toast) rather than by pixel position.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = UiHarness.DEVICE)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class InventoryScreenUITest {
    @get:Rule
    val compose = createComposeRule()

    @Before
    fun setUp() = UiHarness.installFakeImageLoader()

    @Test
    fun layout_keyComposablesVisible() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.INVENTORY)

        compose.awaitDisplayed(TestTags.INVENTORY_LIST_VIEW)
        compose.node(TestTags.BACK_BUTTON).assertIsDisplayed()
        compose.onNodeWithText("Inventory").assertIsDisplayed()
        compose.onNodeWithText("4 ITEMS · 2 LOW").assertIsDisplayed()
        compose.node(TestTags.INVENTORY_ADD_BUTTON).assertIsDisplayed()
        compose.node(TestTags.INVENTORY_SEARCH).assertIsDisplayed()
        compose.node(TestTags.ITEM_LIST).assertIsDisplayed()
        // UI-006 AC1: rows are grouped by category with uppercase headers.
        compose.onNodeWithText("BAKERY").assertIsDisplayed()
        compose.onNodeWithText("BEVERAGES").assertIsDisplayed()
        compose.node(TestTags.itemCell(UiHarness.DIET_COKE_ID)).assertIsDisplayed()
        compose.node(TestTags.itemCell(UiHarness.WHOLE_MILK_ID)).assertIsDisplayed()
        // Full-height inventory hides the tab pill (it is a pushed route, not a tab).
        compose.node(TestTags.BOTTOM_NAV_BAR).assertDoesNotExist()
        compose.node(TestTags.EMPTY_STATE_VIEW).assertDoesNotExist()
    }

    @Test
    fun interaction_tapsInputsAndNavigationTriggers() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.INVENTORY)
        compose.awaitDisplayed(TestTags.INVENTORY_LIST_VIEW)

        // Search filters rows by name/category (UI-006 AC1).
        compose.node(TestTags.INVENTORY_SEARCH).performTextInput("milk")
        compose.awaitGone(TestTags.itemCell(UiHarness.DIET_COKE_ID))
        compose.node(TestTags.itemCell(UiHarness.WHOLE_MILK_ID)).assertIsDisplayed()

        // The row's Use 1 link decrements through the ViewModel (REQ-INV-014 button path).
        compose.node(TestTags.useOne(UiHarness.WHOLE_MILK_ID)).performClick()
        compose.waitUntil(UiHarness.WAIT_MS) {
            compose.onAllNodes(hasText("Dairy · qty 0")).fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithText("Out").assertIsDisplayed()
    }

    @Test
    fun flow_navigatesToNextScreen() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.INVENTORY)
        compose.awaitDisplayed(TestTags.INVENTORY_LIST_VIEW)

        // Row tap → item detail (UI-006 AC2); back returns to the list.
        compose.node(TestTags.itemCell(UiHarness.DIET_COKE_ID)).performClick()
        compose.awaitDisplayed(TestTags.ITEM_DETAIL_VIEW)
        compose.onNodeWithText("Diet Coke").assertIsDisplayed()
        compose.node(TestTags.BACK_BUTTON).performClick()
        compose.awaitDisplayed(TestTags.INVENTORY_LIST_VIEW)

        // Header "Add" opens the add-items hub.
        compose.node(TestTags.INVENTORY_ADD_BUTTON).performClick()
        compose.awaitDisplayed(TestTags.ADD_ITEMS_HUB)
    }

    @Test
    fun visual_semanticStructureMatchesBaseline() {
        compose.setApp(UiHarness.demoSession(undoWindowMillis = 60_000), startRoute = Routes.INVENTORY)
        compose.awaitDisplayed(TestTags.INVENTORY_LIST_VIEW)

        // REQ-INV-014: qty 2 → trailing swipe is "Use 1"; committing decrements and the row springs back.
        compose.onNodeWithText("Beverages · qty 2").assertIsDisplayed()
        compose.node(TestTags.itemCell(UiHarness.DIET_COKE_ID)).performTouchInput { swipeLeft() }
        compose.waitUntil(UiHarness.WAIT_MS) {
            compose.onAllNodes(hasText("Beverages · qty 1")).fetchSemanticsNodes().isNotEmpty()
        }
        compose.node(TestTags.itemCell(UiHarness.DIET_COKE_ID)).assertIsDisplayed()
        compose.node(TestTags.INVENTORY_UNDO_TOAST).assertDoesNotExist()

        // REQ-INV-015/016: qty 1 → trailing swipe is "Remove"; the row leaves and the Undo toast appears.
        compose.onNodeWithText("Dairy · qty 1").assertIsDisplayed()
        compose.node(TestTags.itemCell(UiHarness.WHOLE_MILK_ID)).performTouchInput { swipeLeft() }
        compose.awaitGone(TestTags.itemCell(UiHarness.WHOLE_MILK_ID))
        compose.awaitDisplayed(TestTags.INVENTORY_UNDO_TOAST)
        compose.onNodeWithText("Item removed").assertIsDisplayed()
        compose.onNodeWithText("3 ITEMS · 1 LOW").assertIsDisplayed()

        // REQ-INV-017: Undo restores the row in place and hides the toast.
        compose.node(TestTags.INVENTORY_UNDO_BUTTON).performClick()
        compose.awaitDisplayed(TestTags.itemCell(UiHarness.WHOLE_MILK_ID))
        compose.awaitGone(TestTags.INVENTORY_UNDO_TOAST)
        compose.onNodeWithText("4 ITEMS · 2 LOW").assertIsDisplayed()
        compose.node(TestTags.ITEM_LIST).performScrollToNode(hasTestTag(TestTags.itemCell(UiHarness.PAPER_TOWELS_ID)))
        compose.node(TestTags.ITEM_LIST).onChildren().onFirst().assertIsDisplayed()
    }
}
