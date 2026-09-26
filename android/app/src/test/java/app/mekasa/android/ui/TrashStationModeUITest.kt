// Verifies: UI-005 · REQ-008 AC4–AC5
// Design: design/mockups/TrashStationMode.jsx

package app.mekasa.android.ui

import app.mekasa.android.ui.components.ScanFeedback
import org.junit.Assert.assertEquals
import org.junit.Ignore
import org.junit.Test

/**
 * Trash Station Mode.
 * Cooldown + feedback contracts are asserted here; Compose layout remains stubbed
 * until an instrumented suite is wired.
 */
class TrashStationModeUITest {

    @Test
    fun scanFeedback_fiveSecondCooldownAfterAcceptedScan() {
        assertEquals(5, ScanFeedback.COOLDOWN_SECONDS)
    }

    @Test
    fun scanFeedback_unknownPathIsSafeWithoutContext() {
        ScanFeedback.unknown(context = null)
    }

    @Test
    @Ignore("Stub — instrumented Compose test when TrashStationScreen harness exists")
    fun layout_keyComposablesVisible() {
        // Layout test: verify key composables exist and are visible
    }

    @Test
    @Ignore("Stub — instrumented Compose test when TrashStationScreen harness exists")
    fun interaction_tapsInputsAndNavigationTriggers() {
        // Interaction test: verify taps, inputs, and navigation triggers
    }

    @Test
    @Ignore("Stub — instrumented Compose test when TrashStationScreen harness exists")
    fun flow_navigatesToNextScreen() {
        // Flow test: verify navigation to next screen completes correctly
    }

    @Test
    @Ignore("Stub — implement when baseline exists")
    fun visual_semanticStructureMatchesBaseline() {
        // Visual verification: capture screenshot; compare semantic structure
        // to design/baselines/android/TrashStationMode_baseline.png
    }
}
