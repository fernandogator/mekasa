package app.mekasa.fable.ui.additems

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import app.mekasa.fable.data.CatalogCapture
import app.mekasa.fable.data.CatalogCode
import app.mekasa.fable.data.LineCapture
import app.mekasa.fable.data.model.ReceiptLine
import app.mekasa.fable.ui.TestTags
import app.mekasa.fable.ui.components.LabeledField
import app.mekasa.fable.ui.components.LinkButton
import app.mekasa.fable.ui.components.PrimaryButton
import app.mekasa.fable.ui.components.SecondaryButton
import app.mekasa.fable.ui.dashboard.decodeBitmap
import app.mekasa.fable.ui.dashboard.encodeJpeg
import app.mekasa.fable.ui.theme.MekasaTheme
import app.mekasa.fable.ui.theme.Shapes
import app.mekasa.fable.ui.theme.Space
import app.mekasa.fable.ui.theme.Type

/** Remembers, per signed-in user, that the shared-photo notice was shown (REQ-RCP-020 AC10). */
private object SharedPhotoNotice {
    private const val PREFS = "mekasa_fable_capture"

    fun seen(context: Context, uid: String?): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(key(uid), false)

    fun markSeen(context: Context, uid: String?) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(key(uid), true).apply()
    }

    private fun key(uid: String?) = "shared_notice_seen_${uid.orEmpty()}"
}

/**
 * Photo and optional code for one unidentified receipt line, shown in place of the
 * receipt list. With no code, the photo
 * and receipt text still go to the shared catalog for that store chain.
 * Satisfies: REQ-RCP-020 AC6, AC10, AC15
 * Spec version: 1.0
 */
@Composable
internal fun LineCapturePanel(
    line: ReceiptLine,
    storeName: String?,
    storeChainId: String?,
    uid: String?,
    initial: LineCapture?,
    initialPreview: ImageBitmap?,
    onCancel: () -> Unit,
    onSave: (LineCapture, ImageBitmap?) -> Unit,
) {
    val palette = MekasaTheme.palette
    val context = LocalContext.current
    var code by remember { mutableStateOf(initial?.code.orEmpty()) }
    var jpeg by remember { mutableStateOf(initial?.photoJpeg) }
    var preview by remember { mutableStateOf(initialPreview) }
    var problem by remember { mutableStateOf<String?>(null) }
    var pendingPicker by remember { mutableStateOf<(() -> Unit)?>(null) }

    val draft = LineCapture(
        code = code.trim().ifEmpty { null },
        photoJpeg = jpeg,
        receiptText = line.receiptText,
        storeChainId = storeChainId,
    )
    val codeInvalid = code.isNotBlank() && CatalogCode.parse(code) == null

    fun accept(bitmap: Bitmap?) {
        val encoded = bitmap?.let { encodeJpeg(it) }
        if (bitmap == null || encoded == null) {
            problem = "Couldn't read that photo. Try a JPEG or PNG."
            return
        }
        problem = null
        jpeg = encoded
        preview = bitmap.asImageBitmap()
    }

    val pickPhoto = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        if (uri != null) accept(decodeBitmap(context, uri))
    }
    val legacyPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri != null) accept(decodeBitmap(context, uri))
    }
    val takePhoto = rememberLauncherForActivityResult(ActivityResultContracts.TakePicturePreview()) { bitmap ->
        if (bitmap != null) accept(bitmap)
    }
    val cameraPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) takePhoto.launch(null) else problem = "Camera permission is needed to take a photo."
    }
    val openCamera = {
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        if (granted) takePhoto.launch(null) else cameraPermission.launch(Manifest.permission.CAMERA)
    }
    val openGallery = {
        runCatching { pickPhoto.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }
            .onFailure { legacyPicker.launch("image/*") }
        Unit
    }
    fun withNotice(picker: () -> Unit) {
        if (SharedPhotoNotice.seen(context, uid)) picker() else pendingPicker = picker
    }

    Column(
        modifier = Modifier.fillMaxWidth().verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(Space.md),
    ) {
        Text(line.name, style = Type.subhead, color = palette.text)
        LabeledField(
            label = "Barcode or PLU (optional)",
            value = code,
            onValueChange = { code = it.filter(Char::isDigit).take(14) },
            placeholder = "012345678905",
            keyboardType = KeyboardType.Number,
            imeAction = ImeAction.Done,
            testTag = TestTags.CAPTURE_CODE_FIELD,
        )
        if (codeInvalid) {
            Text(
                "Barcodes have 8–14 digits. Produce PLUs have 4 or 5.",
                style = Type.caption,
                color = palette.warning,
            )
        }
        preview?.let {
            Image(
                bitmap = it,
                contentDescription = "Photo of ${line.name}",
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxWidth().height(160.dp).clip(Shapes.card),
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(Space.sm)) {
            SecondaryButton(
                text = "Take photo",
                onClick = { withNotice(openCamera) },
                icon = Icons.Filled.PhotoCamera,
                modifier = Modifier.weight(1f).testTag(TestTags.CAPTURE_TAKE_PHOTO),
            )
            SecondaryButton(
                text = "Choose photo",
                onClick = { withNotice(openGallery) },
                modifier = Modifier.weight(1f).testTag(TestTags.CAPTURE_CHOOSE_PHOTO),
            )
        }
        problem?.let { Text(it, style = Type.caption, color = palette.warning) }
        if (jpeg != null && draft.sharesPhoto) {
            Text(CatalogCapture.SHARED_LABEL, style = Type.caption, color = palette.text)
            Text(CatalogCapture.STEP_COPY, style = Type.caption, color = palette.textMuted)
        }
        if (draft.isPhotoOnly) {
            Text(
                CatalogCapture.noCodeMessage(storeName),
                style = Type.caption,
                color = palette.textMuted,
                modifier = Modifier.testTag(TestTags.CAPTURE_NO_CODE_LABEL),
            )
        }
        PrimaryButton(
            text = "Save",
            onClick = { onSave(draft, preview) },
            enabled = !codeInvalid && (jpeg != null || CatalogCode.parse(code) != null),
            modifier = Modifier.fillMaxWidth().testTag(TestTags.CAPTURE_SAVE),
        )
        LinkButton(text = "Cancel", onClick = onCancel, color = palette.textMuted)
    }

    pendingPicker?.let { picker ->
        AlertDialog(
            onDismissRequest = { pendingPicker = null },
            title = { Text(CatalogCapture.SHEET_TITLE) },
            text = { Text(CatalogCapture.SHEET_COPY) },
            confirmButton = {
                TextButton(
                    onClick = {
                        SharedPhotoNotice.markSeen(context, uid)
                        pendingPicker = null
                        picker()
                    },
                    modifier = Modifier.testTag(TestTags.CAPTURE_SHARED_NOTICE),
                ) { Text("Got it") }
            },
        )
    }
}
