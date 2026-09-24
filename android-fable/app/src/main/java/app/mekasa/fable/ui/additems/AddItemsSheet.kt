package app.mekasa.fable.ui.additems

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.speech.RecognizerIntent
import android.util.Base64
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.outlined.QrCodeScanner
import androidx.compose.material.icons.outlined.Receipt
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.RestoreFromTrash
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import app.mekasa.fable.data.InventoryDraft
import app.mekasa.fable.data.demo.DemoBackend
import app.mekasa.fable.data.model.BarcodeLookup
import app.mekasa.fable.data.model.ProductHit
import app.mekasa.fable.data.model.ReceiptLine
import app.mekasa.fable.session.SessionState
import app.mekasa.fable.session.SessionViewModel
import app.mekasa.fable.ui.components.Card
import app.mekasa.fable.ui.components.Chip
import app.mekasa.fable.ui.components.EmptyMessage
import app.mekasa.fable.ui.components.IconWell
import app.mekasa.fable.ui.components.LabeledField
import app.mekasa.fable.ui.components.LinkButton
import app.mekasa.fable.ui.components.PrimaryButton
import app.mekasa.fable.ui.components.ProductThumbnail
import app.mekasa.fable.ui.components.SecondaryButton
import app.mekasa.fable.ui.components.SectionLabel
import app.mekasa.fable.ui.components.BarcodeScanner
import app.mekasa.fable.ui.components.money
import app.mekasa.fable.ui.dashboard.decodeBitmap
import app.mekasa.fable.ui.dashboard.encodeJpeg
import app.mekasa.fable.ui.theme.MekasaTheme
import app.mekasa.fable.ui.theme.Shapes
import app.mekasa.fable.ui.theme.Space
import app.mekasa.fable.ui.theme.Type
import app.mekasa.fable.voice.VoicePhraseParser
import kotlinx.coroutines.launch

/** Which step of the add flow the sheet is showing. */
private sealed interface AddStep {
    data object Hub : AddStep
    data object Barcode : AddStep
    data object Search : AddStep
    data object Voice : AddStep
    data object Receipt : AddStep
    data class Confirm(val draft: InventoryDraft, val back: AddStep) : AddStep
    data class ReceiptConfirm(val lines: List<ReceiptLine>, val engine: String) : AddStep

    val depth: Int
        get() = when (this) {
            Hub -> 0
            is Confirm, is ReceiptConfirm -> 2
            else -> 1
        }
}

/**
 * Bottom sheet hub for every way an item enters inventory (REQ-004/005/006/007):
 * barcode camera → UPC lookup, catalog search, voice phrase, receipt haul.
 * Each path funnels into a confirm step so the user always sees what will be saved.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddItemsSheet(
    state: SessionState,
    session: SessionViewModel,
    onDismiss: () -> Unit,
    onOpenTrash: () -> Unit,
) {
    val palette = MekasaTheme.palette
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var step by remember { mutableStateOf<AddStep>(AddStep.Hub) }

    fun goBack() {
        step = when (val s = step) {
            is AddStep.Confirm -> s.back
            is AddStep.ReceiptConfirm -> AddStep.Receipt
            AddStep.Hub -> AddStep.Hub
            else -> AddStep.Hub
        }
    }

    BackHandler(enabled = step != AddStep.Hub) { goBack() }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = palette.surface,
        shape = Shapes.sheet,
        dragHandle = null,
        modifier = Modifier.testTag("AddItemsSheet"),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = Space.lg)
                .padding(top = Space.base, bottom = Space.lg),
        ) {
            SheetTitle(step = step, onBack = ::goBack, onClose = onDismiss)
            Spacer(Modifier.height(Space.base))
            AnimatedContent(targetState = step, label = "add-step") { current ->
                when (current) {
                    AddStep.Hub -> HubStep(
                        onPick = { step = it },
                        onOpenTrash = onOpenTrash,
                    )
                    AddStep.Barcode -> BarcodeStep(
                        session = session,
                        isDemo = state.isDemo,
                        onDraft = { step = AddStep.Confirm(it, AddStep.Barcode) },
                    )
                    AddStep.Search -> SearchStep(
                        session = session,
                        onDraft = { step = AddStep.Confirm(it, AddStep.Search) },
                    )
                    AddStep.Voice -> VoiceStep(
                        session = session,
                        onDraft = { step = AddStep.Confirm(it, AddStep.Voice) },
                    )
                    AddStep.Receipt -> ReceiptStep(
                        session = session,
                        busy = state.busy,
                        isDemo = state.isDemo,
                        onScanned = { step = AddStep.ReceiptConfirm(it.items, it.engine) },
                    )
                    is AddStep.Confirm -> ConfirmStep(
                        draft = current.draft,
                        busy = state.busy,
                        onSave = { draft -> session.addInventory(draft) { onDismiss() } },
                    )
                    is AddStep.ReceiptConfirm -> ReceiptConfirmStep(
                        lines = current.lines,
                        engine = current.engine,
                        busy = state.busy,
                        onSave = { drafts -> session.addInventory(drafts) { onDismiss() } },
                    )
                }
            }
        }
    }
}

@Composable
private fun SheetTitle(step: AddStep, onBack: () -> Unit, onClose: () -> Unit) {
    val palette = MekasaTheme.palette
    val title = when (step) {
        AddStep.Hub -> "Add items"
        AddStep.Barcode -> "Scan a barcode"
        AddStep.Search -> "Search products"
        AddStep.Voice -> "Say what you bought"
        AddStep.Receipt -> "Scan a receipt"
        is AddStep.Confirm -> "Confirm item"
        is AddStep.ReceiptConfirm -> "Receipt haul"
    }
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
        if (step.depth > 0) {
            IconButton(onClick = onBack, modifier = Modifier.testTag("AddBack")) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = palette.text)
            }
        } else {
            Spacer(Modifier.width(Space.sm))
        }
        Text(title, style = Type.title, color = palette.text, modifier = Modifier.weight(1f))
        LinkButton(text = "Close", onClick = onClose, color = palette.textMuted)
    }
}

// --------------------------------------------------------------------- hub

@Composable
private fun HubStep(onPick: (AddStep) -> Unit, onOpenTrash: () -> Unit) {
    val palette = MekasaTheme.palette
    Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
        HubOption(
            icon = Icons.Outlined.QrCodeScanner,
            title = "Scan barcode",
            detail = "Point the camera at a UPC to look it up",
            tint = palette.accent,
            tag = "Add-Barcode",
            onClick = { onPick(AddStep.Barcode) },
        )
        HubOption(
            icon = Icons.Outlined.Search,
            title = "Search products",
            detail = "Find it by name in the catalog",
            tint = palette.brand,
            tag = "Add-Search",
            onClick = { onPick(AddStep.Search) },
        )
        HubOption(
            icon = Icons.Filled.Mic,
            title = "Voice",
            detail = "“Two gallons of milk” — we parse the rest",
            tint = palette.success,
            tag = "Add-Voice",
            onClick = { onPick(AddStep.Voice) },
        )
        HubOption(
            icon = Icons.Outlined.Receipt,
            title = "Receipt",
            detail = "Add a whole grocery haul at once",
            tint = palette.warning,
            tag = "Add-Receipt",
            onClick = { onPick(AddStep.Receipt) },
        )
        Spacer(Modifier.height(Space.xs))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onOpenTrash)
                .padding(vertical = Space.sm)
                .testTag("Add-Trash"),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Outlined.RestoreFromTrash, contentDescription = null, tint = palette.textMuted, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(Space.sm))
            Text("Using something up? Open the trash station", style = Type.caption, color = palette.textMuted)
        }
    }
}

@Composable
private fun HubOption(
    icon: ImageVector,
    title: String,
    detail: String,
    tint: Color,
    tag: String,
    onClick: () -> Unit,
) {
    val palette = MekasaTheme.palette
    Card(onClick = onClick, modifier = Modifier.testTag(tag), padding = androidx.compose.foundation.layout.PaddingValues(Space.base)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconWell(icon = icon, tint = tint, background = tint.copy(alpha = 0.12f), size = 44.dp)
            Spacer(Modifier.width(Space.md))
            Column(Modifier.weight(1f)) {
                Text(title, style = Type.subhead, color = palette.text)
                Text(detail, style = Type.caption, color = palette.textMuted)
            }
        }
    }
}

// ----------------------------------------------------------------- barcode

@Composable
private fun BarcodeStep(
    session: SessionViewModel,
    isDemo: Boolean,
    onDraft: (InventoryDraft) -> Unit,
) {
    val palette = MekasaTheme.palette
    val scope = rememberCoroutineScope()
    var generation by remember { mutableIntStateOf(0) }
    var manual by remember { mutableStateOf("") }
    var looking by remember { mutableStateOf<String?>(null) }
    var miss by remember { mutableStateOf<BarcodeLookup?>(null) }

    fun lookup(code: String) {
        val cleaned = code.filter(Char::isDigit)
        if (cleaned.length < 6 || looking != null) return
        looking = cleaned
        miss = null
        scope.launch {
            val result = runCatching { session.lookupBarcode(cleaned) }
                .getOrElse { e ->
                    session.fail(e.message ?: "Lookup failed")
                    null
                }
            looking = null
            generation++
            if (result == null) return@launch
            if (result.found && !result.name.isNullOrBlank()) {
                onDraft(result.toDraft())
            } else {
                miss = result
            }
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(Space.base)) {
        BarcodeScanner(generation = generation, onBarcode = ::lookup)
        if (isDemo) {
            Text(
                "Preview mode: try the Diet Coke UPC ${DemoBackend.DIET_COKE_UPC}.",
                style = Type.caption,
                color = palette.textMuted,
            )
        }
        LabeledField(
            label = "Or type the number",
            value = manual,
            onValueChange = { manual = it.filter(Char::isDigit).take(14) },
            placeholder = "049000028911",
            keyboardType = KeyboardType.Number,
            imeAction = ImeAction.Search,
            onSubmit = { lookup(manual) },
            testTag = "ManualBarcode",
        )
        val pending = looking
        if (pending != null) {
            BusyLine("Looking up $pending…")
        }
        val missed = miss
        if (missed != null) {
            Card(tint = palette.warningTint) {
                Text("No product matched ${missed.barcode}", style = Type.subhead, color = palette.text)
                Spacer(Modifier.height(Space.xs))
                Text("You can still add it by name.", style = Type.caption, color = palette.textMuted)
                Spacer(Modifier.height(Space.md))
                SecondaryButton(
                    text = "Add manually",
                    onClick = {
                        onDraft(InventoryDraft(name = "", barcode = missed.barcode, source = "barcode"))
                    },
                    modifier = Modifier.testTag("AddUnknownBarcode"),
                )
            }
        }
        PrimaryButton(
            text = "Look up",
            onClick = { lookup(manual) },
            enabled = manual.length >= 6 && looking == null,
            modifier = Modifier.testTag("LookupBarcode"),
        )
    }
}

private fun BarcodeLookup.toDraft() = InventoryDraft(
    name = listOfNotNull(brand?.takeIf { !name.orEmpty().contains(it, ignoreCase = true) }, name).joinToString(" "),
    category = category ?: "Other",
    quantity = quantity.coerceAtLeast(1),
    barcode = barcode,
    imageUrl = imageUrl,
    source = "barcode",
)

private fun ProductHit.toDraft(quantity: Int = 1, source: String = "search") = InventoryDraft(
    name = listOfNotNull(brand?.takeIf { !name.contains(it, ignoreCase = true) }, name).joinToString(" "),
    category = category,
    quantity = quantity.coerceAtLeast(1),
    barcode = barcode,
    imageUrl = imageUrl,
    source = source,
)

// ------------------------------------------------------------------ search

@Composable
private fun SearchStep(
    session: SessionViewModel,
    onDraft: (InventoryDraft) -> Unit,
) {
    var query by remember { mutableStateOf("") }
    var results by remember { mutableStateOf<List<ProductHit>>(emptyList()) }
    var searching by remember { mutableStateOf(false) }
    var searched by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    fun search() {
        val q = query.trim()
        if (q.length < 2 || searching) return
        searching = true
        scope.launch {
            results = runCatching { session.searchProducts(q) }
                .getOrElse { e ->
                    session.fail(e.message ?: "Search failed")
                    emptyList()
                }
            searched = true
            searching = false
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(Space.base)) {
        LabeledField(
            label = "Product",
            value = query,
            onValueChange = { query = it },
            placeholder = "Diet Coke, oat milk, paper towels…",
            capitalization = KeyboardCapitalization.Words,
            imeAction = ImeAction.Search,
            onSubmit = ::search,
            testTag = "SearchQuery",
        )
        PrimaryButton(
            text = "Search",
            onClick = ::search,
            enabled = query.trim().length >= 2,
            loading = searching,
            modifier = Modifier.testTag("SearchProducts"),
        )
        ResultList(
            results = results,
            searched = searched,
            fallbackName = query.trim(),
            onPick = { onDraft(it.toDraft()) },
            onManual = { onDraft(InventoryDraft(name = query.trim(), source = "manual")) },
        )
    }
}

@Composable
private fun ResultList(
    results: List<ProductHit>,
    searched: Boolean,
    fallbackName: String,
    onPick: (ProductHit) -> Unit,
    onManual: () -> Unit,
    quantityHint: Int = 1,
) {
    val palette = MekasaTheme.palette
    if (results.isNotEmpty()) {
        SectionLabel("Matches")
        LazyColumn(
            modifier = Modifier.fillMaxWidth().height((72 * results.size.coerceAtMost(4) + 8).dp),
            verticalArrangement = Arrangement.spacedBy(Space.sm),
        ) {
            items(results, key = { it.barcode ?: it.name }) { hit ->
                Card(onClick = { onPick(hit) }, modifier = Modifier.testTag("Result-${hit.name}"), padding = androidx.compose.foundation.layout.PaddingValues(Space.md)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        ProductThumbnail(imageUrl = hit.imageUrl, name = hit.name, size = 44.dp)
                        Spacer(Modifier.width(Space.md))
                        Column(Modifier.weight(1f)) {
                            Text(hit.name, style = Type.body, color = palette.text)
                            Text(
                                listOfNotNull(hit.brand, hit.category).joinToString(" · "),
                                style = Type.caption,
                                color = palette.textMuted,
                            )
                        }
                        if (quantityHint > 1) Chip("×$quantityHint", palette.brand)
                    }
                }
            }
        }
    } else if (searched) {
        EmptyMessage("Nothing in the catalog matched.")
    }
    if (searched && fallbackName.isNotBlank()) {
        LinkButton(
            text = "Add “$fallbackName” without a match",
            onClick = onManual,
            modifier = Modifier.testTag("AddWithoutMatch"),
        )
    }
}

// ------------------------------------------------------------------- voice

@Composable
private fun VoiceStep(
    session: SessionViewModel,
    onDraft: (InventoryDraft) -> Unit,
) {
    val palette = MekasaTheme.palette
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var phrase by remember { mutableStateOf("") }
    var parsed by remember { mutableStateOf<VoicePhraseParser.Parsed?>(null) }
    var results by remember { mutableStateOf<List<ProductHit>>(emptyList()) }
    var searched by remember { mutableStateOf(false) }
    var searching by remember { mutableStateOf(false) }

    fun interpret(text: String) {
        phrase = text
        val p = VoicePhraseParser.parse(text)
        parsed = p
        searched = false
        results = emptyList()
        if (p == null || searching) return
        searching = true
        scope.launch {
            results = runCatching { session.searchProducts(p.query) }.getOrDefault(emptyList())
            searched = true
            searching = false
        }
    }

    val speech = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val heard = result.data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()
            if (!heard.isNullOrBlank()) interpret(heard)
        }
    }
    val startListening = {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            .putExtra(RecognizerIntent.EXTRA_PROMPT, "What did you buy?")
        runCatching { speech.launch(intent) }
            .onFailure { session.fail("Speech recognition isn't available on this device. Type the phrase instead.") }
        Unit
    }

    Column(verticalArrangement = Arrangement.spacedBy(Space.base)) {
        Card(tint = palette.successTint, onClick = startListening, modifier = Modifier.testTag("VoiceMic")) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier.size(56.dp).background(palette.success, CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Filled.Mic, contentDescription = "Speak", tint = Color.White)
                }
                Spacer(Modifier.width(Space.md))
                Column {
                    Text("Tap to speak", style = Type.subhead, color = palette.text)
                    Text("e.g. “add three cans of black beans”", style = Type.caption, color = palette.textMuted)
                }
            }
        }
        LabeledField(
            label = "Or type it",
            value = phrase,
            onValueChange = { phrase = it },
            placeholder = "two gallons of milk",
            imeAction = ImeAction.Done,
            onSubmit = { interpret(phrase) },
            testTag = "VoicePhrase",
        )
        SecondaryButton(
            text = "Interpret",
            onClick = { interpret(phrase) },
            enabled = phrase.isNotBlank(),
            modifier = Modifier.testTag("InterpretPhrase"),
        )
        val p = parsed
        if (phrase.isNotBlank() && p == null) {
            Text("Couldn't find an item in that phrase.", style = Type.caption, color = palette.accent)
        }
        if (p != null) {
            Card {
                SectionLabel("Heard")
                Spacer(Modifier.height(Space.xs))
                Text("${p.quantity} × ${p.displayName}", style = Type.subhead, color = palette.text, modifier = Modifier.testTag("VoiceParsed"))
            }
            if (searching) BusyLine("Matching “${p.query}”…")
            ResultList(
                results = results,
                searched = searched,
                fallbackName = p.displayName,
                quantityHint = p.quantity,
                onPick = { onDraft(it.toDraft(quantity = p.quantity, source = "voice")) },
                onManual = { onDraft(InventoryDraft(name = p.displayName, quantity = p.quantity, source = "voice")) },
            )
        }
    }
}

// ----------------------------------------------------------------- receipt

@Composable
private fun ReceiptStep(
    session: SessionViewModel,
    busy: Boolean,
    isDemo: Boolean,
    onScanned: (app.mekasa.fable.data.model.ReceiptScanResponse) -> Unit,
) {
    val palette = MekasaTheme.palette
    val context = LocalContext.current
    var rawText by remember { mutableStateOf("") }
    var encoding by remember { mutableStateOf(false) }

    fun submitImage(uri: Uri?) {
        if (uri == null) return
        encoding = true
        val bitmap = decodeBitmap(context, uri)
        val jpeg = bitmap?.let { encodeJpeg(it, maxEdge = 1400, startQuality = 80) }
        encoding = false
        if (jpeg == null) {
            session.fail("Couldn't read that receipt photo.")
            return
        }
        val base64 = Base64.encodeToString(jpeg, Base64.NO_WRAP)
        session.scanReceipt(imageBase64 = base64, onResult = onScanned)
    }

    val pickPhoto = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { submitImage(it) }
    val legacyPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { submitImage(it) }
    val takePhoto = rememberLauncherForActivityResult(ActivityResultContracts.TakePicturePreview()) { bitmap ->
        if (bitmap == null) return@rememberLauncherForActivityResult
        val jpeg = encodeJpeg(bitmap, maxEdge = 1400, startQuality = 80)
        if (jpeg == null) {
            session.fail("Couldn't encode that photo.")
        } else {
            session.scanReceipt(imageBase64 = Base64.encodeToString(jpeg, Base64.NO_WRAP), onResult = onScanned)
        }
    }
    val cameraPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) takePhoto.launch(null) else session.fail("Camera permission is needed to photograph a receipt.")
    }

    Column(verticalArrangement = Arrangement.spacedBy(Space.base)) {
        Text(
            "Photograph the receipt or paste its text. Identified lines come back with categories and prices so spending stays accurate.",
            style = Type.caption,
            color = palette.textMuted,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(Space.md)) {
            SecondaryButton(
                text = "Camera",
                onClick = {
                    val granted = androidx.core.content.ContextCompat.checkSelfPermission(
                        context,
                        android.Manifest.permission.CAMERA,
                    ) == android.content.pm.PackageManager.PERMISSION_GRANTED
                    if (granted) takePhoto.launch(null) else cameraPermission.launch(android.Manifest.permission.CAMERA)
                },
                icon = Icons.Filled.PhotoCamera,
                enabled = !busy && !encoding,
                modifier = Modifier.weight(1f).testTag("ReceiptCamera"),
            )
            SecondaryButton(
                text = "Gallery",
                onClick = {
                    runCatching { pickPhoto.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }
                        .onFailure { legacyPicker.launch("image/*") }
                },
                enabled = !busy && !encoding,
                modifier = Modifier.weight(1f).testTag("ReceiptGallery"),
            )
        }
        LabeledField(
            label = "Receipt text",
            value = rawText,
            onValueChange = { rawText = it },
            placeholder = "PUBLIX\nWHOLE MILK 3.49\n…",
            singleLine = false,
            capitalization = KeyboardCapitalization.Characters,
            imeAction = ImeAction.Default,
            testTag = "ReceiptText",
        )
        if (isDemo) {
            LinkButton(
                text = "Use the sample Publix receipt",
                onClick = { rawText = DemoBackend.DEMO_RECEIPT_TEXT },
                modifier = Modifier.testTag("SampleReceipt"),
            )
        }
        PrimaryButton(
            text = "Read receipt",
            onClick = { session.scanReceipt(rawText = rawText.trim(), onResult = onScanned) },
            enabled = rawText.isNotBlank() && !busy,
            loading = busy || encoding,
            modifier = Modifier.testTag("ScanReceipt"),
        )
    }
}

@Composable
private fun ReceiptConfirmStep(
    lines: List<ReceiptLine>,
    engine: String,
    busy: Boolean,
    onSave: (List<InventoryDraft>) -> Unit,
) {
    val palette = MekasaTheme.palette
    val selected = remember(lines) { mutableStateOf(lines.indices.toSet()) }
    val picked = selected.value

    Column(verticalArrangement = Arrangement.spacedBy(Space.base)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("${lines.size} lines read", style = Type.body, color = palette.text, modifier = Modifier.weight(1f))
            Chip(engine, palette.textMuted)
        }
        if (lines.isEmpty()) {
            EmptyMessage("Nothing readable on that receipt.")
        } else {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .height((lines.size.coerceAtMost(5) * 68).dp)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(Space.sm),
            ) {
                lines.forEachIndexed { index, line ->
                    val checked = index in picked
                    Card(
                        onClick = {
                            selected.value = if (checked) picked - index else picked + index
                        },
                        padding = androidx.compose.foundation.layout.PaddingValues(Space.md),
                        modifier = Modifier.testTag("ReceiptLine-$index"),
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Checkbox(
                                checked = checked,
                                onCheckedChange = null,
                                colors = CheckboxDefaults.colors(checkedColor = palette.accent),
                            )
                            Spacer(Modifier.width(Space.sm))
                            ProductThumbnail(imageUrl = line.imageUrl, name = line.name, size = 40.dp)
                            Spacer(Modifier.width(Space.md))
                            Column(Modifier.weight(1f)) {
                                Text(line.name, style = Type.body, color = palette.text)
                                Text(
                                    buildString {
                                        append("×${line.quantity} · ${line.category}")
                                        line.pricePaid?.let { append(" · ${money(it)}") }
                                    },
                                    style = Type.caption,
                                    color = palette.textMuted,
                                )
                            }
                            if (!line.identified) Chip("Unmatched", palette.warning)
                        }
                    }
                }
            }
        }
        PrimaryButton(
            text = "Add ${picked.size} to inventory",
            onClick = {
                onSave(
                    lines.filterIndexed { index, _ -> index in picked }.map { line ->
                        InventoryDraft(
                            name = line.name,
                            category = line.category,
                            quantity = line.quantity.coerceAtLeast(1),
                            barcode = line.barcode,
                            imageUrl = line.imageUrl,
                            source = "receipt",
                            pricePaid = line.pricePaid,
                        )
                    },
                )
            },
            enabled = picked.isNotEmpty() && !busy,
            loading = busy,
            modifier = Modifier.testTag("SaveReceipt"),
        )
    }
}

// ----------------------------------------------------------------- confirm

@Composable
private fun ConfirmStep(
    draft: InventoryDraft,
    busy: Boolean,
    onSave: (InventoryDraft) -> Unit,
) {
    val palette = MekasaTheme.palette
    var name by remember(draft) { mutableStateOf(draft.name) }
    var category by remember(draft) { mutableStateOf(draft.category) }
    var quantity by remember(draft) { mutableIntStateOf(draft.quantity.coerceAtLeast(1)) }
    var price by remember(draft) { mutableStateOf(draft.pricePaid?.toString().orEmpty()) }

    Column(verticalArrangement = Arrangement.spacedBy(Space.base)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            ProductThumbnail(imageUrl = draft.imageUrl, name = name.ifBlank { "?" }, size = 64.dp)
            Spacer(Modifier.width(Space.md))
            Column {
                Text(name.ifBlank { "New item" }, style = Type.subhead, color = palette.text)
                Text(
                    listOfNotNull(draft.barcode?.let { "UPC $it" }, "via ${draft.source}").joinToString(" · "),
                    style = Type.caption,
                    color = palette.textMuted,
                )
            }
        }
        LabeledField(
            label = "Name",
            value = name,
            onValueChange = { name = it },
            placeholder = "What is it?",
            capitalization = KeyboardCapitalization.Words,
            testTag = "ConfirmName",
        )
        LabeledField(
            label = "Category",
            value = category,
            onValueChange = { category = it },
            placeholder = "Beverages",
            capitalization = KeyboardCapitalization.Words,
            testTag = "ConfirmCategory",
        )
        Column {
            SectionLabel("Quantity")
            Spacer(Modifier.height(Space.sm))
            Row(verticalAlignment = Alignment.CenterVertically) {
                StepButton(Icons.Filled.Remove, enabled = quantity > 1, tag = "QtyMinus") { quantity-- }
                Text(
                    quantity.toString(),
                    style = Type.stat,
                    color = palette.text,
                    modifier = Modifier.padding(horizontal = Space.lg).testTag("QtyValue"),
                )
                StepButton(Icons.Filled.Add, enabled = quantity < 999, tag = "QtyPlus") { quantity++ }
            }
        }
        LabeledField(
            label = "Price paid (optional)",
            value = price,
            onValueChange = { price = it.filter { c -> c.isDigit() || c == '.' } },
            placeholder = "3.49",
            keyboardType = KeyboardType.Decimal,
            imeAction = ImeAction.Done,
            testTag = "ConfirmPrice",
        )
        PrimaryButton(
            text = "Add to inventory",
            onClick = {
                onSave(
                    draft.copy(
                        name = name.trim(),
                        category = category.trim().ifBlank { "Other" },
                        quantity = quantity,
                        pricePaid = price.toDoubleOrNull(),
                    ),
                )
            },
            enabled = name.isNotBlank() && !busy,
            loading = busy,
            icon = Icons.Filled.Check,
            modifier = Modifier.testTag("SaveItem"),
        )
    }
}

@Composable
private fun StepButton(icon: ImageVector, enabled: Boolean, tag: String, onClick: () -> Unit) {
    val palette = MekasaTheme.palette
    IconButton(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier
            .size(44.dp)
            .background(if (enabled) palette.brand else palette.overlay, CircleShape)
            .testTag(tag),
    ) {
        Icon(icon, contentDescription = null, tint = if (enabled) Color.White else palette.textMuted)
    }
}

@Composable
private fun BusyLine(text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp, color = MekasaTheme.palette.accent)
        Spacer(Modifier.width(Space.sm))
        Text(text, style = Type.caption, color = MekasaTheme.palette.textMuted)
    }
}