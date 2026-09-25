package app.mekasa.fable.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.hasAnyAncestor
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.mekasa.fable.data.demo.DemoBackend
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
 * Verifies: UI-006 / AC2–AC5, REQ-009 (quantity & threshold edits) / Design: design/baselines/android/ItemDetail_baseline.png
 *
 * Structural (Layer 1) checks for the item detail: large product image (tap → lightbox),
 * metadata chips, UPC, last price, and the two steppers that PATCH through the ViewModel.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = UiHarness.DEVICE)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ItemDetailUITest {
    @get:Rule
    val compose = createComposeRule()

    @Before
    fun setUp() = UiHarness.installFakeImageLoader()

    /** The stepper's big number lives inside the tagged card next to a label, so scope the text match. */
    private fun awaitStepperValue(tag: String, value: Int) {
        compose.waitUntil(UiHarness.WAIT_MS) {
            compose.onAllNodes(hasText(value.toString()) and hasAnyAncestor(hasTestTag(tag)), useUnmergedTree = true)
                .fetchSemanticsNodes().isNotEmpty()
        }
    }

    @Test
    fun layout_keyComposablesVisible() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.item(UiHarness.DIET_COKE_ID))

        compose.awaitDisplayed(TestTags.ITEM_DETAIL_VIEW)
        compose.node(TestTags.BACK_BUTTON).assertIsDisplayed()
        compose.onNodeWithText("Item").assertIsDisplayed()
        compose.onNodeWithText("BEVERAGES").assertIsDisplayed()
        compose.node(TestTags.ITEM_IMAGE).assertIsDisplayed()
        compose.onNodeWithText("Diet Coke").assertIsDisplayed()
        compose.onNodeWithText("Beverages").assertIsDisplayed()
        compose.onNodeWithText("Low stock").assertIsDisplayed()
        compose.onNodeWithText("barcode").assertIsDisplayed()
        compose.onNodeWithText("UPC").assertIsDisplayed()
        compose.onNodeWithText(DemoBackend.DIET_COKE_UPC).assertIsDisplayed()
        compose.node(TestTags.QUANTITY_CONTROL).performScrollTo().assertIsDisplayed()
        compose.node(TestTags.THRESHOLD_CONTROL).performScrollTo().assertIsDisplayed()
        compose.node(TestTags.ITEM_LIGHTBOX).assertDoesNotExist()
    }

    @Test
    fun interaction_tapsInputsAndNavigationTriggers() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.item(UiHarness.DIET_COKE_ID))
        compose.awaitDisplayed(TestTags.ITEM_DETAIL_VIEW)

        // Quantity stepper PATCHes through the ViewModel: 2 → 3 → 2.
        compose.node(TestTags.QUANTITY_CONTROL).performScrollTo()
        compose.onNodeWithContentDescription("Increase Quantity").performClick()
        awaitStepperValue(TestTags.QUANTITY_CONTROL, 3)
        compose.onNodeWithContentDescription("Decrease Quantity").performClick()
        awaitStepperValue(TestTags.QUANTITY_CONTROL, 2)

        // Threshold 3 → 1 flips the low-stock flag off (qty 2 > 1) and updates the caption.
        compose.node(TestTags.THRESHOLD_CONTROL).performScrollTo()
        compose.onNodeWithContentDescription("Decrease Low-stock threshold").performClick()
        compose.onNodeWithContentDescription("Decrease Low-stock threshold").performClick()
        compose.waitUntil(UiHarness.WAIT_MS) {
            compose.onAllNodes(hasText("When quantity drops to 1 it will be flagged as low stock.")).fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithText("Low stock").assertDoesNotExist()
    }

    @Test
    fun flow_navigatesToNextScreen() {
        compose.setApp(UiHarness.demoSession())
        compose.awaitDisplayed(TestTags.DASHBOARD_VIEW)

        // Dashboard low-stock row → detail → back to the dashboard (UI-006 AC2).
        compose.node(TestTags.itemCell(UiHarness.WHOLE_MILK_ID)).performClick()
        compose.awaitDisplayed(TestTags.ITEM_DETAIL_VIEW)
        compose.onNodeWithText("Whole Milk").assertIsDisplayed()
        compose.onNodeWithText("LAST PRICE PAID").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("$3.49").assertIsDisplayed()
        compose.node(TestTags.BACK_BUTTON).performClick()
        compose.awaitDisplayed(TestTags.DASHBOARD_VIEW)
        compose.awaitGone(TestTags.ITEM_DETAIL_VIEW)
    }

    @Test
    fun visual_semanticStructureMatchesBaseline() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.item(UiHarness.DIET_COKE_ID))
        compose.awaitDisplayed(TestTags.ITEM_DETAIL_VIEW)

        // Baseline: hero image card → title → chips → UPC → steppers → explanatory caption.
        compose.onNodeWithText("At or below the threshold", substring = true).performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("QUANTITY").assertIsDisplayed()
        compose.onNodeWithText("LOW-STOCK THRESHOLD").assertIsDisplayed()
        // Decrease is disabled at zero: drive threshold to 0 and check the button state.
        repeat(3) { compose.onNodeWithContentDescription("Decrease Low-stock threshold").performClick() }
        awaitStepperValue(TestTags.THRESHOLD_CONTROL, 0)
        compose.onNodeWithContentDescription("Decrease Low-stock threshold").assertIsNotEnabled()

        // The image card opens the full-screen lightbox (UI-006 AC3) and tapping it closes it.
        compose.node(TestTags.ITEM_IMAGE).performScrollTo().performClick()
        compose.awaitDisplayed(TestTags.ITEM_LIGHTBOX)
        compose.node(TestTags.ITEM_LIGHTBOX).performClick()
        compose.awaitGone(TestTags.ITEM_LIGHTBOX)
    }
}
