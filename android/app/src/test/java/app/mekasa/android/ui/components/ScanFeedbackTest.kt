package app.mekasa.android.ui.components

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
        assert(ScanFeedback.COOLDOWN_SECONDS == 5)
    }
}
