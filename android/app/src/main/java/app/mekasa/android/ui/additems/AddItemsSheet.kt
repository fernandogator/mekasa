package app.mekasa.android.ui.additems

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import app.mekasa.android.data.ProductSearchHit
import app.mekasa.android.data.ReceiptLineItemDto
import app.mekasa.android.session.AppSession
import app.mekasa.android.session.AppUiState
import app.mekasa.android.session.PendingInventoryDraft
import app.mekasa.android.ui.components.BarcodeCameraOrPermission
import app.mekasa.android.ui.components.MekasaTextField
import app.mekasa.android.ui.components.PrimaryButton
import app.mekasa.android.ui.components.ScanFeedback
import app.mekasa.android.ui.components.SecondaryButton
import app.mekasa.android.ui.components.SoftCard
import app.mekasa.android.ui.components.rememberScanFeedbackContext
import app.mekasa.android.ui.theme.MekasaColor
import app.mekasa.android.ui.theme.MekasaType
import app.mekasa.android.ui.theme.Spacing
import app.mekasa.android.voice.VoicePhraseParser
import kotlinx.coroutines.launch

private enum class AddStep {
    Hub,
    Barcode,
    Search,
    Voice,
    Receipt,
    ReceiptConfirm,
    Confirm,
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddItemsSheet(
    state: AppUiState,
    session: AppSession,
    onDismiss: () -> Unit,
    onOpenTrash: () -> Unit = {},
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var step by remember { mutableStateOf(AddStep.Hub) }
    var draft by remember { mutableStateOf<PendingInventoryDraft?>(null) }
    var receiptLines by remember { mutableStateOf<List<ReceiptLineItemDto>>(emptyList()) }
    var receiptEngine by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MekasaColor.surface,
    ) {
        when (step) {
            AddStep.Hub -> HubContent(
                onBarcode = { step = AddStep.Barcode },
                onSearch = { step = AddStep.Search },
                onVoice = { step = AddStep.Voice },
                onReceipt = { step = AddStep.Receipt },
                onTrash = {
                    onDismiss()
                    onOpenTrash()
                },
                onDismiss = onDismiss,
            )
            AddStep.Barcode -> BarcodeContent(
                state = state,
                session = session,
                onBack = { step = AddStep.Hub },
                onDraft = {
                    draft = it
                    step = AddStep.Confirm
                },
            )
            AddStep.Search -> SearchContent(
                state = state,
                session = session,
                onBack = { step = AddStep.Hub },
                onDraft = {
                    draft = it
                    step = AddStep.Confirm
                },
            )
            AddStep.Voice -> VoiceContent(
                state = state,
                session = session,
                onBack = { step = AddStep.Hub },
                onDraft = {
                    draft = it
                    step = AddStep.Confirm
                },
            )
            AddStep.Receipt -> ReceiptContent(
                state = state,
                session = session,
                onBack = { step = AddStep.Hub },
                onLines = { lines, engine ->
                    receiptLines = lines
                    receiptEngine = engine
                    step = AddStep.ReceiptConfirm
                },
            )
            AddStep.ReceiptConfirm -> ReceiptConfirmContent(
                lines = receiptLines,
                engine = receiptEngine,
                isBusy = state.isBusy,
                onBack = { step = AddStep.Receipt },
                onSave = {
                    val drafts = receiptLines.map {
                        PendingInventoryDraft(
                            name = it.name,
                            category = it.category,
                            quantity = it.quantity.coerceAtLeast(1),
                            barcode = it.barcode,
                            imageUrl = it.imageUrl,
                            source = "receipt",
                            pricePaid = it.pricePaid,
                        )
                    }
                    session.addInventoryItems(drafts) {
                        scope.launch { onDismiss() }
                    }
                },
            )
            AddStep.Confirm -> {
                val current = draft
                if (current == null) {
                    step = AddStep.Hub
                } else {
                    ConfirmContent(
                        draft = current,
                        isBusy = state.isBusy,
                        onQuantityChange = { qty -> draft = current.copy(quantity = qty) },
                        onBack = { step = AddStep.Hub },
                        onSave = {
                            val toSave = draft ?: current
                            session.addInventoryItem(toSave) {
                                scope.launch { onDismiss() }
                            }
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun HubContent(
    onBarcode: () -> Unit,
    onSearch: () -> Unit,
    onVoice: () -> Unit,
    onReceipt: () -> Unit,
    onTrash: () -> Unit,
    onDismiss: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg)
            .padding(bottom = Spacing.xl)
            .testTag("AddItemsSheet"),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Text(text = "Add items", style = MekasaType.title, color = MekasaColor.brand)
        Text(
            text = "Barcode, search, voice phrase, receipt haul, or trash station.",
            style = MekasaType.body,
            color = MekasaColor.textMuted,
        )
        PrimaryButton(title = "Scan / enter barcode", onClick = onBarcode)
        SecondaryButton(title = "Search products", onClick = onSearch)
        SecondaryButton(title = "Voice / type a phrase", onClick = onVoice)
        SecondaryButton(title = "Scan receipt", onClick = onReceipt)
        SecondaryButton(title = "Trash station", onClick = onTrash)
        SecondaryButton(title = "Close", onClick = onDismiss)
    }
}

@Composable
private fun BarcodeContent(
    state: AppUiState,
    session: AppSession,
    onBack: () -> Unit,
    onDraft: (PendingInventoryDraft) -> Unit,
) {
    var code by remember { mutableStateOf("") }
    var lookingUp by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf<String?>(null) }
    var scanKey by remember { mutableStateOf(0) }
    val scope = rememberCoroutineScope()
    val feedbackContext = rememberScanFeedbackContext()

    fun lookup(raw: String) {
        val trimmed = raw.trim()
        if (trimmed.length < 6) {
            status = "Enter a valid barcode"
            return
        }
        scope.launch {
            lookingUp = true
            status = null
            try {
                if (state.isOfflinePreview) {
                    ScanFeedback.accepted(feedbackContext)
                    onDraft(
                        PendingInventoryDraft(
                            name = "Scanned item $trimmed",
                            category = "Other",
                            barcode = trimmed,
                            source = "barcode",
                        ),
                    )
                } else {
                    val result = session.lookupBarcode(trimmed)
                    onDraft(
                        PendingInventoryDraft(
                            name = result.name ?: "Unknown product",
                            category = result.category ?: "Other",
                            quantity = result.quantity.coerceAtLeast(1),
                            barcode = result.barcode,
                            imageUrl = result.imageUrl,
                            source = "barcode",
                        ),
                    )
                    if (result.found) {
                        ScanFeedback.accepted(feedbackContext)
                    } else {
                        ScanFeedback.unknown(feedbackContext)
                        status = "Not in catalog — confirm name before saving"
                    }
                }
            } catch (e: Exception) {
                ScanFeedback.unknown(feedbackContext)
                status = e.message
            } finally {
                lookingUp = false
                scanKey += 1
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg)
            .padding(bottom = Spacing.xl),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Text(text = "Barcode", style = MekasaType.title, color = MekasaColor.brand)
        BarcodeCameraOrPermission(
            scanKey = scanKey,
            onBarcode = { lookup(it) },
        )
        MekasaTextField(
            label = "UPC / EAN",
            value = code,
            onValueChange = { code = it.filter { ch -> ch.isDigit() } },
            placeholder = "049000028911",
            keyboardType = KeyboardType.Number,
            imeAction = ImeAction.Go,
            onImeAction = { lookup(code) },
            testTag = "BarcodeManualField",
        )
        if (status != null) {
            Text(text = status!!, style = MekasaType.label, color = MekasaColor.warning)
        }
        PrimaryButton(
            title = "Look up",
            enabled = code.length >= 6,
            isLoading = lookingUp || state.isBusy,
            onClick = { lookup(code) },
        )
        SecondaryButton(title = "Back", onClick = onBack)
    }
}

@Composable
private fun SearchContent(
    state: AppUiState,
    session: AppSession,
    onBack: () -> Unit,
    onDraft: (PendingInventoryDraft) -> Unit,
) {
    var query by remember { mutableStateOf("") }
    var results by remember { mutableStateOf<List<ProductSearchHit>>(emptyList()) }
    var searching by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    fun runSearch() {
        val q = query.trim()
        if (q.isBlank()) return
        scope.launch {
            searching = true
            status = null
            try {
                if (state.isOfflinePreview) {
                    results = listOf(
                        ProductSearchHit(
                            barcode = "049000028911",
                            name = "Diet Coke",
                            brand = "Coca-Cola",
                            category = "Beverages",
                            imageUrl = "https://images.openfoodfacts.org/images/products/004/900/002/8911/front_en.jpg",
                        ),
                    )
                } else {
                    results = session.searchProducts(q)
                    if (results.isEmpty()) status = "No matches — try another name"
                }
            } catch (e: Exception) {
                status = e.message
            } finally {
                searching = false
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = Spacing.lg)
            .padding(bottom = Spacing.xl),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Text(text = "Search products", style = MekasaType.title, color = MekasaColor.brand)
        MekasaTextField(
            label = "Product name",
            value = query,
            onValueChange = { query = it },
            placeholder = "coke, milk, bread…",
            imeAction = ImeAction.Search,
            onImeAction = { runSearch() },
            testTag = "ProductSearchField",
        )
        PrimaryButton(
            title = "Search",
            enabled = query.isNotBlank(),
            isLoading = searching,
            onClick = { runSearch() },
        )
        if (status != null) {
            Text(text = status!!, style = MekasaType.label, color = MekasaColor.warning)
        }
        results.forEach { hit ->
            SoftCard {
                Text(text = hit.name, style = MekasaType.body, color = MekasaColor.brand)
                Text(
                    text = listOfNotNull(hit.brand, hit.category, hit.barcode).joinToString(" · "),
                    style = MekasaType.label,
                    color = MekasaColor.textMuted,
                )
                Box(modifier = Modifier.height(Spacing.sm))
                SecondaryButton(title = "Select") {
                    onDraft(
                        PendingInventoryDraft(
                            name = hit.name,
                            category = hit.category,
                            barcode = hit.barcode,
                            imageUrl = hit.imageUrl,
                            source = "manual",
                        ),
                    )
                }
            }
        }
        SecondaryButton(title = "Back", onClick = onBack)
    }
}

@Composable
private fun ConfirmContent(
    draft: PendingInventoryDraft,
    isBusy: Boolean,
    onQuantityChange: (Int) -> Unit,
    onBack: () -> Unit,
    onSave: () -> Unit,
) {
    var qtyText by remember { mutableStateOf(draft.quantity.toString()) }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg)
            .padding(bottom = Spacing.xl)
            .testTag("ItemConfirm"),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Text(text = "Confirm item", style = MekasaType.title, color = MekasaColor.brand)
        SoftCard {
            Text(text = draft.name, style = MekasaType.subhead, color = MekasaColor.brand)
            Text(
                text = listOfNotNull(draft.category, draft.barcode).joinToString(" · "),
                style = MekasaType.label,
                color = MekasaColor.textMuted,
            )
        }
        MekasaTextField(
            label = "Quantity",
            value = qtyText,
            onValueChange = {
                qtyText = it.filter { ch -> ch.isDigit() }.take(4)
                onQuantityChange(qtyText.toIntOrNull()?.coerceAtLeast(1) ?: 1)
            },
            keyboardType = KeyboardType.Number,
            imeAction = ImeAction.Done,
        )
        PrimaryButton(
            title = "Add to inventory",
            isLoading = isBusy,
            onClick = onSave,
        )
        SecondaryButton(title = "Back", onClick = onBack)
    }
}

@Composable
private fun VoiceContent(
    state: AppUiState,
    session: AppSession,
    onBack: () -> Unit,
    onDraft: (PendingInventoryDraft) -> Unit,
) {
    var phrase by remember { mutableStateOf("") }
    var status by remember { mutableStateOf<String?>(null) }
    var searching by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    fun matchPhrase() {
        val parsed = VoicePhraseParser.parse(phrase)
        if (parsed == null) {
            status = "Try “two avocados” or “oat milk”"
            return
        }
        scope.launch {
            searching = true
            status = null
            try {
                val hits = if (state.isOfflinePreview) {
                    emptyList()
                } else {
                    runCatching { session.searchProducts(parsed.productQuery) }.getOrDefault(emptyList())
                }
                val hit = hits.firstOrNull()
                onDraft(
                    PendingInventoryDraft(
                        name = hit?.name ?: parsed.displayName,
                        category = hit?.category ?: "Other",
                        quantity = parsed.quantity,
                        barcode = hit?.barcode,
                        imageUrl = hit?.imageUrl,
                        source = "voice",
                    ),
                )
            } catch (e: Exception) {
                status = e.message
            } finally {
                searching = false
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg)
            .padding(bottom = Spacing.xl)
            .testTag("VoiceAddView"),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Text(text = "Voice / type a phrase", style = MekasaType.title, color = MekasaColor.brand)
        Text(
            text = "Type what you’d say — e.g. “three packs of oat milk”.",
            style = MekasaType.body,
            color = MekasaColor.textMuted,
        )
        MekasaTextField(
            label = "Phrase",
            value = phrase,
            onValueChange = { phrase = it },
            placeholder = "two avocados",
            imeAction = ImeAction.Go,
            onImeAction = { matchPhrase() },
            testTag = "VoicePhraseField",
        )
        if (status != null) {
            Text(text = status!!, style = MekasaType.label, color = MekasaColor.warning)
        }
        PrimaryButton(
            title = "Match product",
            enabled = phrase.isNotBlank(),
            isLoading = searching || state.isBusy,
            onClick = { matchPhrase() },
        )
        SecondaryButton(title = "Back", onClick = onBack)
    }
}

@Composable
private fun ReceiptContent(
    state: AppUiState,
    session: AppSession,
    onBack: () -> Unit,
    onLines: (List<ReceiptLineItemDto>, String?) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg)
            .padding(bottom = Spacing.xl)
            .testTag("ReceiptScanView"),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Text(text = "Scan receipt", style = MekasaType.title, color = MekasaColor.brand)
        Text(
            text = "Run the demo haul or paste receipt text. Photo OCR uses the API when available.",
            style = MekasaType.body,
            color = MekasaColor.textMuted,
        )
        PrimaryButton(
            title = if (state.isBusy) "Scanning…" else "Use demo haul",
            isLoading = state.isBusy,
            onClick = {
                session.scanReceipt(rawText = AppSession.DEMO_RECEIPT_TEXT) { response ->
                    onLines(response.items, response.engine)
                }
            },
        )
        SecondaryButton(title = "Back", onClick = onBack)
    }
}

@Composable
private fun ReceiptConfirmContent(
    lines: List<ReceiptLineItemDto>,
    engine: String?,
    isBusy: Boolean,
    onBack: () -> Unit,
    onSave: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = Spacing.lg)
            .padding(bottom = Spacing.xl),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Text(text = "Confirm haul", style = MekasaType.title, color = MekasaColor.brand)
        if (engine != null) {
            Text(text = "Engine: $engine", style = MekasaType.label, color = MekasaColor.textMuted)
        }
        lines.forEach { line ->
            SoftCard {
                Text(text = line.name, style = MekasaType.body, color = MekasaColor.brand)
                Text(
                    text = buildString {
                        append("${line.category} · qty ${line.quantity}")
                        line.pricePaid?.let { append(" · $%.2f".format(it)) }
                        if (!line.identified) append(" · needs review")
                    },
                    style = MekasaType.label,
                    color = if (line.identified) MekasaColor.textMuted else MekasaColor.warning,
                )
            }
        }
        PrimaryButton(
            title = "Add ${lines.size} items",
            enabled = lines.isNotEmpty(),
            isLoading = isBusy,
            onClick = onSave,
        )
        SecondaryButton(title = "Back", onClick = onBack)
    }
}
