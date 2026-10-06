package app.mekasa.fable.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.mekasa.fable.support.UiHarness
import app.mekasa.fable.support.UiHarness.awaitDisplayed
import app.mekasa.fable.support.UiHarness.awaitGone
import app.mekasa.fable.support.UiHarness.node
import app.mekasa.fable.support.UiHarness.setApp
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Verifies: REQ-RCP-020 AC6, AC15 / Design: design/pages/scan-photo-only.html
 *
 * Receipt review: an unidentified line opens the capture panel, a typed code is
 * validated and saved onto the line, and saving the haul links the item. The JVM has
 * no camera or photo picker, so the photo path is covered by ReceiptCaptureTest.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = UiHarness.DEVICE)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ReceiptCaptureUITest {
    @get:Rule
    val compose = createComposeRule()

    @Before
    fun setUp() = UiHarness.installFakeImageLoader()

    @Test
    fun unidentifiedLine_takesCodeAndSavesWithIt() {
        val session = UiHarness.demoSession()
        compose.setApp(session)
        compose.awaitDisplayed(TestTags.DASHBOARD_VIEW)
        compose.node(TestTags.ADD_ITEM_BUTTON).performClick()
        compose.awaitDisplayed(TestTags.ADD_ITEMS_HUB)
        compose.node(TestTags.ADD_RECEIPT).performClick()
        compose.awaitDisplayed(TestTags.SAMPLE_RECEIPT).performClick()
        compose.node(TestTags.SCAN_RECEIPT).performClick()

        compose.awaitDisplayed(TestTags.receiptLine(2))
        compose.node(TestTags.receiptLineCapture(0)).assertDoesNotExist()
        compose.node(TestTags.receiptLineCapture(2)).performScrollTo().performClick()

        compose.awaitDisplayed(TestTags.CAPTURE_CODE_FIELD)
        compose.node(TestTags.CAPTURE_SAVE).assertIsNotEnabled()
        compose.node(TestTags.CAPTURE_CODE_FIELD).performTextInput("123")
        compose.onNodeWithText("Barcodes have 8–14 digits. Produce PLUs have 4 or 5.").assertIsDisplayed()
        compose.node(TestTags.CAPTURE_SAVE).assertIsNotEnabled()
        compose.node(TestTags.CAPTURE_CODE_FIELD).performTextInput("45678905")
        compose.node(TestTags.CAPTURE_SAVE).performScrollTo().assertIsEnabled().performClick()

        compose.awaitGone(TestTags.CAPTURE_CODE_FIELD)
        compose.onNodeWithText("×1 · Bakery · \$4.99 · 12345678905", substring = true).assertIsDisplayed()
        compose.node(TestTags.SAVE_RECEIPT).performClick()

        compose.awaitGone(TestTags.ADD_ITEMS_HUB)
        val saved = session.state.value.data.inventory.first { it.name == "Sourdough Loaf" }
        assertEquals("12345678905", saved.barcode)
        assertEquals("12345678905", saved.productId)
    }
}
