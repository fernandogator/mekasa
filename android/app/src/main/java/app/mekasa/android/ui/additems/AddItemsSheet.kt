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
import app.mekasa.android.session.AppSession
import app.mekasa.android.session.AppUiState
import app.mekasa.android.session.PendingInventoryDraft
import app.mekasa.android.ui.components.BarcodeCameraOrPermission
import app.mekasa.android.ui.components.MekasaTextField
import app.mekasa.android.ui.components.PrimaryButton
import app.mekasa.android.ui.components.SecondaryButton
import app.mekasa.android.ui.components.SoftCard
import app.mekasa.android.ui.theme.MekasaColor
import app.mekasa.android.ui.theme.MekasaType
import app.mekasa.android.ui.theme.Spacing
import kotlinx.coroutines.launch

private enum class AddStep {
    Hub,
    Barcode,
    Search,
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
            text = "Scan a barcode, search the product catalog, or open the trash station.",
            style = MekasaType.body,
            color = MekasaColor.textMuted,
        )
        PrimaryButton(title = "Scan / enter barcode", onClick = onBarcode)
        SecondaryButton(title = "Search products", onClick = onSearch)
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
                    if (!result.found) {
                        status = "Not in catalog — confirm name before saving"
                    }
                }
            } catch (e: Exception) {
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
