package app.mekasa.fable.ui

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.mekasa.fable.support.UiHarness
import app.mekasa.fable.support.UiHarness.awaitDisplayed
import app.mekasa.fable.support.UiHarness.awaitTag
import app.mekasa.fable.support.UiHarness.node
import app.mekasa.fable.support.UiHarness.nodes
import app.mekasa.fable.support.UiHarness.setApp
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Verifies: UI-004 / AC1–AC4 / Design: design/baselines/android/Dashboard_baseline.png
 *
 * Structural (Layer 1) checks for the Home dashboard, driven through the production
 * SessionViewModel + DemoBackend path ("Browse UI offline").
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = UiHarness.DEVICE)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class DashboardUITest {
    @get:Rule
    val compose = createComposeRule()

    @Before
    fun setUp() = UiHarness.installFakeImageLoader()

    @Test
    fun layout_keyComposablesVisible() {
        compose.setApp(UiHarness.demoSession())

        compose.awaitDisplayed(TestTags.DASHBOARD_VIEW)
        compose.awaitDisplayed(TestTags.HOME_PHOTO_HERO)
        compose.node(TestTags.EDIT_HOME_BUTTON).assertIsDisplayed()
        compose.node(TestTags.LOW_STOCK_STAT_BUTTON).assertIsDisplayed()
        compose.node(TestTags.SPEND_STAT_BUTTON).assertIsDisplayed()
        compose.node(TestTags.BOTTOM_NAV_BAR).assertIsDisplayed()
        compose.node(TestTags.ADD_ITEM_BUTTON).assertIsDisplayed()
        // UI-004 AC3: the household name sits on the hero band.
        compose.onNodeWithText("The Guerrero Home").assertIsDisplayed()
    }

    @Test
    fun interaction_tapsInputsAndNavigationTriggers() {
        compose.setApp(UiHarness.demoSession())
        compose.awaitDisplayed(TestTags.DASHBOARD_VIEW)

        // Tapping the Spend stat switches to the Spend tab.
        compose.node(TestTags.SPEND_STAT_BUTTON).performClick()
        compose.awaitDisplayed(TestTags.SPENDING_VIEW)

        // Bottom nav returns Home; the FAB opens the Add Items hub.
        compose.node(TestTags.HOME_TAB).performClick()
        compose.awaitDisplayed(TestTags.DASHBOARD_VIEW)
        compose.node(TestTags.ADD_ITEM_BUTTON).performClick()
        compose.awaitDisplayed(TestTags.ADD_ITEMS_HUB)
    }

    @Test
    fun flow_navigatesToNextScreen() {
        compose.setApp(UiHarness.demoSession())
        compose.awaitDisplayed(TestTags.DASHBOARD_VIEW)

        // Low-stock stat card → full inventory (UI-004 AC2 → UI-006).
        compose.node(TestTags.LOW_STOCK_STAT_BUTTON).performClick()
        compose.awaitDisplayed(TestTags.INVENTORY_LIST_VIEW)
        compose.node(TestTags.BACK_BUTTON).performClick()
        compose.awaitDisplayed(TestTags.DASHBOARD_VIEW)

        // Hero band → home photo editor (UI-004 AC3).
        compose.node(TestTags.HOME_PHOTO_HERO).performClick()
        compose.awaitDisplayed(TestTags.HOME_PHOTO_VIEW)
        compose.node(TestTags.BACK_BUTTON).performClick()
        compose.awaitDisplayed(TestTags.DASHBOARD_VIEW)

        // Shopping section "Open list" → List tab.
        compose.node(TestTags.DASHBOARD_VIEW).performScrollToNode(hasTestTag(TestTags.OPEN_LIST_BUTTON))
        compose.awaitTag(TestTags.OPEN_LIST_BUTTON).performClick()
        compose.awaitDisplayed(TestTags.SHOPPING_LIST_VIEW)
    }

    @Test
    fun visual_semanticStructureMatchesBaseline() {
        compose.setApp(UiHarness.demoSession())
        compose.awaitDisplayed(TestTags.DASHBOARD_VIEW)

        // Baseline reading order: eyebrow → hero → two stat cards → sections → pill nav.
        compose.onNodeWithText("Offline preview").assertIsDisplayed()
        // "Low stock" is both the stat label and the section heading.
        compose.onAllNodesWithText("Low stock").assertCountEquals(2)
        compose.onAllNodesWithText("Spend").onFirst().assertIsDisplayed()
        compose.onAllNodesWithText("See inventory").assertCountEquals(1)
        // Demo fixtures seed two low-stock rows (Diet Coke 2/3, Whole Milk 1/2) as inventory rows.
        compose.nodes(TestTags.itemCell(UiHarness.DIET_COKE_ID)).onFirst().assertIsDisplayed()
        compose.nodes(TestTags.itemCell(UiHarness.WHOLE_MILK_ID)).onFirst().assertIsDisplayed()
        compose.node(TestTags.BOTTOM_NAV_BAR).assertIsDisplayed()
    }
}
