package app.mekasa.android.ui.components

import android.util.Base64
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import app.mekasa.android.ui.theme.MekasaColor
import app.mekasa.android.ui.theme.MekasaType
import coil.compose.AsyncImage

/**
 * Renders household `photo_url` — HTTPS or `data:image/...;base64,...` from the API.
 */
@Composable
fun HouseholdPhotoImage(
    photoUrl: String?,
    modifier: Modifier = Modifier,
    contentDescription: String? = "Home photo",
    contentScale: ContentScale = ContentScale.Crop,
    placeholder: @Composable () -> Unit = {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(MekasaColor.brandMuted.copy(alpha = 0.25f)),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "Tap to add a home photo",
                style = MekasaType.body,
                color = MekasaColor.textMuted,
            )
        }
    },
) {
    if (photoUrl.isNullOrBlank()) {
        Box(modifier = modifier) { placeholder() }
        return
    }
    val model = remember(photoUrl) { photoModel(photoUrl) }
    if (model == null) {
        Box(modifier = modifier) { placeholder() }
        return
    }
    AsyncImage(
        model = model,
        contentDescription = contentDescription,
        modifier = modifier,
        contentScale = contentScale,
    )
}

fun photoModel(photoUrl: String): Any? {
    val trimmed = photoUrl.trim()
    if (trimmed.startsWith("data:", ignoreCase = true)) {
        val comma = trimmed.indexOf(',')
        if (comma <= 0) return null
        val meta = trimmed.substring(5, comma)
        if (!meta.contains(";base64", ignoreCase = true)) return null
        return try {
            Base64.decode(trimmed.substring(comma + 1), Base64.DEFAULT)
        } catch (_: IllegalArgumentException) {
            null
        }
    }
    return trimmed
}
