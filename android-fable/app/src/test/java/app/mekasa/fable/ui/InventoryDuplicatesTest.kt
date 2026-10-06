package app.mekasa.fable.ui

import android.content.Context
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.mekasa.fable.data.DismissedDuplicates
import app.mekasa.fable.data.InventoryDraft
import app.mekasa.fable.data.InventoryDuplicates
import app.mekasa.fable.data.model.DuplicateGroup
import app.mekasa.fable.data.model.DuplicateReason
import app.mekasa.fable.data.model.InventoryItem
import app.mekasa.fable.session.SessionViewModel
import app.mekasa.fable.support.UiHarness
import app.mekasa.fable.support.UiHarness.awaitDisplayed
import app.mekasa.fable.support.UiHarness.awaitGone
import app.mekasa.fable.support.UiHarness.node
import app.mekasa.fable.support.UiHarness.setApp
import app.mekasa.fable.ui.home.Routes
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Instant
import java.time.ZoneOffset

/**
 * Verifies: REQ-INV-021 AC1–AC7 / Design: design/pages/inventory-duplicates.html
 *
 * The shared rules (names, groups, survivor, merge, copy, "Not duplicates") and the
 * Duplicates review driven through the offline-preview session.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = UiHarness.DEVICE)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class InventoryDuplicatesTest {
    @get:Rule
    val compose = createComposeRule()

    @Before
    fun setUp() = UiHarness.installFakeImageLoader()

    private fun item(
        id: String,
        name: String,
        category: String = "Produce",
        quantity: Int = 1,
        threshold: Int = 1,
        barcode: String? = null,
        productId: String? = null,
        imageUrl: String? = null,
        imageUpdatedAt: String? = null,
        updatedAt: String = "2026-09-01T00:00:00Z",
        pricePaid: Double? = null,
    ) = InventoryItem(
        id = id, householdId = "hh-1", name = name, category = category, quantity = quantity,
        lowStockThreshold = threshold, barcode = barcode, productId = productId, imageUrl = imageUrl,
        imageUpdatedAt = imageUpdatedAt, updatedAt = updatedAt, pricePaid = pricePaid,
    )

    // ---------------------------------------------------------------- AC1

    @Test
    fun dedupeName_exactAndSimplePlurals() {
        val cases = mapOf(
            "Organic Bananas" to "organic banana",
            "  ORGANIC   banana! " to "organic banana",
            "Berries" to "berry",
            "Boxes" to "box",
            "Tomatoes" to "tomato",
            "Peaches" to "peach",
            "Jalapeño" to "jalapeno",
            "Hummus" to "hummus",
            "Glass" to "glass",
            "Eggs" to "egg",
            "Gas" to "gas",
        )
        cases.forEach { (input, expected) -> assertEquals(input, expected, InventoryDuplicates.dedupeName(input)) }
    }

    @Test
    fun findGroups_sameNameNeedsSameCategory() {
        val groups = InventoryDuplicates.findGroups(
            listOf(item("a", "Banana"), item("b", "Bananas"), item("c", "Bananas", category = "Pantry")),
        )
        assertEquals(1, groups.size)
        assertEquals(DuplicateReason.SameName, groups[0].reason)
        assertEquals(setOf("a", "b"), groups[0].items.map { it.id }.toSet())
    }

    @Test
    fun findGroups_chainsLinksAndUsesStrongestReason() {
        val groups = InventoryDuplicates.findGroups(
            listOf(
                item("a", "Oat Milk", category = "Dairy", barcode = "0123"),
                item("b", "Whole Milk", category = "Dairy", barcode = "0123"),
                item("c", "Whole Milk", category = "Dairy"),
                item("d", "Bread", category = "Pantry"),
            ),
        )
        assertEquals(1, groups.size)
        assertEquals(DuplicateReason.SameBarcode, groups[0].reason)
        assertEquals(setOf("a", "b", "c"), groups[0].items.map { it.id }.toSet())
    }

    @Test
    fun findGroups_sameProductAcrossCategories() {
        val groups = InventoryDuplicates.findGroups(
            listOf(
                item("a", "Sourdough", category = "Pantry", productId = "llm:abc"),
                item("b", "Sourdough Loaf", category = "Bakery", productId = "llm:abc"),
            ),
        )
        assertEquals(listOf(DuplicateReason.SameProduct), groups.map { it.reason })
        assertTrue(InventoryDuplicates.isOneGroup(groups[0].items))
        assertFalse(InventoryDuplicates.isOneGroup(listOf(item("a", "Apples"), item("b", "Pears"))))
    }

    // ---------------------------------------------------------------- AC2

    @Test
    fun survivor_newestRealPhotoWins() {
        val survivor = InventoryDuplicates.pickSurvivor(
            listOf(
                item("old", "Bananas", imageUrl = "https://x/old.jpg", imageUpdatedAt = "2026-09-01T00:00:00Z", updatedAt = "2026-09-10T00:00:00Z"),
                item("new", "Banana", imageUrl = "https://x/new.jpg", imageUpdatedAt = "2026-09-02T00:00:00.123456+00:00"),
                item("ph", "Bananas", imageUrl = "https://placehold.co/96x96?text=B", updatedAt = "2026-09-20T00:00:00Z"),
            ),
        )
        assertEquals("new", survivor?.id)
    }

    @Test
    fun survivor_withoutPhotos_mostRecentlyUpdatedWins() {
        val survivor = InventoryDuplicates.pickSurvivor(
            listOf(item("a", "Bananas"), item("b", "Bananas", updatedAt = "2026-09-02T00:00:00Z")),
        )
        assertEquals("b", survivor?.id)
    }

    @Test
    fun survivor_missingImageTimeFallsBackToUpdatedAt() {
        val survivor = InventoryDuplicates.pickSurvivor(
            listOf(
                item("a", "Bananas", imageUrl = "https://x/a.jpg", updatedAt = "2026-09-03T00:00:00Z"),
                item("b", "Bananas", imageUrl = "https://x/b.jpg", imageUpdatedAt = "2026-09-02T00:00:00Z", updatedAt = "2026-09-04T00:00:00Z"),
            ),
        )
        assertEquals("a", survivor?.id)
    }

    // ---------------------------------------------------------------- AC3

    @Test
    fun merged_keepsHigherValuesAndFillsGaps() {
        val group = DuplicateGroup(
            DuplicateReason.SameName,
            keepId = "a",
            items = listOf(
                item("a", "Organic Bananas", quantity = 2, threshold = 3, imageUrl = "https://x/a.jpg"),
                item("b", "Bananas", quantity = 5, barcode = "4011", productId = "plu:4011", pricePaid = 1.29),
            ),
        )
        val merged = InventoryDuplicates.merged(group)!!
        assertEquals("a", merged.id)
        assertEquals("Organic Bananas", merged.name)
        assertEquals(5, merged.quantity)
        assertEquals(3, merged.lowStockThreshold)
        assertEquals("4011", merged.barcode)
        assertEquals("plu:4011", merged.productId)
        assertEquals(1.29, merged.pricePaid!!, 0.0)
        assertEquals("https://x/a.jpg", merged.imageUrl)
    }

    @Test
    fun merged_survivorValuesAreNotOverwritten() {
        val group = DuplicateGroup(
            DuplicateReason.SameBarcode,
            keepId = "a",
            items = listOf(item("a", "Milk", barcode = "111", productId = "111"), item("b", "Milk", barcode = "111", productId = "222")),
        )
        assertEquals("111", InventoryDuplicates.merged(group)!!.productId)
    }

    // ---------------------------------------------------------------- AC5 copy

    @Test
    fun copy() {
        assertEquals("1 group found · review before merging", InventoryDuplicates.headline(1))
        assertEquals("2 groups found · review before merging", InventoryDuplicates.headline(2))
        assertEquals("Merged 2 items into Bananas", InventoryDuplicates.confirmation(2, "Bananas"))

        val withPhoto = DuplicateGroup(
            DuplicateReason.SameName,
            keepId = "a",
            items = listOf(item("a", "Bananas", imageUrl = "https://x/a.jpg"), item("b", "Banana", quantity = 3)),
        )
        val noPhoto = DuplicateGroup(DuplicateReason.SameName, "a", listOf(item("a", "Pears"), item("b", "Pear")))
        assertEquals("keeps qty 3 (higher) · newest photo", InventoryDuplicates.resultDetail(withPhoto))
        assertEquals("keeps qty 1 (higher)", InventoryDuplicates.resultDetail(noPhoto))

        assertNull(InventoryDuplicates.bulkConfirmation(emptyList()))
        assertEquals("Merged 2 items into Bananas", InventoryDuplicates.bulkConfirmation(listOf(withPhoto)))
        assertEquals("Merged 4 items into 2 items", InventoryDuplicates.bulkConfirmation(listOf(withPhoto, noPhoto)))
    }

    @Test
    fun photoAge() {
        val now = Instant.parse("2026-10-06T12:00:00Z")
        fun age(changed: String, url: String? = "https://x/a.jpg") =
            InventoryDuplicates.photoAge(item("a", "A", imageUrl = url, imageUpdatedAt = changed), now, ZoneOffset.UTC)
        assertEquals("Photo updated today", age("2026-10-06T01:00:00Z"))
        assertEquals("Photo updated yesterday", age("2026-10-05T23:00:00Z"))
        assertEquals("Photo updated 2 days ago", age("2026-10-04T12:00:00Z"))
        assertEquals("No photo", age("2026-10-06T01:00:00Z", url = null))
        assertEquals("No photo", age("2026-10-06T01:00:00Z", url = "https://placehold.co/96"))
    }

    // ---------------------------------------------------------------- AC5 Not duplicates

    @Test
    fun dismissedDuplicates_lapseWhenItemsChange() {
        val prefs = ApplicationProvider.getApplicationContext<Context>()
            .getSharedPreferences("duplicates-test", Context.MODE_PRIVATE)
        val group = DuplicateGroup(DuplicateReason.SameName, "a", listOf(item("a", "Pears"), item("b", "Pear")))
        val dismissed = DismissedDuplicates(prefs, "hh-1")
        dismissed.dismiss(group)
        assertTrue(dismissed.contains(group))
        assertTrue(dismissed.visible(listOf(group)).isEmpty())
        assertFalse(DismissedDuplicates(prefs, "hh-2").contains(group))

        val changed = group.copy(items = listOf(item("a", "Pears"), item("b", "Pear", updatedAt = "2026-09-09T00:00:00Z")))
        assertFalse(dismissed.contains(changed))
    }

    // ---------------------------------------------------------------- AC5–AC7 review screen

    private fun demoWithDuplicates(vararg drafts: InventoryDraft): SessionViewModel {
        val session = UiHarness.demoSession()
        session.addInventory(drafts.toList())
        compose.waitUntil(UiHarness.WAIT_MS) { session.state.value.data.inventory.size == 4 + drafts.size }
        return session
    }

    private fun SessionViewModel.groupId(vararg names: String): String =
        state.value.data.inventory.filter { it.name in names }.map { it.id }.sorted().joinToString("|")

    @Test
    fun findDuplicates_mergeKeepsPhotoAndHigherQuantity() {
        val session = demoWithDuplicates(InventoryDraft(name = "Diet Cokes", category = "Beverages", quantity = 5))
        val groupId = session.groupId("Diet Coke", "Diet Cokes")
        compose.setApp(session, startRoute = Routes.INVENTORY)

        compose.awaitDisplayed(TestTags.INVENTORY_FIND_DUPLICATES_BUTTON).performClick()
        compose.awaitDisplayed(TestTags.duplicatesGroup(groupId))
        compose.onNodeWithText("1 GROUP FOUND · REVIEW BEFORE MERGING").assertIsDisplayed()
        compose.onNodeWithText("Same name").assertIsDisplayed()
        // AC7: the survivor (the one with a real photo) is announced as keeping its photo.
        compose.onNode(hasContentDescription("Diet Coke, keeps this photo"), useUnmergedTree = true).assertIsDisplayed()
        compose.onNodeWithText("Merges into Diet Coke · keeps qty 5 (higher) · newest photo").assertIsDisplayed()

        compose.node(TestTags.duplicatesMerge(groupId)).performClick()
        compose.awaitDisplayed(TestTags.DUPLICATES_CONFIRMATION)
        compose.onNodeWithText("Merged 2 items into Diet Coke").assertIsDisplayed()
        compose.awaitDisplayed(TestTags.DUPLICATES_EMPTY_STATE)
        compose.onNodeWithText(InventoryDuplicates.EMPTY_TITLE).assertIsDisplayed()

        val inventory = session.state.value.data.inventory
        assertEquals(4, inventory.size)
        val coke = inventory.single { it.name == "Diet Coke" }
        assertEquals(5, coke.quantity)
        assertEquals(3, coke.lowStockThreshold)
    }

    @Test
    fun notDuplicates_hidesGroupUntilItemsChange() {
        val session = demoWithDuplicates(InventoryDraft(name = "Diet Cokes", category = "Beverages"))
        val groupId = session.groupId("Diet Coke", "Diet Cokes")
        compose.setApp(session, startRoute = Routes.DUPLICATES)

        compose.awaitDisplayed(TestTags.duplicatesDismiss(groupId)).performClick()
        compose.awaitGone(TestTags.duplicatesGroup(groupId))
        compose.awaitDisplayed(TestTags.DUPLICATES_EMPTY_STATE)
        compose.node(TestTags.DUPLICATES_MERGE_ALL_BUTTON).assertDoesNotExist()
        assertEquals(5, session.state.value.data.inventory.size)
    }

    @Test
    fun mergeAll_mergesEveryGroup() {
        val session = demoWithDuplicates(
            InventoryDraft(name = "Diet Cokes", category = "Beverages"),
            InventoryDraft(name = "Paper Towel", category = "Household"),
        )
        compose.setApp(session, startRoute = Routes.DUPLICATES)

        compose.awaitDisplayed(TestTags.DUPLICATES_MERGE_ALL_BUTTON)
        compose.onNodeWithText("Merge all 2").performClick()
        compose.awaitDisplayed(TestTags.DUPLICATES_CONFIRMATION)
        compose.onNodeWithText("Merged 4 items into 2 items").assertIsDisplayed()
        compose.awaitDisplayed(TestTags.DUPLICATES_EMPTY_STATE)
        assertEquals(4, session.state.value.data.inventory.size)
    }

    @Test
    fun noDuplicates_showsEmptyState() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.DUPLICATES)
        compose.awaitDisplayed(TestTags.DUPLICATES_EMPTY_STATE)
        compose.onNodeWithText(InventoryDuplicates.EMPTY_SUBTITLE).assertIsDisplayed()
    }
}
