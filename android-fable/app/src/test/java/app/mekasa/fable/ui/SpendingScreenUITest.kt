package app.mekasa.fable.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.mekasa.fable.support.UiHarness
import app.mekasa.fable.support.UiHarness.awaitDisplayed
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
 * Verifies: REQ-017 (household spending) / Design: design/baselines/android/Spending_baseline.png
 *
 * Structural (Layer 1) checks for the Spend tab: period toggle, total card and category bars
 * fed by the demo report (week 86.42, month ×4.2, year ×49).
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = UiHarness.DEVICE)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class SpendingScreenUITest {
    @get:Rule
    val compose = createComposeRule()

    @Before
    fun setUp() = UiHarness.installFakeImageLoader()

    @Test
    fun layout_keyComposablesVisible() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.SPEND)

        compose.awaitDisplayed(TestTags.SPENDING_VIEW)
        compose.onNodeWithText("Spending").assertIsDisplayed()
        compose.onNodeWithText("HOUSEHOLD TOTAL").assertIsDisplayed()
        compose.node(TestTags.PERIOD_TOGGLE).assertIsDisplayed()
        listOf("week", "month", "year").forEach { compose.node(TestTags.period(it)).assertIsDisplayed() }
        compose.awaitDisplayed(TestTags.SPENDING_TOTAL)
        compose.onNodeWithText("BY CATEGORY").assertIsDisplayed()
        compose.onNodeWithText("Groceries").assertIsDisplayed()
        compose.onNodeWithText("Beverages").assertIsDisplayed()
        compose.onNodeWithText("Household").assertIsDisplayed()
        compose.node(TestTags.SPENDING_EMPTY).assertDoesNotExist()
        compose.node(TestTags.BOTTOM_NAV_BAR).assertIsDisplayed()
    }

    @Test
    fun interaction_tapsInputsAndNavigationTriggers() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.SPEND)
        compose.awaitDisplayed(TestTags.SPENDING_TOTAL)
        compose.onNodeWithText("THIS WEEK").assertIsDisplayed()
        compose.onNodeWithText("$86.42").assertIsDisplayed()

        // Switching period re-queries the report through the ViewModel.
        compose.node(TestTags.period("month")).performClick()
        compose.waitUntil(UiHarness.WAIT_MS) { compose.onAllNodes(hasText("THIS MONTH")).fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithText("$362.96").assertIsDisplayed()

        compose.node(TestTags.period("year")).performClick()
        compose.waitUntil(UiHarness.WAIT_MS) { compose.onAllNodes(hasText("THIS YEAR")).fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithText("$4,234.58").assertIsDisplayed()
    }

    @Test
    fun flow_navigatesToNextScreen() {
        compose.setApp(UiHarness.demoSession())
        compose.awaitDisplayed(TestTags.DASHBOARD_VIEW)

        // Spend tab via the pill nav; the dashboard stat card suffix matches the selected period.
        compose.node(TestTags.SPEND_TAB).performClick()
        compose.awaitDisplayed(TestTags.SPENDING_VIEW)
        compose.node(TestTags.period("month")).performClick()
        compose.waitUntil(UiHarness.WAIT_MS) { compose.onAllNodes(hasText("THIS MONTH")).fetchSemanticsNodes().isNotEmpty() }

        compose.node(TestTags.HOME_TAB).performClick()
        compose.awaitDisplayed(TestTags.DASHBOARD_VIEW)
        compose.onNodeWithText("/mo").assertIsDisplayed()
    }

    @Test
    fun visual_semanticStructureMatchesBaseline() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.SPEND)
        compose.awaitDisplayed(TestTags.SPENDING_TOTAL)

        // Baseline: header → pill toggle → hero total card → three category bars with share captions.
        compose.onNodeWithText("3 categories · USD").assertIsDisplayed()
        compose.onNodeWithText("$54.10").assertIsDisplayed()
        compose.onNodeWithText("$18.20").assertIsDisplayed()
        compose.onNodeWithText("$14.12").assertIsDisplayed()
        compose.onNodeWithText("62% of total").assertIsDisplayed()
        compose.onNodeWithText("21% of total").assertIsDisplayed()
        compose.onNodeWithText("16% of total").assertIsDisplayed()
    }
}
