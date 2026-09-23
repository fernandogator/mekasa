package app.mekasa.android.session

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AppSessionTest {
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
}
