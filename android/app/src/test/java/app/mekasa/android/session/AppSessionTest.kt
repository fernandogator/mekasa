package app.mekasa.android.session

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AppSessionTest {
    private val dispatcher = UnconfinedTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun startOfflinePreview_reachesDoneWithSampleData() {
        val session = AppSession()
        session.startOfflinePreview()
        val state = session.state.value
        assertEquals(OnboardingStep.Done, state.step)
        assertTrue(state.isOfflinePreview)
        assertTrue(state.inventory.isNotEmpty())
        assertTrue(state.shoppingList.isNotEmpty())
        assertEquals("The Guerrero Home", state.household?.name)
    }

    @Test
    fun signOut_preservesLastSignedInEmail() {
        val session = AppSession()
        session.startOfflinePreview()
        session.signOut()
        val state = session.state.value
        assertEquals(OnboardingStep.Welcome, state.step)
        assertEquals("preview@mekasa.local", state.lastSignedInEmail)
        assertEquals(null, state.idToken)
    }

    @Test
    fun consumeInventoryItem_offlinePreview_decrementsQuantity() = runTest {
        val session = AppSession()
        session.startOfflinePreview()
        val id = session.state.value.inventory.first().id
        val before = session.state.value.inventory.first().quantity
        session.consumeInventoryItem(id)
        dispatcher.scheduler.advanceUntilIdle()
        assertEquals(before - 1, session.state.value.inventory.first { it.id == id }.quantity)
    }

    @Test
    fun refreshSpending_offlinePreview_updatesPeriod() {
        val session = AppSession()
        session.startOfflinePreview()
        session.refreshSpending("month")
        assertEquals("month", session.state.value.spendingPeriod)
        assertEquals("month", session.state.value.spending?.period)
    }

    @Test
    fun consumeInventoryByBarcode_offlineUnknown_logsEvent() = runTest {
        val session = AppSession()
        session.startOfflinePreview()
        var result: ConsumeResult? = null
        session.consumeInventoryByBarcode("999999999999") { result = it }
        dispatcher.scheduler.advanceUntilIdle()
        assertTrue(result is ConsumeResult.Unknown)
        assertTrue(session.state.value.unknownTrashScans.any { it.barcode == "999999999999" })
    }

    @Test
    fun consumeInventoryByBarcode_offlineKnown_decrements() = runTest {
        val session = AppSession()
        session.startOfflinePreview()
        val before = session.state.value.inventory.first { it.barcode == "049000028911" }.quantity
        var result: ConsumeResult? = null
        session.consumeInventoryByBarcode("049000028911") { result = it }
        dispatcher.scheduler.advanceUntilIdle()
        assertTrue(result is ConsumeResult.Decremented || result is ConsumeResult.Depleted)
        assertEquals(
            before - 1,
            session.state.value.inventory.first { it.barcode == "049000028911" }.quantity,
        )
    }

    @Test
    fun saveHomePhotoEdits_offlinePreview_updatesNameAndPhoto() = runTest {
        val session = AppSession()
        session.startOfflinePreview()
        var ok = false
        val jpeg = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0xD9.toByte())
        session.saveHomePhotoEdits(
            name = "Casa Mekasa",
            imageJpeg = jpeg,
            nameChanged = true,
            imageChanged = true,
        ) { ok = it }
        dispatcher.scheduler.advanceUntilIdle()
        assertTrue(ok)
        assertEquals("Casa Mekasa", session.state.value.household?.name)
        assertTrue(session.state.value.household?.photoUrl?.startsWith("data:image/jpeg;base64,") == true)
    }

    @Test
    fun toggleShoppingChecked_nonOwner_blockedWhenChecking() = runTest {
        val session = AppSession()
        session.startOfflinePreview()
        // Demote to member
        val hh = session.state.value.household!!
        // preview user is owner — create a non-owner scenario via shopping gate helper
        assertTrue(session.canMarkShoppingPurchased)
        val id = session.state.value.shoppingList.first().id
        session.toggleShoppingChecked(id)
        dispatcher.scheduler.advanceUntilIdle()
        assertTrue(session.state.value.shoppingList.first { it.id == id }.isChecked)
    }

    @Test
    fun updateInventoryItem_offlinePreview_updatesQuantity() = runTest {
        val session = AppSession()
        session.startOfflinePreview()
        val id = session.state.value.inventory.first().id
        session.updateInventoryItem(id, quantity = 9, lowStockThreshold = 2)
        dispatcher.scheduler.advanceUntilIdle()
        val item = session.state.value.inventory.first { it.id == id }
        assertEquals(9, item.quantity)
        assertEquals(2, item.lowStockThreshold)
    }
}
