package app.mekasa.android.ui.components

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Tone + vibrate helpers are best-effort and must not throw without a Context. */
class ScanFeedbackTest {
    @Test
    fun acceptedWithoutContext_doesNotThrow() {
        ScanFeedback.accepted(context = null)
    }

    @Test
    fun unknownWithoutContext_doesNotThrow() {
        ScanFeedback.unknown(context = null)
    }

    @Test
    fun cooldownSeconds_isFive() {
        assertEquals(5, ScanFeedback.COOLDOWN_SECONDS)
    }

    @Test
    fun preferenceKeys_areStable() {
        assertEquals("mekasa_settings", ScanFeedback.PREFS_NAME)
        assertEquals("scan_sounds_enabled", ScanFeedback.PREF_SOUNDS_ENABLED)
    }

    @Test
    fun soundsEnabled_nullContext_defaultsOn() {
        assertTrue(ScanFeedback.soundsEnabled(null))
    }
}
