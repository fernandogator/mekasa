package app.mekasa.fable.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Semantic palette from design/design-system.md (Rich & Grounded). Screens read
 * colours through [MekasaTheme.palette] so dark mode (UI-001 AC3) is a second instance.
 *
 * Satisfies: NFR-005 AC2, AC5 — screens never use literal colours, and every
 * text/fill pair below is contrast-checked in design/design-system.md.
 */
@Immutable
data class MekasaPalette(
    /** Primary text in light mode; tab bar, selected rows and dark fills. */
    val brand: Color,
    /** Decorative sage for washes and wells; never text, icons or outlines. */
    val brandMuted: Color,
    val surface: Color,
    val surfaceElevated: Color,
    val text: Color,
    val textMuted: Color,
    /** Primary buttons, the Add button, selections and links. */
    val accent: Color,
    /** Errors, destructive actions and depleted / failed scan feedback. */
    val danger: Color,
    val success: Color,
    val warning: Color,
    val overlay: Color,
    val successTint: Color,
    val accentTint: Color,
    val dangerTint: Color,
    val warningTint: Color,
    /** Icons, input borders, chip outlines and unchecked controls (3:1). */
    val border: Color,
    /** Text and icons on brand fills. */
    val onBrand: Color,
    /** Text and icons on accent, success and danger fills. */
    val onAccent: Color,
    /** Inactive icons and secondary text on brand fills. */
    val onBrandMuted: Color,
    /** Text, icons and the reticle over the live camera preview. */
    val onCamera: Color,
    /** Gradient laid over photos so overlaid text keeps contrast (NFR-005 AC2). */
    val photoScrim: Color,
    val isDark: Boolean,
)

val LightPalette = MekasaPalette(
    brand = Color(0xFF5D5652),
    brandMuted = Color(0xFF8FA085),
    surface = Color(0xFFEDE8E0),
    surfaceElevated = Color(0xFFFAF7F3),
    text = Color(0xFF5D5652),
    textMuted = Color(0xFF5C6B54),
    accent = Color(0xFF5A6F4F),
    danger = Color(0xFFA44A3F),
    success = Color(0xFF5A6F4F),
    warning = Color(0xFF8B5C32),
    overlay = Color(0x268FA085),
    successTint = Color(0xFFDCE8D3),
    accentTint = Color(0xFFDCE8D3),
    dangerTint = Color(0xFFF6E3E0),
    warningTint = Color(0xFFF3E6D8),
    border = Color(0xFF76896B),
    onBrand = Color(0xFFFFFFFF),
    onAccent = Color(0xFFFFFFFF),
    onBrandMuted = Color(0xFFC9D6C0),
    onCamera = Color(0xFFFAF7F3),
    photoScrim = Color(0xFF1A1918),
    isDark = false,
)

val DarkPalette = MekasaPalette(
    brand = Color(0xFF3A3531),
    brandMuted = Color(0xFF5A6F4F),
    surface = Color(0xFF1C1A18),
    surfaceElevated = Color(0xFF272421),
    text = Color(0xFFEDE8E0),
    textMuted = Color(0xFFA9B79F),
    accent = Color(0xFF8FA085),
    danger = Color(0xFFE39286),
    success = Color(0xFFA3B598),
    warning = Color(0xFFE2B07E),
    overlay = Color(0x265A6F4F),
    successTint = Color(0xFF2C3628),
    accentTint = Color(0xFF2C3628),
    dangerTint = Color(0xFF3A2220),
    warningTint = Color(0xFF3A2E22),
    border = Color(0xFF7F8E76),
    onBrand = Color(0xFFEDE8E0),
    onAccent = Color(0xFF1C1A18),
    onBrandMuted = Color(0xFFB5C2AB),
    onCamera = Color(0xFFFAF7F3),
    photoScrim = Color(0xFF0F0E0D),
    isDark = true,
)

object Space {
    val xs = 4.dp
    val sm = 8.dp
    val md = 12.dp
    val base = 16.dp
    val lg = 24.dp
    val xl = 32.dp
    val xxl = 48.dp
}

object Shapes {
    val sheet = RoundedCornerShape(40.dp)
    val card = RoundedCornerShape(24.dp)
    val well = RoundedCornerShape(16.dp)
    val field = RoundedCornerShape(24.dp)
    val button = RoundedCornerShape(24.dp)
    val pill = RoundedCornerShape(999.dp)
}

/** Nunito isn't bundled; the system sans-serif at the same weights keeps the hierarchy. */
object Type {
    private val family = FontFamily.SansSerif

    val hero = TextStyle(fontFamily = family, fontWeight = FontWeight.Black, fontSize = 34.sp, lineHeight = 40.sp, letterSpacing = (-0.5).sp)
    val title = TextStyle(fontFamily = family, fontWeight = FontWeight.Black, fontSize = 28.sp, lineHeight = 34.sp, letterSpacing = (-0.3).sp)
    val subhead = TextStyle(fontFamily = family, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp, lineHeight = 26.sp)
    val body = TextStyle(fontFamily = family, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, lineHeight = 22.sp)
    val bodyRegular = TextStyle(fontFamily = family, fontWeight = FontWeight.Normal, fontSize = 15.sp, lineHeight = 21.sp)
    val stat = TextStyle(fontFamily = family, fontWeight = FontWeight.Black, fontSize = 24.sp, lineHeight = 28.sp)
    val label = TextStyle(fontFamily = family, fontWeight = FontWeight.Bold, fontSize = 12.sp, lineHeight = 16.sp, letterSpacing = 1.2.sp)
    val caption = TextStyle(fontFamily = family, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, lineHeight = 18.sp)
    val mono = TextStyle(fontFamily = FontFamily.Monospace, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
    val button = TextStyle(fontFamily = family, fontWeight = FontWeight.Black, fontSize = 17.sp)
}

private val LocalPalette = staticCompositionLocalOf { LightPalette }

object MekasaTheme {
    val palette: MekasaPalette
        @Composable get() = LocalPalette.current
}

private fun MekasaPalette.toColorScheme(): ColorScheme = if (isDark) {
    darkColorScheme(
        primary = accent, onPrimary = onAccent, secondary = brandMuted, background = surface,
        surface = surfaceElevated, onBackground = text, onSurface = text, error = danger,
        surfaceVariant = surfaceElevated, onSurfaceVariant = textMuted, outline = border,
    )
} else {
    lightColorScheme(
        primary = accent, onPrimary = onAccent, secondary = brandMuted, background = surface,
        surface = surfaceElevated, onBackground = text, onSurface = text, error = danger,
        surfaceVariant = surfaceElevated, onSurfaceVariant = textMuted, outline = border,
    )
}

@Composable
fun MekasaTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val palette = if (darkTheme) DarkPalette else LightPalette
    CompositionLocalProvider(LocalPalette provides palette) {
        MaterialTheme(
            colorScheme = palette.toColorScheme(),
            typography = Typography(
                bodyLarge = Type.body,
                bodyMedium = Type.bodyRegular,
                labelSmall = Type.label,
                titleLarge = Type.title,
                titleMedium = Type.subhead,
            ),
            content = content,
        )
    }
}
