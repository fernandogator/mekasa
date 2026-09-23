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
    fun createInvite_offlinePreview_prependsPendingInvite() = runTest {
        val session = AppSession()
        session.startOfflinePreview()
        session.createInvite("Alex", "alex@example.com")
        dispatcher.scheduler.advanceUntilIdle()
        assertTrue(session.state.value.invites.any { it.name == "Alex" && it.status == "pending" })
    }
}
