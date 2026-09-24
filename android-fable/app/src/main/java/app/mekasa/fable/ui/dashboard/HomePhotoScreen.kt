package app.mekasa.fable.ui.dashboard

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.PhotoCamera
import androidx.compose.material.icons.outlined.PhotoLibrary
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import app.mekasa.fable.session.SessionState
import app.mekasa.fable.session.SessionViewModel
import app.mekasa.fable.ui.components.Backdrop
import app.mekasa.fable.ui.components.HomePhoto
import app.mekasa.fable.ui.components.LabeledField
import app.mekasa.fable.ui.components.LinkButton
import app.mekasa.fable.ui.components.PrimaryButton
import app.mekasa.fable.ui.components.ScreenHeader
import app.mekasa.fable.ui.components.SecondaryButton
import app.mekasa.fable.ui.theme.MekasaTheme
import app.mekasa.fable.ui.theme.Shapes
import app.mekasa.fable.ui.theme.Space
import app.mekasa.fable.ui.theme.Type
import java.io.ByteArrayOutputStream

/**
 * REQ-002 / UI-004 AC3: rename the household and pick a hero photo from the gallery or
 * camera. The image is downscaled and JPEG-encoded on device, then multipart-uploaded.
 */
@Composable
fun HomePhotoScreen(
    state: SessionState,
    session: SessionViewModel,
    onClose: () -> Unit,
) {
    val palette = MekasaTheme.palette
    val context = LocalContext.current
    val household = state.household
    val originalName = household?.name.orEmpty()

    var name by remember(household?.id) { mutableStateOf(originalName) }
    var picked by remember { mutableStateOf<Bitmap?>(null) }

    fun accept(bitmap: Bitmap?, failure: String) {
        if (bitmap == null) session.fail(failure) else picked = bitmap
    }

    val pickPhoto = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        if (uri != null) accept(decodeBitmap(context, uri), "Couldn't read that photo. Try a JPEG or PNG.")
    }
    val legacyPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri != null) accept(decodeBitmap(context, uri), "Couldn't read that photo. Try a JPEG or PNG.")
    }
    val takePhoto = rememberLauncherForActivityResult(ActivityResultContracts.TakePicturePreview()) { bitmap ->
        accept(bitmap, "Couldn't capture a photo.")
    }
    val cameraPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) takePhoto.launch(null) else session.fail("Camera permission is needed to take a home photo.")
    }

    val openGallery = {
        runCatching { pickPhoto.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }
            .onFailure { legacyPicker.launch("image/*") }
        Unit
    }
    val openCamera = {
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        if (granted) takePhoto.launch(null) else cameraPermission.launch(Manifest.permission.CAMERA)
    }

    val dirty = picked != null || name.trim() != originalName.trim()
    val save = {
        val jpeg = picked?.let(::encodeJpeg)
        if (picked != null && jpeg == null) {
            session.fail("Couldn't encode that photo.")
        } else {
            session.saveHomeDetails(name = name, jpeg = jpeg) { ok -> if (ok) onClose() }
        }
    }

    Backdrop(modifier = Modifier.testTag("HomePhotoScreen")) {
        Column(modifier = Modifier.fillMaxSize()) {
            ScreenHeader(
                title = "Home photo",
                onBack = onClose,
                trailing = {
                    LinkButton(
                        text = if (state.busy) "Saving…" else "Save",
                        onClick = save,
                        enabled = dirty && !state.busy,
                        color = palette.text,
                        modifier = Modifier.testTag("SaveHome"),
                    )
                },
            )
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Space.lg)
                    .padding(bottom = Space.xxl),
                verticalArrangement = Arrangement.spacedBy(Space.base),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(240.dp)
                        .clip(Shapes.card)
                        .clickable(onClick = openGallery)
                        .testTag("HomePhotoPreview"),
                ) {
                    val bitmap = picked
                    if (bitmap != null) {
                        Image(
                            bitmap = bitmap.asImageBitmap(),
                            contentDescription = "Selected home photo",
                            modifier = Modifier.fillMaxSize(),
                            contentScale = ContentScale.Crop,
                        )
                    } else {
                        HomePhoto(photoUrl = household?.photoUrl, modifier = Modifier.fillMaxSize())
                    }
                }

                Row(horizontalArrangement = Arrangement.spacedBy(Space.md)) {
                    SecondaryButton(
                        text = "Gallery",
                        onClick = openGallery,
                        icon = Icons.Outlined.PhotoLibrary,
                        modifier = Modifier.weight(1f).testTag("PickFromGallery"),
                        enabled = !state.busy,
                    )
                    SecondaryButton(
                        text = "Camera",
                        onClick = openCamera,
                        icon = Icons.Outlined.PhotoCamera,
                        modifier = Modifier.weight(1f).testTag("TakePhoto"),
                        enabled = !state.busy,
                    )
                }

                LabeledField(
                    label = "House name",
                    value = name,
                    onValueChange = { name = it },
                    placeholder = "The Guerrero Home",
                    testTag = "HouseNameField",
                )

                Text(
                    text = when {
                        state.isDemo -> "Offline preview: the photo stays on this device."
                        state.isOwner -> "Photos are resized to 1600px and uploaded as JPEG (max 5 MB)."
                        else -> "Only the household owner can change the name or photo."
                    },
                    style = Type.caption,
                    color = if (state.isOwner || state.isDemo) palette.textMuted else palette.warning,
                )

                PrimaryButton(
                    text = "Save changes",
                    onClick = save,
                    enabled = dirty,
                    loading = state.busy,
                    modifier = Modifier.testTag("SaveHomePrimary"),
                )
            }
        }
    }
}

internal fun decodeBitmap(context: Context, uri: Uri): Bitmap? = runCatching {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        val source = ImageDecoder.createSource(context.contentResolver, uri)
        ImageDecoder.decodeBitmap(source) { decoder, _, _ ->
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            decoder.isMutableRequired = false
        }
    } else {
        context.contentResolver.openInputStream(uri)?.use(BitmapFactory::decodeStream)
    }
}.getOrElse {
    runCatching { context.contentResolver.openInputStream(uri)?.use(BitmapFactory::decodeStream) }.getOrNull()
}

/** Downscale to [maxEdge] px and compress, stepping quality down until under the API's 5 MB limit. */
internal fun encodeJpeg(source: Bitmap, maxEdge: Int = 1600, startQuality: Int = 85): ByteArray? {
    val longest = maxOf(source.width, source.height)
    val scaled = if (longest > maxEdge) {
        val ratio = maxEdge.toFloat() / longest
        Bitmap.createScaledBitmap(
            source,
            (source.width * ratio).toInt().coerceAtLeast(1),
            (source.height * ratio).toInt().coerceAtLeast(1),
            true,
        )
    } else {
        source
    }
    val opaque = if (scaled.config == Bitmap.Config.HARDWARE) scaled.copy(Bitmap.Config.ARGB_8888, false) else scaled
    var quality = startQuality
    while (quality >= 40) {
        val out = ByteArrayOutputStream()
        if (!opaque.compress(Bitmap.CompressFormat.JPEG, quality, out)) return null
        val bytes = out.toByteArray()
        if (bytes.size <= 4_500_000) return bytes
        quality -= 10
    }
    return null
}
