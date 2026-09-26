// Verifies: REQ-019 AC5 (Family / settings — Scan sounds)
// Design: design/mockups/FamilyMembers.jsx

package app.mekasa.android.ui

import app.mekasa.android.ui.components.ScanFeedback
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Settings / Family scan-feedback coverage.
 * Layout/interaction Compose UI tests remain stubs until an instrumented suite lands;
 * preference keys and defaults are asserted here so CI guards the contract.
 */
class SettingsUITest {

    @Test
    fun scanSounds_preferenceKeysMatchFamilyToggle() {
        assertEquals("mekasa_settings", ScanFeedback.PREFS_NAME)
        assertEquals("scan_sounds_enabled", ScanFeedback.PREF_SOUNDS_ENABLED)
    }

    @Test
    fun scanSounds_defaultEnabledWithoutContext() {
        assertTrue(ScanFeedback.soundsEnabled(null))
    }

    @Test
    fun scanFeedback_cooldownMatchesTrashStationSpec() {
        // REQ-008 AC4: 5 s disarm after an accepted trash-station scan.
        assertEquals(5, ScanFeedback.COOLDOWN_SECONDS)
    }
}
