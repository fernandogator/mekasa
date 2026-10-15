package app.mekasa.fable.ui.theme

import android.content.Context
import androidx.compose.ui.graphics.Color
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import java.util.Calendar

@RunWith(AndroidJUnit4::class)
@Config(sdk = [34])
class ThemePreferencesTest {

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        ThemePreferences.bind(context.getSharedPreferences("theme-pref-test", Context.MODE_PRIVATE))
        ThemePreferences.resetForTests()
    }

    @After
    fun tearDown() {
        ThemePreferences.resetForTests()
    }

    @Test
    fun defaultsToGrounded() {
        assertEquals(MekasaPaletteStyle.Grounded, ThemePreferences.style)
        assertFalse(ThemePreferences.isHalloween)
    }

    @Test
    fun selectPersistsHalloween() {
        ThemePreferences.select(MekasaPaletteStyle.Halloween)
        assertEquals(MekasaPaletteStyle.Halloween, ThemePreferences.style)
        assertTrue(ThemePreferences.isHalloween)
    }

    @Test
    fun undoRestoresGrounded() {
        ThemePreferences.select(MekasaPaletteStyle.Halloween, showUndo = true)
        assertTrue(ThemePreferences.halloweenUndoVisible)
        ThemePreferences.undoHalloween()
        assertEquals(MekasaPaletteStyle.Grounded, ThemePreferences.style)
        assertFalse(ThemePreferences.halloweenUndoVisible)
    }

    @Test
    fun octoberPromptHiddenAfterDismiss() {
        val october = Calendar.getInstance().apply { set(Calendar.MONTH, Calendar.OCTOBER) }
        assertTrue(ThemePreferences.shouldShowHalloweenPrompt(october))
        ThemePreferences.dismissHalloweenPrompt()
        assertFalse(ThemePreferences.shouldShowHalloweenPrompt(october))
    }

    @Test
    fun halloweenPalettesMatchDesignSystem() {
        val light = paletteFor(MekasaPaletteStyle.Halloween, darkTheme = false)
        val dark = paletteFor(MekasaPaletteStyle.Halloween, darkTheme = true)
        assertEquals(Color(0xFF8B4A0C), light.brand)
        assertEquals(Color(0xFF6B247A), light.accent)
        assertEquals(Color(0xFFD4A01B), dark.brand)
        assertEquals(Color(0xFF9FD356), dark.accent)
        assertEquals(Color(0xFF1A1513), dark.onBrand)
    }
}
