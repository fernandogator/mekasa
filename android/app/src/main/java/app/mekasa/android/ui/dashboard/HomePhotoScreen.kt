package app.mekasa.android.ui.dashboard

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.result.contract.ActivityResultContracts.PickVisualMedia
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import app.mekasa.android.session.AppSession
import app.mekasa.android.session.AppUiState
import app.mekasa.android.ui.components.HouseholdPhotoImage
import app.mekasa.android.ui.components.MekasaScreen
import app.mekasa.android.ui.components.MekasaTextField
import app.mekasa.android.ui.components.PrimaryButton
import app.mekasa.android.ui.components.SecondaryButton
import app.mekasa.android.ui.theme.MekasaColor
import app.mekasa.android.ui.theme.MekasaType
import app.mekasa.android.ui.theme.Spacing
import java.io.ByteArrayOutputStream

@Composable
fun HomePhotoScreen(
    state: AppUiState,
    session: AppSession,
    onClose: () -> Unit,
    contentPadding: PaddingValues = PaddingValues(),
) {
    val context = LocalContext.current
    val household = state.household
    val initialName = household?.name.orEmpty()
    var name by remember(household?.id, initialName) { mutableStateOf(initialName) }
    var previewBitmap by remember { mutableStateOf<Bitmap?>(null) }
    var imageChanged by remember { mutableStateOf(false) }

    val gallery = rememberLauncherForActivityResult(PickVisualMedia()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        val bmp = runCatching {
            context.contentResolver.openInputStream(uri)?.use { stream ->
                BitmapFactory.decodeStream(stream)
            }
        }.getOrNull()
        if (bmp != null) {
            previewBitmap = bmp
            imageChanged = true
        } else {
            session.reportError("Couldn’t read that photo.")
        }
    }

    val camera = rememberLauncherForActivityResult(
        ActivityResultContracts.TakePicturePreview(),
    ) { bmp: Bitmap? ->
        if (bmp != null) {
            previewBitmap = bmp
            imageChanged = true
        }
    }

    MekasaScreen(modifier = Modifier.testTag("HomePhotoView")) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(contentPadding)
                .padding(horizontal = Spacing.lg)
                .padding(top = Spacing.base, bottom = Spacing.xxl),
            verticalArrangement = Arrangement.spacedBy(Spacing.base),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                TextButton(onClick = onClose) {
                    Text("Close", color = MekasaColor.accent, style = MekasaType.label)
                }
                Text(
                    text = "Home photo",
                    style = MekasaType.subhead,
                    color = MekasaColor.brand,
                )
                TextButton(
                    onClick = {
                        val nameChanged = name.trim() != initialName.trim()
                        if (!nameChanged && !imageChanged) {
                            onClose()
                            return@TextButton
                        }
                        val jpeg = previewBitmap?.let { encodeJpeg(it) }
                        if (imageChanged && jpeg == null) {
                            session.reportError("Couldn’t encode that photo.")
                            return@TextButton
                        }
                        session.saveHomePhotoEdits(
                            name = name,
                            imageJpeg = jpeg,
                            nameChanged = nameChanged,
                            imageChanged = imageChanged,
                        ) { ok ->
                            if (ok) onClose()
                        }
                    },
                    enabled = !state.isBusy,
                ) {
                    Text("Save", color = MekasaColor.brand, style = MekasaType.label)
                }
            }

            MekasaTextField(
                label = "House name",
                value = name,
                onValueChange = { name = it },
                placeholder = "The Guerrero Home",
                testTag = "HomePhotoNameField",
            )

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(220.dp)
                    .background(MekasaColor.brandMuted.copy(alpha = 0.2f))
                    .testTag("HomePhotoHero"),
            ) {
                val bmp = previewBitmap
                when {
                    bmp != null -> Image(
                        bitmap = bmp.asImageBitmap(),
                        contentDescription = "Selected home photo",
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop,
                    )
                    else -> HouseholdPhotoImage(
                        photoUrl = household?.photoUrl,
                        modifier = Modifier.fillMaxSize(),
                    )
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                SecondaryButton(
                    title = "Choose photo",
                    onClick = {
                        gallery.launch(PickVisualMediaRequest(PickVisualMedia.ImageOnly))
                    },
                    modifier = Modifier
                        .weight(1f)
                        .testTag("HomePhotoLibraryButton"),
                    enabled = !state.isBusy,
                )
                PrimaryButton(
                    title = "Take photo",
                    onClick = { camera.launch(null) },
                    modifier = Modifier
                        .weight(1f)
                        .testTag("HomePhotoCameraButton"),
                    enabled = !state.isBusy,
                    isLoading = state.isBusy,
                )
            }

            Text(
                text = if (session.isHouseholdOwner || state.isOfflinePreview) {
                    "Owners can update the house name and hero photo."
                } else {
                    "Only the household owner can change the home photo."
                },
                style = MekasaType.label,
                color = MekasaColor.textMuted,
            )
        }
    }
}

private fun encodeJpeg(bitmap: Bitmap, maxEdge: Int = 1600, quality: Int = 82): ByteArray? {
    val scaled = scaleDown(bitmap, maxEdge)
    val out = ByteArrayOutputStream()
    if (!scaled.compress(Bitmap.CompressFormat.JPEG, quality, out)) return null
    var bytes = out.toByteArray()
    var q = quality
    while (bytes.size > 4_500_000 && q > 40) {
        q -= 10
        out.reset()
        if (!scaled.compress(Bitmap.CompressFormat.JPEG, q, out)) return null
        bytes = out.toByteArray()
    }
    return bytes
}

private fun scaleDown(bitmap: Bitmap, maxEdge: Int): Bitmap {
    val w = bitmap.width
    val h = bitmap.height
    val longest = maxOf(w, h)
    if (longest <= maxEdge) return bitmap
    val scale = maxEdge.toFloat() / longest
    val nw = (w * scale).toInt().coerceAtLeast(1)
    val nh = (h * scale).toInt().coerceAtLeast(1)
    return Bitmap.createScaledBitmap(bitmap, nw, nh, true)
}
