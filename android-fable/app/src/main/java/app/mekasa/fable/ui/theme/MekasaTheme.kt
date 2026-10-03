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
 * Semantic palette from design/DESIGN_SYSTEM.md. Screens read colours through
 * [MekasaTheme.palette] so dark mode (UI-001 AC3) only needs a second instance.
 */
@Immutable
data class MekasaPalette(
    val brand: Color,
    val brandMuted: Color,
    val surface: Color,
    val surfaceElevated: Color,
    val text: Color,
    val textMuted: Color,
    val accent: Color,
    val success: Color,
    val warning: Color,
    val overlay: Color,
    val successTint: Color,
    val accentTint: Color,
    val warningTint: Color,
    val isDark: Boolean,
)

val LightPalette = MekasaPalette(
    brand = Color(0xFF171E19),
    brandMuted = Color(0xFFB7C6C2),
    surface = Color(0xFFEEEBE3),
    surfaceElevated = Color(0xFFFFFFFF),
    text = Color(0xFF171E19),
    textMuted = Color(0xFF6D7A76),
    accent = Color(0xFFCA0013),
    success = Color(0xFF2F6B4F),
    warning = Color(0xFFC45C12),
    overlay = Color(0x33B7C6C2),
    successTint = Color(0xFFEAF1EC),
    accentTint = Color(0xFFFCE5E7),
    warningTint = Color(0xFFFFF5F0),
    isDark = false,
)

val DarkPalette = MekasaPalette(
    brand = Color(0xFF1F2A24),
    brandMuted = Color(0xFF5E706C),
    surface = Color(0xFF121612),
    surfaceElevated = Color(0xFF1C241F),
    text = Color(0xFFEEEBE3),
    textMuted = Color(0xFF9AADA8),
    accent = Color(0xFFFF3B4E),
    success = Color(0xFF5DBA8A),
    warning = Color(0xFFE28A4A),
    overlay = Color(0x335E706C),
    successTint = Color(0xFF1F3328),
    accentTint = Color(0xFF3A1A1E),
    warningTint = Color(0xFF3A2A1C),
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
        primary = text, onPrimary = brand, secondary = brandMuted, background = surface,
        surface = surfaceElevated, onBackground = text, onSurface = text, error = accent,
        surfaceVariant = surfaceElevated, onSurfaceVariant = textMuted, outline = brandMuted,
    )
} else {
    lightColorScheme(
        primary = brand, onPrimary = Color.White, secondary = brandMuted, background = surface,
        surface = surfaceElevated, onBackground = text, onSurface = text, error = accent,
        surfaceVariant = surfaceElevated, onSurfaceVariant = textMuted, outline = brandMuted,
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
