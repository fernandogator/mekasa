package app.mekasa.fable.ui

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeLeft
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.mekasa.fable.support.UiHarness
import app.mekasa.fable.support.UiHarness.awaitDisplayed
import app.mekasa.fable.support.UiHarness.node
import app.mekasa.fable.support.UiHarness.setApp
import app.mekasa.fable.ui.home.Routes
import com.github.takahirom.roborazzi.RoborazziOptions
import com.github.takahirom.roborazzi.RoborazziRule
import com.github.takahirom.roborazzi.ThresholdValidator
import com.github.takahirom.roborazzi.captureRoboImage
import com.github.takahirom.roborazzi.captureScreenRoboImage
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Verifies: UI-001, UI-003, UI-004, UI-005, UI-006 / Design: design/baselines/android/<Screen>_baseline.png
 *
 * Layer 2 snapshot baselines. Every screen state asserted structurally in the `*UITest`
 * files is rendered once here on a fixed Pixel-7-class device with the demo fixtures and
 * compared against `design/baselines/android/<Screen>_baseline.png`.
 *
 *   ./gradlew :app:recordRoborazziDebug   # (re)write the baselines
 *   ./gradlew :app:verifyRoborazziDebug   # compare; diffs land in app/build/outputs/roborazzi
 *
 * Comparison is semantic (design/baselines/README.md): a 15% pixel-change threshold, so text
 * and data drift pass while layout, hierarchy or palette changes fail.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = UiHarness.DEVICE)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ScreenSnapshotTest {
    @get:Rule
    val compose = createComposeRule()

    @get:Rule
    val roborazzi = RoborazziRule(
        composeRule = compose,
        captureRoot = compose.onRoot(),
        options = RoborazziRule.Options(roborazziOptions = OPTIONS),
    )

    @Before
    fun setUp() = UiHarness.installFakeImageLoader()

    private fun snapshot(name: String) {
        compose.waitForIdle()
        compose.onRoot().captureRoboImage("${name}_baseline.png", roborazziOptions = OPTIONS)
    }

    /** For states with more than one window (bottom sheet, dialog) capture the whole screen. */
    private fun screenSnapshot(name: String) {
        compose.waitForIdle()
        captureScreenRoboImage("${name}_baseline.png", roborazziOptions = OPTIONS)
    }

    // ------------------------------------------------------------ UI-001 / UI-003

    @Test
    fun welcome() {
        compose.setApp(UiHarness.signedOutSession())
        compose.awaitDisplayed(TestTags.WELCOME_VIEW)
        snapshot("Welcome")
    }

    @Test
    fun householdName() {
        compose.setApp(UiHarness.onboardingSession())
        compose.awaitDisplayed(TestTags.HOUSEHOLD_NAME_VIEW)
        snapshot("HouseholdName")
    }

    @Test
    fun address() {
        compose.setApp(UiHarness.onboardingSession())
        compose.awaitDisplayed(TestTags.HOUSEHOLD_NAME_VIEW)
        compose.node(TestTags.HOUSEHOLD_CONTINUE).performClick()
        compose.awaitDisplayed(TestTags.ADDRESS_VIEW)
        snapshot("Address")
    }

    @Test
    fun storeSelection() {
        val session = UiHarness.onboardingSession()
        compose.setApp(session)
        compose.awaitDisplayed(TestTags.HOUSEHOLD_NAME_VIEW)
        session.createHousehold("The Guerrero Home")
        compose.awaitDisplayed(TestTags.ADDRESS_VIEW)
        session.saveAddress("123 Peachtree St, Atlanta, GA")
        compose.awaitDisplayed(TestTags.STORE_SELECTION_VIEW)
        snapshot("StoreSelection")
    }

    // ------------------------------------------------------------ UI-004

    @Test
    fun dashboard() {
        compose.setApp(UiHarness.demoSession())
        compose.awaitDisplayed(TestTags.DASHBOARD_VIEW)
        compose.awaitDisplayed(TestTags.itemCell(UiHarness.DIET_COKE_ID))
        snapshot("Dashboard")
    }

    // ------------------------------------------------------------ UI-006

    @Test
    fun inventoryList() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.INVENTORY)
        compose.awaitDisplayed(TestTags.ITEM_LIST)
        snapshot("InventoryList")
    }

    @Test
    fun inventorySwipeUseOne() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.INVENTORY)
        compose.awaitDisplayed(TestTags.itemCell(UiHarness.DIET_COKE_ID))
        // Hold the row part-way through a trailing swipe so the accent "Use 1" pane is revealed (REQ-INV-014).
        compose.node(TestTags.itemCell(UiHarness.DIET_COKE_ID)).performTouchInput {
            down(centerRight)
            moveBy(Offset(-width * 0.35f, 0f))
        }
        snapshot("InventorySwipeUseOne")
        compose.node(TestTags.itemCell(UiHarness.DIET_COKE_ID)).performTouchInput { up() }
    }

    @Test
    fun inventorySwipeRemove() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.INVENTORY)
        compose.awaitDisplayed(TestTags.itemCell(UiHarness.WHOLE_MILK_ID))
        // Qty 1 row: the same gesture reveals the trash + "Remove" pane (REQ-INV-015).
        compose.node(TestTags.itemCell(UiHarness.WHOLE_MILK_ID)).performTouchInput {
            down(centerRight)
            moveBy(Offset(-width * 0.35f, 0f))
        }
        snapshot("InventorySwipeRemove")
        compose.node(TestTags.itemCell(UiHarness.WHOLE_MILK_ID)).performTouchInput { up() }
    }

    @Test
    fun inventoryUndoToast() {
        compose.setApp(UiHarness.demoSession(undoWindowMillis = 60_000), startRoute = Routes.INVENTORY)
        compose.awaitDisplayed(TestTags.itemCell(UiHarness.WHOLE_MILK_ID))
        compose.node(TestTags.itemCell(UiHarness.WHOLE_MILK_ID)).performTouchInput { swipeLeft() }
        compose.awaitDisplayed(TestTags.INVENTORY_UNDO_TOAST)
        snapshot("InventoryUndoToast")
    }

    @Test
    fun itemDetail() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.item(UiHarness.DIET_COKE_ID))
        compose.awaitDisplayed(TestTags.ITEM_DETAIL_VIEW)
        snapshot("ItemDetail")
    }

    // ------------------------------------------------------------ tabs

    @Test
    fun shoppingList() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.LIST)
        compose.awaitDisplayed(TestTags.shoppingRow(UiHarness.AUTO_SHOPPING_ID))
        snapshot("ShoppingList")
    }

    @Test
    fun spending() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.SPEND)
        compose.awaitDisplayed(TestTags.SPENDING_TOTAL)
        snapshot("Spending")
    }

    @Test
    fun family() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.FAMILY)
        compose.awaitDisplayed(TestTags.member("demo-kid"))
        snapshot("Family")
    }

    // ------------------------------------------------------------ UI-005

    @Test
    fun trashStation() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.TRASH)
        compose.awaitDisplayed(TestTags.trashUse(UiHarness.DIET_COKE_ID))
        snapshot("TrashStation")
    }

    // ------------------------------------------------------------ add items

    @Test
    fun addItems() {
        compose.setApp(UiHarness.demoSession())
        compose.awaitDisplayed(TestTags.DASHBOARD_VIEW)
        compose.node(TestTags.ADD_ITEM_BUTTON).performClick()
        compose.awaitDisplayed(TestTags.ADD_TRASH)
        screenSnapshot("AddItems")
    }

    @Test
    fun scanner() {
        compose.setApp(UiHarness.demoSession())
        compose.awaitDisplayed(TestTags.DASHBOARD_VIEW)
        compose.node(TestTags.ADD_ITEM_BUTTON).performClick()
        compose.awaitDisplayed(TestTags.ADD_BARCODE)
        compose.node(TestTags.ADD_BARCODE).performClick()
        compose.awaitDisplayed(TestTags.LOOKUP_BARCODE)
        screenSnapshot("Scanner")
    }

    private companion object {
        /** design/baselines/README.md: 15% tolerance, structural drift only. */
        val OPTIONS = RoborazziOptions(
            compareOptions = RoborazziOptions.CompareOptions(resultValidator = ThresholdValidator(0.15f)),
        )
    }
}
