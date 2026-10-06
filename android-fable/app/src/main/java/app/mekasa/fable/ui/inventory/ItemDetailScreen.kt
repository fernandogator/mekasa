package app.mekasa.fable.ui.inventory

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import kotlin.math.roundToInt
import kotlinx.coroutines.launch
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.core.content.ContextCompat
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import app.mekasa.fable.data.CatalogCapture
import app.mekasa.fable.data.model.InventoryItem
import app.mekasa.fable.ui.components.LabeledField
import app.mekasa.fable.ui.components.PrimaryButton
import app.mekasa.fable.ui.components.SecondaryButton
import app.mekasa.fable.session.SessionViewModel
import app.mekasa.fable.ui.TestTags
import app.mekasa.fable.ui.components.Backdrop
import app.mekasa.fable.ui.components.Card
import app.mekasa.fable.ui.components.Chip
import app.mekasa.fable.ui.components.LinkButton
import app.mekasa.fable.ui.components.ProductThumbnail
import app.mekasa.fable.ui.components.ScreenHeader
import app.mekasa.fable.ui.components.SectionLabel
import app.mekasa.fable.ui.components.money
import app.mekasa.fable.ui.dashboard.decodeBitmap
import app.mekasa.fable.ui.dashboard.encodeJpeg
import app.mekasa.fable.ui.theme.MekasaTheme
import app.mekasa.fable.ui.theme.Shapes
import app.mekasa.fable.ui.theme.Space
import app.mekasa.fable.ui.theme.Type

/**
 * UI-006 AC2–AC5 and REQ-009: large product image (tap for full screen), metadata, and
 * steppers that PATCH quantity / threshold. Opening a row without an image asks the API
 * to look one up (`refresh-image`). Opened from a list, it swipes to the previous / next
 * item of that list (REQ-INV-020).
 */
@Composable
fun ItemDetailScreen(
    item: InventoryItem,
    session: SessionViewModel,
    onBack: () -> Unit,
    pager: ItemPager = ItemPager(),
    neighbor: (String) -> InventoryItem? = { null },
    onMove: (String) -> Unit = {},
) {
    val palette = MekasaTheme.palette
    val context = LocalContext.current
    var lightbox by remember { mutableStateOf(false) }
    var saving by remember { mutableStateOf(false) }
    var addingCode by remember(item.id) { mutableStateOf(false) }

    // REQ-INV-020: swipe / chevrons / TalkBack actions move within the list the detail came from.
    val haptics = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()
    val density = LocalDensity.current
    val slide = remember { Animatable(0f) }
    val previous = pager.neighbor(item.id, ItemPager.Step.PREVIOUS)?.let(neighbor)
    val next = pager.neighbor(item.id, ItemPager.Step.NEXT)?.let(neighbor)
    val move: (ItemPager.Step) -> Unit = { step ->
        val target = if (step == ItemPager.Step.NEXT) next else previous
        scope.launch {
            if (target == null) {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                slide.animateTo(0f, spring(dampingRatio = 0.45f))
            } else {
                haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                onMove(target.id)
                slide.snapTo(with(density) { (if (step == ItemPager.Step.NEXT) 120.dp else (-120).dp).toPx() })
                slide.animateTo(0f, spring(dampingRatio = 0.9f))
            }
        }
    }
    val swipe = if (pager.isActive) {
        Modifier.pointerInput(item.id, pager) {
            val minPx = 60.dp.toPx()
            var start = Offset.Zero
            var last = Offset.Zero
            detectHorizontalDragGestures(
                onDragStart = { start = it; last = it },
                onDragEnd = {
                    val step = ItemPager.step(last.x - start.x, last.y - start.y, minPx)
                    if (step != null) move(step) else scope.launch { slide.animateTo(0f, spring()) }
                },
                onDragCancel = { scope.launch { slide.animateTo(0f, spring()) } },
            ) { change, _ ->
                last = change.position
                scope.launch { slide.snapTo((last.x - start.x) * 0.35f) }
            }
        }.semantics {
            customActions = listOf(
                CustomAccessibilityAction("Next item") { move(ItemPager.Step.NEXT); true },
                CustomAccessibilityAction("Previous item") { move(ItemPager.Step.PREVIOUS); true },
            )
        }
    } else {
        Modifier
    }

    LaunchedEffect(item.id) {
        if (!item.hasImage) session.refreshItemImage(item.id)
    }

    // REQ-INV-019 AC8: replace the picture with the member's own photo (private to the household).
    fun submit(bitmap: Bitmap?, failure: String) {
        if (bitmap == null) {
            session.fail(failure)
            return
        }
        val jpeg = encodeJpeg(bitmap)
        if (jpeg == null) {
            session.fail("Couldn't encode that photo.")
            return
        }
        saving = true
        session.replaceItemPhoto(item.id, jpeg) { saving = false }
    }

    val pickPhoto = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        if (uri != null) submit(decodeBitmap(context, uri), "Couldn't read that photo. Try a JPEG or PNG.")
    }
    val legacyPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri != null) submit(decodeBitmap(context, uri), "Couldn't read that photo. Try a JPEG or PNG.")
    }
    val takePhoto = rememberLauncherForActivityResult(ActivityResultContracts.TakePicturePreview()) { bitmap ->
        submit(bitmap, "Couldn't capture a photo.")
    }
    val cameraPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) takePhoto.launch(null) else session.fail("Camera permission is needed to take a photo.")
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

    Backdrop(modifier = Modifier.testTag(TestTags.ITEM_DETAIL_VIEW)) {
        Column(modifier = Modifier.fillMaxSize()) {
            ScreenHeader(
                title = "Item",
                eyebrow = item.category,
                onBack = onBack,
                trailing = {
                    pager.positionLabel(item.id)?.let {
                        Chip(it, color = palette.text, modifier = Modifier.testTag(TestTags.ITEM_PAGER_POSITION))
                    }
                },
            )
            Column(
                modifier = Modifier
                    .weight(1f)
                    .offset { IntOffset(slide.value.roundToInt(), 0) }
                    .then(swipe)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Space.lg)
                    .padding(bottom = Space.xxl),
                verticalArrangement = Arrangement.spacedBy(Space.base),
            ) {
                Box(modifier = Modifier.fillMaxWidth()) {
                    previous?.let { NeighborSliver(it, Alignment.CenterStart, (-18).dp) }
                    next?.let { NeighborSliver(it, Alignment.CenterEnd, 18.dp) }
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(280.dp)
                            .clip(Shapes.card)
                            .background(palette.surfaceElevated)
                            .clickable(enabled = item.hasImage) { lightbox = true }
                            .testTag(TestTags.ITEM_IMAGE),
                        contentAlignment = Alignment.Center,
                    ) {
                        ProductThumbnail(
                            imageUrl = item.imageUrl,
                            name = item.name,
                            modifier = Modifier.fillMaxSize(),
                            size = 280.dp,
                            shape = Shapes.card,
                        )
                        if (previous != null) {
                            PagerChevron(
                                icon = Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                                description = "Previous item",
                                modifier = Modifier.align(Alignment.CenterStart).testTag(TestTags.ITEM_PAGER_PREVIOUS),
                            ) { move(ItemPager.Step.PREVIOUS) }
                        }
                        if (next != null) {
                            PagerChevron(
                                icon = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                                description = "Next item",
                                modifier = Modifier.align(Alignment.CenterEnd).testTag(TestTags.ITEM_PAGER_NEXT),
                            ) { move(ItemPager.Step.NEXT) }
                        }
                    }
                }
                ItemPhotoActions(
                    saving = saving,
                    onTakePhoto = openCamera,
                    onChooseFromLibrary = openGallery,
                )
                if (!item.hasImage) {
                    LinkButton("Look up product image", onClick = { session.refreshItemImage(item.id) })
                }

                Text(item.name, style = Type.title, color = palette.text)
                Row(horizontalArrangement = Arrangement.spacedBy(Space.sm), verticalAlignment = Alignment.CenterVertically) {
                    Chip(item.category, color = palette.textMuted)
                    if (item.isLowStock) Chip("Low stock", color = palette.warning)
                    Chip(item.source, color = palette.success)
                }
                if (!item.barcode.isNullOrBlank()) {
                    Column {
                        SectionLabel("UPC")
                        Text(item.barcode, style = Type.mono, color = palette.text)
                    }
                }
                if (item.canAddCode) {
                    if (addingCode) {
                        AddCodeCard(
                            onCancel = { addingCode = false },
                            onSave = { code, onError ->
                                session.addCode(item.id, code) { error ->
                                    if (error == null) addingCode = false else onError(error)
                                }
                            },
                        )
                    } else {
                        Column(verticalArrangement = Arrangement.spacedBy(Space.xs)) {
                            SecondaryButton(
                                text = CatalogCapture.ADD_CODE_TITLE,
                                onClick = { addingCode = true },
                                modifier = Modifier.fillMaxWidth().testTag(TestTags.ADD_ITEM_CODE_BUTTON),
                            )
                            Text(CatalogCapture.ADD_CODE_HINT, style = Type.caption, color = palette.textMuted)
                        }
                    }
                }
                item.pricePaid?.let {
                    Column {
                        SectionLabel("Last price paid")
                        Text(money(it), style = Type.body, color = palette.text)
                    }
                }

                Stepper(
                    label = "Quantity",
                    value = item.quantity,
                    testTag = TestTags.QUANTITY_CONTROL,
                    onChange = { session.updateInventory(item.id, quantity = it) },
                )
                Stepper(
                    label = "Low-stock threshold",
                    value = item.lowStockThreshold,
                    testTag = TestTags.THRESHOLD_CONTROL,
                    onChange = { session.updateInventory(item.id, threshold = it) },
                )
                Text(
                    if (item.isLowStock) {
                        "At or below the threshold: this item shows in Low stock and syncs onto the shopping list."
                    } else {
                        "When quantity drops to ${item.lowStockThreshold} it will be flagged as low stock."
                    },
                    style = Type.caption,
                    color = palette.textMuted,
                )
                if (pager.isActive) {
                    Text(
                        "Swipe left or right for the next or previous item",
                        style = Type.caption,
                        color = palette.textMuted,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth().clearAndSetSemantics {},
                    )
                }
            }
        }
    }

    if (lightbox) {
        Dialog(onDismissRequest = { lightbox = false }) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(420.dp)
                    .clip(Shapes.card)
                    .background(palette.surfaceElevated)
                    .clickable { lightbox = false }
                    .testTag(TestTags.ITEM_LIGHTBOX),
            ) {
                ProductThumbnail(
                    imageUrl = item.imageUrl,
                    name = item.name,
                    modifier = Modifier.fillMaxSize(),
                    size = 420.dp,
                    shape = Shapes.card,
                )
            }
        }
    }
}

/**
 * Inline entry for a barcode or PLU on an item saved without one. The code re-keys the shared
 * product and, for a UPC, brings in nutrition info.
 * Satisfies: REQ-RCP-020 AC15
 * Spec version: 1.0
 */
@Composable
private fun AddCodeCard(
    onCancel: () -> Unit,
    onSave: (code: String, onError: (String) -> Unit) -> Unit,
) {
    val palette = MekasaTheme.palette
    var code by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var saving by remember { mutableStateOf(false) }
    Card {
        Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
            Text(CatalogCapture.ADD_CODE_TITLE, style = Type.subhead, color = palette.text)
            LabeledField(
                label = "Barcode or PLU",
                value = code,
                onValueChange = { code = it.filter(Char::isDigit).take(14); error = null },
                placeholder = "012345678905",
                keyboardType = KeyboardType.Number,
                imeAction = ImeAction.Done,
                testTag = TestTags.ADD_ITEM_CODE_FIELD,
            )
            Text(CatalogCapture.ADD_CODE_HINT, style = Type.caption, color = palette.textMuted)
            error?.let { Text(it, style = Type.caption, color = palette.warning) }
            PrimaryButton(
                text = "Save",
                onClick = {
                    saving = true
                    onSave(code) { message ->
                        saving = false
                        error = message
                    }
                },
                enabled = code.isNotBlank() && !saving,
                loading = saving,
                modifier = Modifier.fillMaxWidth().testTag(TestTags.ADD_ITEM_CODE_SAVE),
            )
            LinkButton(text = "Cancel", onClick = onCancel, color = palette.textMuted)
        }
    }
}

/** Dimmed edge of the neighbouring item's picture, peeking from beside the hero (REQ-INV-020 AC3). */
@Composable
private fun BoxScope.NeighborSliver(item: InventoryItem, alignment: Alignment, shift: Dp) {
    Box(
        modifier = Modifier
            .align(alignment)
            .offset(x = shift)
            .width(14.dp)
            .height(160.dp)
            .clip(Shapes.card)
            .alpha(0.45f)
            .clearAndSetSemantics {},
    ) {
        ProductThumbnail(
            imageUrl = item.imageUrl,
            name = item.name,
            modifier = Modifier
                .wrapContentWidth(
                    align = if (alignment == Alignment.CenterStart) Alignment.End else Alignment.Start,
                    unbounded = true,
                )
                .requiredSize(160.dp),
            size = 160.dp,
            shape = Shapes.card,
        )
    }
}

@Composable
private fun PagerChevron(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    description: String,
    modifier: Modifier,
    onClick: () -> Unit,
) {
    val palette = MekasaTheme.palette
    IconButton(
        onClick = onClick,
        modifier = modifier
            .padding(Space.sm)
            .size(36.dp)
            .clip(CircleShape)
            .background(palette.surfaceElevated.copy(alpha = 0.85f)),
    ) {
        Icon(icon, contentDescription = description, tint = palette.text)
    }
}

/** "Take photo" / "Choose from library" under the hero image (REQ-INV-019 AC8). */
@Composable
private fun ItemPhotoActions(
    saving: Boolean,
    onTakePhoto: () -> Unit,
    onChooseFromLibrary: () -> Unit,
) {
    val palette = MekasaTheme.palette
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(Space.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        LinkButton(
            text = if (saving) "Saving photo…" else "Take photo",
            onClick = onTakePhoto,
            enabled = !saving,
            color = palette.text,
            modifier = Modifier.testTag(TestTags.ITEM_PHOTO_CAMERA_BUTTON),
        )
        LinkButton(
            text = "Choose from library",
            onClick = onChooseFromLibrary,
            enabled = !saving,
            color = palette.text,
            modifier = Modifier.testTag(TestTags.ITEM_PHOTO_LIBRARY_BUTTON),
        )
        Spacer(Modifier.weight(1f))
        Icon(
            Icons.Outlined.Lock,
            contentDescription = "Your photos stay private to this household",
            tint = palette.textMuted,
            modifier = Modifier.size(16.dp),
        )
    }
}

@Composable
private fun Stepper(
    label: String,
    value: Int,
    testTag: String,
    onChange: (Int) -> Unit,
) {
    val palette = MekasaTheme.palette
    Card(modifier = Modifier.testTag(testTag)) {
        SectionLabel(label)
        Spacer(Modifier.height(Space.sm))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            RoundIconButton(Icons.Filled.Remove, "Decrease $label", enabled = value > 0) { onChange(value - 1) }
            Text("$value", style = Type.hero, color = palette.text)
            RoundIconButton(Icons.Filled.Add, "Increase $label") { onChange(value + 1) }
        }
    }
}

@Composable
private fun RoundIconButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    description: String,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    val palette = MekasaTheme.palette
    IconButton(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.size(48.dp).clip(CircleShape).background(palette.overlay),
    ) {
        Icon(icon, contentDescription = description, tint = if (enabled) palette.text else palette.textMuted)
    }
}

/** Compact detail preview used by the receipt confirm list. */
@Composable
fun ProductLine(name: String, meta: String, imageUrl: String?, warn: Boolean = false) {
    val palette = MekasaTheme.palette
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.md)) {
        ProductThumbnail(imageUrl = imageUrl, name = name, size = 44.dp)
        Column(modifier = Modifier.weight(1f)) {
            Text(name, style = Type.body, color = palette.text)
            Text(meta, style = Type.caption, color = if (warn) palette.warning else palette.textMuted)
        }
    }
}
