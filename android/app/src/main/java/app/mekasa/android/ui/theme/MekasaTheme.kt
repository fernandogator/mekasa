package app.mekasa.android.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

object MekasaColor {
    val brand = Color(0xFF171E19)
    val brandMuted = Color(0xFFB7C6C2)
    val surface = Color(0xFFEEEBE3)
    val surfaceElevated = Color(0xFFFFFFFF)
    val text = Color(0xFF171E19)
    val textMuted = Color(0xFF6D7A76)
    val accent = Color(0xFFCA0013)
    val success = Color(0xFF2F6B4F)
    val warning = Color(0xFFC45C12)
    val overlay = Color(0x33B7C6C2)
}

object Spacing {
    val xs: Dp = 4.dp
    val sm: Dp = 8.dp
    val md: Dp = 12.dp
    val base: Dp = 16.dp
    val lg: Dp = 24.dp
    val xl: Dp = 32.dp
    val xxl: Dp = 48.dp
}

object MekasaShapes {
    val card = RoundedCornerShape(40.dp)
    val nested = RoundedCornerShape(24.dp)
    val input = RoundedCornerShape(24.dp)
    val button = RoundedCornerShape(24.dp)
    val pill = RoundedCornerShape(999.dp)
}

private val LightColors = lightColorScheme(
    primary = MekasaColor.brand,
    onPrimary = Color.White,
    secondary = MekasaColor.brandMuted,
    background = MekasaColor.surface,
    surface = MekasaColor.surfaceElevated,
    onBackground = MekasaColor.text,
    onSurface = MekasaColor.text,
    error = MekasaColor.accent,
)

object MekasaType {
    val display = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.Black,
        fontSize = 32.sp,
        lineHeight = 38.sp,
    )
    val title = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.Black,
        fontSize = 28.sp,
        lineHeight = 34.sp,
    )
    val subhead = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.ExtraBold,
        fontSize = 20.sp,
    )
    val body = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.SemiBold,
        fontSize = 16.sp,
        lineHeight = 22.sp,
    )
    val label = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.Bold,
        fontSize = 12.sp,
        letterSpacing = 1.sp,
    )
}

@Composable
fun MekasaTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = LightColors,
        content = content,
    )
}
