package app.mekasa.fable.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
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
 * Verifies: UI-005 / AC1–AC3, REQ-010 / Design: design/baselines/android/TrashStation_baseline.png
 *
 * Structural (Layer 1) checks for the trash station in both shapes: the pushed "Dispose"
 * route inside the shell and the full-screen kiosk that replaces the shell. Robolectric has
 * no camera, so the scanner renders its permission fallback ("Allow camera") and consumption
 * is exercised through the manual UPC field, which shares the same `consume()` path.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = UiHarness.DEVICE)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class TrashStationModeUITest {
    @get:Rule
    val compose = createComposeRule()

    @Before
    fun setUp() = UiHarness.installFakeImageLoader()

    @Test
    fun layout_keyComposablesVisible() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.TRASH)

        compose.awaitDisplayed(TestTags.TRASH_STATION_VIEW)
        compose.onNodeWithText("Dispose").assertIsDisplayed()
        compose.onNodeWithText("USE ONE BY BARCODE").assertIsDisplayed()
        compose.node(TestTags.BACK_BUTTON).assertIsDisplayed()
        compose.node(TestTags.BARCODE_SCANNER).assertIsDisplayed()
        compose.node(TestTags.ALLOW_CAMERA).assertIsDisplayed()
        compose.node(TestTags.MANUAL_BARCODE).assertIsDisplayed()
        compose.node(TestTags.MANUAL_CONSUME).assertIsDisplayed().assertIsNotEnabled()
        compose.onNodeWithText("In stock").assertIsDisplayed()
        compose.node(TestTags.trashUse(UiHarness.DIET_COKE_ID)).assertIsDisplayed()
        // Not kiosk: no "Exit kiosk" link, and the pushed route hides the tab pill.
        compose.node(TestTags.EXIT_KIOSK).assertDoesNotExist()
        compose.node(TestTags.BOTTOM_NAV_BAR).assertDoesNotExist()
    }

    @Test
    fun interaction_tapsInputsAndNavigationTriggers() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.TRASH)
        compose.awaitDisplayed(TestTags.TRASH_STATION_VIEW)

        // Typing a UPC arms the button; consuming Diet Coke (qty 2) flashes "Used 1 … 1 left".
        compose.node(TestTags.MANUAL_BARCODE).performTextInput(DemoBackend.DIET_COKE_UPC)
        compose.node(TestTags.MANUAL_CONSUME).assertIsEnabled().performClick()
        compose.awaitDisplayed(TestTags.SCAN_FLASH)
        compose.onNodeWithText("Used 1 Diet Coke · 1 left").assertIsDisplayed()
        compose.onNodeWithText("qty 1 · ${DemoBackend.DIET_COKE_UPC}").assertIsDisplayed()

        // Unknown code is logged (REQ-010 AC2) and listed under "Unknown scans".
        compose.node(TestTags.MANUAL_BARCODE).performTextInput("000000000000")
        compose.node(TestTags.MANUAL_CONSUME).performClick()
        compose.waitUntil(UiHarness.WAIT_MS) {
            compose.onAllNodes(hasText("Unknown barcode 000000000000 logged")).fetchSemanticsNodes().isNotEmpty()
        }
    }

    @Test
    fun flow_navigatesToNextScreen() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.FAMILY)
        compose.awaitDisplayed(TestTags.FAMILY_VIEW)

        // Family → "Trash station kiosk" swaps the whole shell for the kiosk (UI-005 AC1).
        compose.node(TestTags.OPEN_KIOSK).performClick()
        compose.awaitDisplayed(TestTags.TRASH_KIOSK_VIEW)
        compose.onNodeWithText("Trash station").assertIsDisplayed()
        compose.onNodeWithText("SCAN BEFORE YOU TOSS").assertIsDisplayed()
        compose.node(TestTags.EXIT_KIOSK).assertIsDisplayed()
        compose.node(TestTags.MAIN_SHELL_VIEW).assertDoesNotExist()
        compose.node(TestTags.BACK_BUTTON).assertDoesNotExist()
        // Kiosk hides the in-stock list: only scan + manual entry remain (UI-005 AC2).
        compose.onNodeWithText("In stock").assertDoesNotExist()

        // Exit kiosk returns to the shell.
        compose.node(TestTags.EXIT_KIOSK).performClick()
        compose.awaitDisplayed(TestTags.MAIN_SHELL_VIEW)
        compose.awaitGone(TestTags.TRASH_KIOSK_VIEW)
    }

    @Test
    fun visual_semanticStructureMatchesBaseline() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.TRASH)
        compose.awaitDisplayed(TestTags.TRASH_STATION_VIEW)

        // Baseline: header → charcoal scanner well (permission fallback) → UPC field + CTA → in-stock rows.
        compose.onNodeWithText("Camera access lets you scan barcodes live.").assertIsDisplayed()
        compose.onNodeWithText("Allow camera").assertIsDisplayed()
        compose.onNodeWithText("Use 1 by barcode").assertIsDisplayed()
        listOf(UiHarness.DIET_COKE_ID, UiHarness.WHOLE_MILK_ID, UiHarness.SOURDOUGH_ID)
            .forEach { compose.node(TestTags.trashUse(it)).assertIsDisplayed() }

        // The in-stock Use 1 link drops Whole Milk (qty 1) to zero and out of the in-stock list (UI-005 AC3).
        compose.node(TestTags.trashUse(UiHarness.WHOLE_MILK_ID)).performClick()
        compose.awaitGone(TestTags.trashUse(UiHarness.WHOLE_MILK_ID))
    }
}
