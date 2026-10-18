package app.mekasa.fable.ui.stores

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import app.mekasa.fable.data.model.Store
import app.mekasa.fable.session.SessionState
import app.mekasa.fable.session.SessionViewModel
import app.mekasa.fable.session.StorePickerResult
import app.mekasa.fable.ui.TestTags
import app.mekasa.fable.ui.components.Backdrop
import app.mekasa.fable.ui.components.EmptyMessage
import app.mekasa.fable.ui.components.LabeledField
import app.mekasa.fable.ui.components.PrimaryButton
import app.mekasa.fable.ui.components.SecondaryButton
import app.mekasa.fable.ui.components.miles
import app.mekasa.fable.ui.shopping.ShoppingStores
import app.mekasa.fable.ui.shopping.ShoppingStores.toStore
import app.mekasa.fable.ui.theme.MekasaTheme
import app.mekasa.fable.ui.theme.Shapes
import app.mekasa.fable.ui.theme.Space
import app.mekasa.fable.ui.theme.Type

/** Search radius the API uses for nearby stores (REQ-003 AC8). */
private const val SEARCH_RADIUS_MILES = 15

/** "950 W Peachtree St · 0.8 mi" under a store's name. Satisfies: REQ-003 AC11 */
fun storeDetailLine(address: String, distanceMiles: Double?): String =
    listOfNotNull(address.ifBlank { null }, distanceMiles?.takeIf { it > 0 }?.let(::miles)).joinToString(" · ")

/** Initial-letter circle standing in for a store logo (design 02-store-selection). Satisfies: REQ-003 AC11 */
@Composable
fun StoreLogo(name: String, modifier: Modifier = Modifier) {
    val palette = MekasaTheme.palette
    Box(
        modifier = modifier.size(40.dp).background(palette.overlay, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Text(name.trim().take(1).uppercase(), style = Type.subhead, color = palette.brand)
    }
}

/**
 * One checkable store, shared by the onboarding step and the settings picker.
 * [showLogo] adds the logo circle the settings picker shows. Satisfies: REQ-003 AC11
 */
@Composable
fun StoreRow(store: Store, selected: Boolean, onClick: () -> Unit, showLogo: Boolean = false) {
    val palette = MekasaTheme.palette
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(palette.surfaceElevated, Shapes.card)
            .border(
                width = if (selected) 2.dp else 1.dp,
                color = if (selected) palette.accent else palette.brandMuted.copy(alpha = 0.3f),
                shape = Shapes.card,
            )
            .clickable(onClick = onClick)
            .padding(Space.base)
            .testTag(TestTags.storeRow(store.id)),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Space.md),
    ) {
        if (showLogo) StoreLogo(store.name)
        if (!showLogo) CheckMark(selected)
        Column(modifier = Modifier.weight(1f)) {
            Text(store.name, style = Type.body, color = palette.text)
            Text(storeDetailLine(store.address, store.distanceMiles), style = Type.caption, color = palette.textMuted)
        }
        if (showLogo) CheckMark(selected)
    }
}

@Composable
private fun CheckMark(selected: Boolean) {
    val palette = MekasaTheme.palette
    Icon(
        imageVector = if (selected) Icons.Filled.CheckCircle else Icons.Outlined.Circle,
        contentDescription = if (selected) "Selected" else "Not selected",
        tint = if (selected) palette.accent else palette.border,
    )
}

/** The checkable store rows, or [emptyText] when there are none. Satisfies: REQ-003 AC11 */
@Composable
fun StoreList(
    stores: List<Store>,
    selectedIds: Set<String>,
    onToggle: (String) -> Unit,
    emptyText: String,
    showLogo: Boolean = false,
) {
    if (stores.isEmpty()) {
        EmptyMessage(emptyText)
    } else {
        Column(verticalArrangement = Arrangement.spacedBy(Space.base)) {
            stores.forEach { store ->
                StoreRow(store = store, selected = store.id in selectedIds, onClick = { onToggle(store.id) }, showLogo = showLogo)
            }
        }
    }
}

private sealed interface PickerStep {
    data object Loading : PickerStep
    data object Address : PickerStep
    data class Stores(val candidates: List<Store>) : PickerStep
}

/**
 * Settings store picker (design 02-store-selection): asks for the home address when the
 * household has no coordinates, then lists nearby stores to search and check. Starts with
 * only the stores saved with details checked; Confirm saves and closes, Cancel just closes.
 * Satisfies: REQ-003 AC11
 */
@Composable
fun StorePickerDialog(
    state: SessionState,
    session: SessionViewModel,
    onDismiss: () -> Unit,
) {
    val palette = MekasaTheme.palette
    val saved = state.household?.stores.orEmpty()
    var step by remember { mutableStateOf<PickerStep>(PickerStep.Loading) }
    var selected by remember { mutableStateOf(ShoppingStores.pickerSelection(state.household)) }
    var query by remember { mutableStateOf("") }
    var address by remember { mutableStateOf(state.household?.address.orEmpty()) }
    var error by remember { mutableStateOf<String?>(null) }
    var working by remember { mutableStateOf(false) }

    fun show(result: StorePickerResult, failedStep: PickerStep) {
        working = false
        when (result) {
            StorePickerResult.NeedsAddress -> { error = null; step = PickerStep.Address }
            is StorePickerResult.Stores -> { error = null; step = PickerStep.Stores(ShoppingStores.pickerCandidates(result.stores, saved)) }
            is StorePickerResult.Failed -> { error = result.message; step = failedStep }
        }
    }

    LaunchedEffect(Unit) {
        session.loadStorePicker { show(it, PickerStep.Stores(saved.map { s -> s.toStore() })) }
    }

    fun findStores() {
        if (address.isBlank() || working) return
        working = true
        error = null
        session.findStoresNear(address) { show(it, PickerStep.Address) }
    }

    fun confirm(candidates: List<Store>) {
        if (selected.isEmpty() || working) return
        working = true
        error = null
        session.saveStores(selected, candidates) { failure ->
            working = false
            if (failure == null) onDismiss() else error = failure
        }
    }

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Backdrop(modifier = Modifier.testTag(TestTags.STORE_PICKER)) {
            Column(modifier = Modifier.fillMaxSize()) {
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .verticalScroll(rememberScrollState())
                        .statusBarsPadding()
                        .padding(Space.lg),
                    verticalArrangement = Arrangement.spacedBy(Space.base),
                ) {
                    val current = step
                    if (current == PickerStep.Address) {
                        Text("Where's home?", style = Type.title, color = palette.text)
                        Text(
                            "We look for grocery stores within $SEARCH_RADIUS_MILES miles of your home.",
                            style = Type.bodyRegular,
                            color = palette.textMuted,
                        )
                        LabeledField(
                            label = "Home address",
                            value = address,
                            onValueChange = { address = it },
                            placeholder = "123 Peachtree St, Atlanta, GA",
                            capitalization = KeyboardCapitalization.Words,
                            imeAction = ImeAction.Done,
                            onSubmit = ::findStores,
                            testTag = TestTags.STORE_PICKER_ADDRESS_FIELD,
                        )
                    } else {
                        Text("Where do you shop?", style = Type.title, color = palette.text)
                        Text(
                            state.household?.address?.takeIf { it.isNotBlank() }
                                ?.let { "We'll look within $SEARCH_RADIUS_MILES miles of $it" }
                                ?: "We'll look within $SEARCH_RADIUS_MILES miles of home",
                            style = Type.bodyRegular,
                            color = palette.textMuted,
                        )
                    }
                    error?.let {
                        Text(it, style = Type.caption, color = palette.danger, modifier = Modifier.testTag(TestTags.STORE_PICKER_ERROR))
                    }
                    when (current) {
                        PickerStep.Loading -> Box(
                            modifier = Modifier.fillMaxWidth().padding(Space.xl).testTag(TestTags.STORE_PICKER_LOADING),
                            contentAlignment = Alignment.Center,
                        ) {
                            CircularProgressIndicator(color = palette.accent)
                        }
                        PickerStep.Address -> Unit
                        is PickerStep.Stores -> {
                            LabeledField(
                                label = "Search",
                                value = query,
                                onValueChange = { query = it },
                                placeholder = "Store name or address",
                                imeAction = ImeAction.Search,
                                testTag = TestTags.STORE_PICKER_SEARCH,
                                trailing = { Icon(Icons.Outlined.Search, contentDescription = null, tint = palette.textMuted) },
                            )
                            StoreList(
                                stores = ShoppingStores.search(current.candidates, query),
                                selectedIds = selected,
                                onToggle = { id -> selected = if (id in selected) selected - id else selected + id },
                                emptyText = if (current.candidates.isEmpty()) {
                                    "No stores came back for that address."
                                } else {
                                    "No stores match \"${query.trim()}\"."
                                },
                                showLogo = true,
                            )
                        }
                    }
                }
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(palette.surface.copy(alpha = 0.96f))
                        .padding(horizontal = Space.lg, vertical = Space.base),
                    verticalArrangement = Arrangement.spacedBy(Space.sm),
                ) {
                    when (val current = step) {
                        PickerStep.Address -> PrimaryButton(
                            "Find stores",
                            onClick = ::findStores,
                            enabled = address.isNotBlank(),
                            loading = working,
                            modifier = Modifier.testTag(TestTags.STORE_PICKER_FIND),
                        )
                        is PickerStep.Stores -> PrimaryButton(
                            "Confirm stores",
                            onClick = { confirm(current.candidates) },
                            enabled = selected.isNotEmpty(),
                            loading = working,
                            modifier = Modifier.testTag(TestTags.STORE_PICKER_CONFIRM),
                        )
                        PickerStep.Loading -> Spacer(Modifier.height(0.dp))
                    }
                    SecondaryButton("Cancel", onClick = onDismiss, modifier = Modifier.testTag(TestTags.STORE_PICKER_CANCEL))
                }
            }
        }
    }
}
