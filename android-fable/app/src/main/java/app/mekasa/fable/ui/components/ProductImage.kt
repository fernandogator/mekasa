package app.mekasa.fable.ui.components

import android.util.Base64
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.mekasa.fable.ui.theme.MekasaTheme
import app.mekasa.fable.ui.theme.Shapes
import app.mekasa.fable.ui.theme.Type
import coil.compose.SubcomposeAsyncImage

/**
 * Converts an API `photo_url`/`image_url` into something Coil can load: https URLs pass
 * through, `data:<mime>;base64,<payload>` becomes decoded bytes. Returns null when the
 * value is unusable so callers can show a placeholder.
 */
fun imageModelFor(url: String?): Any? {
    val value = url?.trim().orEmpty()
    if (value.isEmpty()) return null
    if (!value.startsWith("data:", ignoreCase = true)) return value
    val comma = value.indexOf(',')
    if (comma <= 5) return null
    val header = value.substring(5, comma)
    if (!header.contains("base64", ignoreCase = true)) return null
    return runCatching { Base64.decode(value.substring(comma + 1), Base64.DEFAULT) }
        .getOrNull()
        ?.takeIf { it.isNotEmpty() }
}

/** Square product thumbnail with a monogram fallback (UI-006 AC1 / REQ-004 AC5). */
@Composable
fun ProductThumbnail(
    imageUrl: String?,
    name: String,
    modifier: Modifier = Modifier,
    size: Dp = 56.dp,
    shape: Shape = Shapes.well,
) {
    val palette = MekasaTheme.palette
    val model = remember(imageUrl) { imageModelFor(imageUrl) }
    Box(
        modifier = modifier.size(size).clip(shape).background(palette.overlay),
        contentAlignment = Alignment.Center,
    ) {
        val monogram: @Composable () -> Unit = {
            Text(name.trim().take(1).uppercase().ifEmpty { "?" }, style = Type.subhead, color = palette.text)
        }
        if (model == null) {
            monogram()
        } else {
            SubcomposeAsyncImage(
                model = model,
                contentDescription = name,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
                loading = { monogram() },
                error = { monogram() },
            )
        }
    }
}

/** Household hero image; falls back to a soft sage panel with a house glyph. */
@Composable
fun HomePhoto(
    photoUrl: String?,
    modifier: Modifier = Modifier,
    contentScale: ContentScale = ContentScale.Crop,
) {
    val palette = MekasaTheme.palette
    val model = remember(photoUrl) { imageModelFor(photoUrl) }
    Box(modifier = modifier.background(palette.brandMuted.copy(alpha = 0.35f)), contentAlignment = Alignment.Center) {
        if (model == null) {
            Icon(Icons.Outlined.Home, contentDescription = "No home photo yet", tint = palette.text.copy(alpha = 0.5f), modifier = Modifier.size(48.dp))
        } else {
            SubcomposeAsyncImage(
                model = model,
                contentDescription = "Home photo",
                contentScale = contentScale,
                modifier = Modifier.fillMaxSize(),
                error = {
                    Icon(Icons.Outlined.Home, contentDescription = null, tint = palette.text.copy(alpha = 0.5f), modifier = Modifier.size(48.dp))
                },
            )
        }
    }
}
