package app.mekasa.fable.ui.theme

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.util.Calendar

/** Seasonal / brand palette choice. Light and dark still follow the system appearance. */
enum class MekasaPaletteStyle(val storageKey: String, val title: String, val subtitle: String) {
    Grounded("grounded", "Grounded", "Original rich & earthy home palette."),
    Halloween("halloween", "Halloween", "Spooky candy corn and slime theme."),
    ;

    companion object {
        fun fromStorage(raw: String?): MekasaPaletteStyle =
            entries.firstOrNull { it.storageKey == raw } ?: Grounded
    }
}

/**
 * Persists the seasonal palette and the October “try Halloween” prompt.
 * Spec version: 1.0 — Superdesign Halloween seasonal theme (2026-10-15).
 */
object ThemePreferences {
    const val PREFS = "mekasa_theme"
    const val STYLE_KEY = "mekasa.paletteStyle"
    const val PROMPT_DISMISSED_KEY = "mekasa.halloweenPromptDismissed"

    private var prefs: SharedPreferences? = null

    var style by mutableStateOf(MekasaPaletteStyle.Grounded)
        private set

    /** Brief undo toast after enabling Halloween from the promo card. */
    var halloweenUndoVisible by mutableStateOf(false)
        private set

    /**
     * Bumps when promo visibility may change so Compose re-reads [shouldShowHalloweenPrompt].
     */
    var promptRevision by mutableStateOf(0)
        private set

    val isHalloween: Boolean get() = style == MekasaPaletteStyle.Halloween

    fun init(context: Context) {
        prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        style = MekasaPaletteStyle.fromStorage(prefs?.getString(STYLE_KEY, null))
        halloweenUndoVisible = false
        promptRevision++
    }

    /** Test / preview hook that does not require Android context. */
    fun bind(sharedPreferences: SharedPreferences) {
        prefs = sharedPreferences
        style = MekasaPaletteStyle.fromStorage(sharedPreferences.getString(STYLE_KEY, null))
        halloweenUndoVisible = false
        promptRevision++
    }

    fun resetForTests() {
        prefs?.edit()?.clear()?.apply()
        style = MekasaPaletteStyle.Grounded
        halloweenUndoVisible = false
        promptRevision++
    }

    /** Show the dashboard promo in October until dismissed or Halloween is on. */
    fun shouldShowHalloweenPrompt(now: Calendar = Calendar.getInstance()): Boolean {
        if (isHalloween) return false
        if (prefs?.contains(PROMPT_DISMISSED_KEY) == true) return false
        return now.get(Calendar.MONTH) == Calendar.OCTOBER
    }

    fun select(newStyle: MekasaPaletteStyle, showUndo: Boolean = false) {
        val previous = style
        style = newStyle
        prefs?.edit()?.putString(STYLE_KEY, newStyle.storageKey)?.apply()
        if (showUndo && newStyle == MekasaPaletteStyle.Halloween && previous != MekasaPaletteStyle.Halloween) {
            halloweenUndoVisible = true
        }
        if (newStyle == MekasaPaletteStyle.Halloween) {
            prefs?.edit()?.putBoolean(PROMPT_DISMISSED_KEY, true)?.apply()
        }
        promptRevision++
    }

    fun dismissHalloweenPrompt() {
        prefs?.edit()?.putBoolean(PROMPT_DISMISSED_KEY, true)?.apply()
        promptRevision++
    }

    fun undoHalloween() {
        style = MekasaPaletteStyle.Grounded
        prefs?.edit()?.putString(STYLE_KEY, MekasaPaletteStyle.Grounded.storageKey)?.apply()
        halloweenUndoVisible = false
    }

    fun clearHalloweenUndo() {
        halloweenUndoVisible = false
    }
}
