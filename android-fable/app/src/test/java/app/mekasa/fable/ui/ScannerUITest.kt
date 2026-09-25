package app.mekasa.fable.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.mekasa.fable.data.demo.DemoBackend
import app.mekasa.fable.support.UiHarness
import app.mekasa.fable.support.UiHarness.awaitDisplayed
import app.mekasa.fable.support.UiHarness.awaitGone
import app.mekasa.fable.support.UiHarness.node
import app.mekasa.fable.support.UiHarness.setApp
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Verifies: REQ-004 (barcode add), REQ-006 (unknown barcode) / Design: design/baselines/android/AddItems_baseline.png,
 * Scanner_baseline.png
 *
 * Structural (Layer 1) checks for the Add Items sheet and its "Scan a barcode" step. The JVM
 * has no camera, so the live preview is never started: the test asserts the permission
 * fallback UI and drives lookups through the manual UPC field, which feeds the same
 * `lookup()` the scanner callback uses.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = UiHarness.DEVICE)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ScannerUITest {
    @get:Rule
    val compose = createComposeRule()

    @Before
    fun setUp() = UiHarness.installFakeImageLoader()

    private fun openScanner() {
        compose.setApp(UiHarness.demoSession())
        compose.awaitDisplayed(TestTags.DASHBOARD_VIEW)
        compose.node(TestTags.ADD_ITEM_BUTTON).performClick()
        compose.awaitDisplayed(TestTags.ADD_ITEMS_HUB)
        compose.node(TestTags.ADD_BARCODE).performClick()
        compose.awaitDisplayed(TestTags.BARCODE_SCANNER)
    }

    @Test
    fun layout_keyComposablesVisible() {
        compose.setApp(UiHarness.demoSession())
        compose.awaitDisplayed(TestTags.DASHBOARD_VIEW)
        compose.node(TestTags.ADD_ITEM_BUTTON).performClick()

        // Hub: four entry points plus the trash-station shortcut.
        compose.awaitDisplayed(TestTags.ADD_ITEMS_HUB)
        compose.onNodeWithText("Add items").assertIsDisplayed()
        compose.node(TestTags.ADD_BARCODE).assertIsDisplayed()
        compose.node(TestTags.ADD_SEARCH).assertIsDisplayed()
        compose.node(TestTags.ADD_VOICE).assertIsDisplayed()
        compose.node(TestTags.ADD_RECEIPT).assertIsDisplayed()
        compose.node(TestTags.ADD_TRASH).assertIsDisplayed()
        compose.node(TestTags.ADD_BACK).assertDoesNotExist()

        // Barcode step: scanner well with permission fallback, manual UPC field, disabled Look up.
        compose.node(TestTags.ADD_BARCODE).performClick()
        compose.awaitDisplayed(TestTags.BARCODE_SCANNER)
        compose.onNodeWithText("Scan a barcode").assertIsDisplayed()
        compose.node(TestTags.ALLOW_CAMERA).assertIsDisplayed()
        compose.onNodeWithText("Camera access lets you scan barcodes live.").assertIsDisplayed()
        compose.onNodeWithText("Preview mode: try the Diet Coke UPC ${DemoBackend.DIET_COKE_UPC}.").assertIsDisplayed()
        compose.node(TestTags.MANUAL_BARCODE).assertIsDisplayed()
        compose.node(TestTags.LOOKUP_BARCODE).assertIsDisplayed().assertIsNotEnabled()
        compose.node(TestTags.ADD_BACK).assertIsDisplayed()
    }

    @Test
    fun interaction_tapsInputsAndNavigationTriggers() {
        openScanner()

        // Short codes keep the button disabled; a full UPC enables it.
        compose.node(TestTags.MANUAL_BARCODE).performTextInput("0490")
        compose.node(TestTags.LOOKUP_BARCODE).assertIsNotEnabled()
        compose.node(TestTags.MANUAL_BARCODE).performTextInput("00028911")
        compose.node(TestTags.MANUAL_BARCODE).assertTextContains(DemoBackend.DIET_COKE_UPC)
        compose.node(TestTags.LOOKUP_BARCODE).assertIsEnabled()

        // Back arrow returns to the hub.
        compose.node(TestTags.ADD_BACK).performClick()
        compose.awaitDisplayed(TestTags.ADD_SEARCH)
        compose.node(TestTags.BARCODE_SCANNER).assertDoesNotExist()
    }

    @Test
    fun flow_navigatesToNextScreen() {
        openScanner()

        // Known UPC → confirm step pre-filled from the catalog hit (REQ-004 AC2).
        compose.node(TestTags.MANUAL_BARCODE).performTextInput(DemoBackend.DIET_COKE_UPC)
        compose.node(TestTags.LOOKUP_BARCODE).performClick()
        compose.awaitDisplayed(TestTags.CONFIRM_NAME)
        compose.onNodeWithText("Confirm item").assertIsDisplayed()
        compose.node(TestTags.CONFIRM_NAME).assertTextContains("Coca-Cola Diet Coke")
        compose.node(TestTags.CONFIRM_CATEGORY).assertTextContains("Beverages")
        compose.node(TestTags.QTY_VALUE).assertTextContains("1")
        compose.node(TestTags.QTY_PLUS).performClick()
        compose.node(TestTags.QTY_VALUE).assertTextContains("2")

        // Saving adds to inventory through the ViewModel and closes the sheet; the new row
        // surfaces under "Recently added" on the dashboard.
        compose.node(TestTags.SAVE_ITEM).performClick()
        compose.awaitGone(TestTags.ADD_ITEMS_HUB)
        compose.node(TestTags.DASHBOARD_VIEW).performScrollToNode(hasText("Coca-Cola Diet Coke"))
        compose.onNodeWithText("Coca-Cola Diet Coke").assertIsDisplayed()
    }

    @Test
    fun visual_semanticStructureMatchesBaseline() {
        openScanner()

        // Unknown UPC → warning card with "Add manually" (REQ-006 AC1), leading to an empty-name confirm.
        compose.node(TestTags.MANUAL_BARCODE).performTextInput("000000000000")
        compose.node(TestTags.LOOKUP_BARCODE).performClick()
        compose.awaitDisplayed(TestTags.ADD_UNKNOWN_BARCODE)
        compose.onNodeWithText("No product matched 000000000000").assertIsDisplayed()
        compose.onNodeWithText("You can still add it by name.").assertIsDisplayed()

        compose.node(TestTags.ADD_UNKNOWN_BARCODE).performClick()
        compose.awaitDisplayed(TestTags.CONFIRM_NAME)
        compose.node(TestTags.SAVE_ITEM).assertIsNotEnabled()
        compose.node(TestTags.CONFIRM_NAME).performTextInput("Mystery snack")
        compose.node(TestTags.SAVE_ITEM).assertIsEnabled()
    }
}
