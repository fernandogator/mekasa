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
    fun addInventoryItem_offlinePreview_prependsLocalItem() = runTest {
        val session = AppSession()
        session.startOfflinePreview()
        val before = session.state.value.inventory.size
        session.addInventoryItem(
            PendingInventoryDraft(
                name = "Test Bar",
                category = "Snacks",
                quantity = 2,
                barcode = "123",
                source = "barcode",
            ),
        )
        dispatcher.scheduler.advanceUntilIdle()
        val state = session.state.value
        assertEquals(before + 1, state.inventory.size)
        assertEquals("Test Bar", state.inventory.first().name)
        assertEquals("barcode", state.inventory.first().source)
    }
}
