package app.mekasa.fable.ui.shopping

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.MoreVert
import androidx.compose.material.icons.outlined.Storefront
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import app.mekasa.fable.data.model.SavedStore
import app.mekasa.fable.data.model.ShoppingItem
import app.mekasa.fable.session.HouseholdData
import app.mekasa.fable.session.SessionState
import app.mekasa.fable.session.SessionViewModel
import app.mekasa.fable.ui.TestTags
import app.mekasa.fable.ui.components.Card
import app.mekasa.fable.ui.components.Chip
import app.mekasa.fable.ui.components.EmptyMessage
import app.mekasa.fable.ui.components.LabeledField
import app.mekasa.fable.ui.components.LinkButton
import app.mekasa.fable.ui.components.PrimaryButton
import app.mekasa.fable.ui.components.ScreenHeader
import app.mekasa.fable.ui.components.SecondaryButton
import app.mekasa.fable.ui.components.SectionHeading
import app.mekasa.fable.ui.theme.MekasaTheme
import app.mekasa.fable.ui.theme.Shapes
import app.mekasa.fable.ui.theme.Space
import app.mekasa.fable.ui.theme.Type

/**
 * UI-003 / REQ-011–014: grouped list (needs approval → to buy → purchased), custom adds,
 * owner-gated purchase toggle, approve/reject for requests, and inventory sync.
 * Where the household has saved stores, a store selector shows one list per store
 * plus "Any store", and rows can move between them. Satisfies: REQ-024 AC7
 */
@Composable
fun ShoppingListScreen(
    state: SessionState,
    session: SessionViewModel,
    contentPadding: PaddingValues,
) {
    val palette = MekasaTheme.palette
    val asks = state.submitsShoppingRequests
    val saved = state.household?.stores.orEmpty()
    var selection by rememberSaveable { mutableStateOf(ShoppingStores.ALL) }
    val currentList = ShoppingStores.normalizedSelection(selection, saved)
    val rows = ShoppingStores.filter(state.data.shopping, currentList, saved)
    val data = HouseholdData(shopping = rows)
    val addStoreId = ShoppingStores.storeIdForAdd(currentList, saved)
    var composing by rememberSaveable { mutableStateOf(false) }
    var newName by rememberSaveable { mutableStateOf("") }
    var newQty by rememberSaveable { mutableStateOf("1") }

    fun submitNew() {
        if (newName.isBlank()) return
        session.addShoppingItem(newName, newQty.toIntOrNull() ?: 1, storeId = addStoreId)
        newName = ""
        newQty = "1"
        composing = false
    }

    Column(modifier = Modifier.fillMaxSize().testTag(TestTags.SHOPPING_LIST_VIEW)) {
        ScreenHeader(
            title = "Shopping list",
            eyebrow = "${data.openShopping.size} to buy",
            trailing = {
                LinkButton("Sync low stock", onClick = { session.syncShoppingFromInventory() }, modifier = Modifier.testTag(TestTags.SYNC_LOW_STOCK))
            },
        )
        if (saved.isNotEmpty()) {
            StoreSelector(
                tabs = ShoppingStores.tabs(state.data.shopping, saved),
                selected = currentList,
                onSelect = { selection = it },
            )
        }
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                start = Space.lg,
                end = Space.lg,
                top = Space.sm,
                bottom = contentPadding.calculateBottomPadding() + Space.xxl,
            ),
            verticalArrangement = Arrangement.spacedBy(Space.md),
        ) {
            item {
                AnimatedVisibility(visible = composing) {
                    Card(modifier = Modifier.testTag(TestTags.ADD_SHOPPING_CARD)) {
                        LabeledField(
                            label = "Item",
                            value = newName,
                            onValueChange = { newName = it },
                            placeholder = if (asks) "Oreos" else "Avocados",
                            testTag = TestTags.SHOPPING_NAME_FIELD,
                        )
                        Spacer(Modifier.height(Space.sm))
                        LabeledField(
                            label = "Quantity",
                            value = newQty,
                            onValueChange = { newQty = it.filter(Char::isDigit).take(4) },
                            keyboardType = KeyboardType.Number,
                            imeAction = ImeAction.Done,
                            onSubmit = ::submitNew,
                        )
                        if (saved.isNotEmpty()) {
                            Spacer(Modifier.height(Space.sm))
                            Text(
                                "Goes on the ${ShoppingStores.storeName(addStoreId, saved)} list.",
                                style = Type.caption,
                                color = palette.textMuted,
                            )
                        }
                        Spacer(Modifier.height(Space.md))
                        PrimaryButton(if (asks) "Request it" else "Add to list", onClick = ::submitNew, enabled = newName.isNotBlank(), loading = state.busy, modifier = Modifier.testTag(TestTags.SHOPPING_ADD_SUBMIT))
                        Spacer(Modifier.height(Space.sm))
                        SecondaryButton("Cancel", onClick = { composing = false })
                    }
                }
                if (!composing) {
                    SecondaryButton(if (asks) "What do you want?" else "Add an item", onClick = { composing = true }, modifier = Modifier.testTag(TestTags.SHOPPING_ADD_TOGGLE))
                }
            }

            if (saved.isEmpty() && state.isOwner) {
                item {
                    Row(
                        modifier = Modifier.testTag(TestTags.SHOPPING_STORES_HINT),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(Space.sm),
                    ) {
                        Icon(Icons.Outlined.Storefront, contentDescription = null, tint = palette.textMuted)
                        Text(
                            "Want a list per store? Choose your grocery stores in Family settings.",
                            style = Type.caption,
                            color = palette.textMuted,
                        )
                    }
                }
            }

            if (!state.canMarkPurchased) {
                item {
                    Row(
                        modifier = Modifier.testTag(TestTags.PURCHASE_LOCK_NOTICE),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(Space.sm),
                    ) {
                        Icon(Icons.Outlined.Lock, contentDescription = null, tint = palette.textMuted)
                        Text("Only household owners can mark items purchased.", style = Type.caption, color = palette.textMuted)
                    }
                }
            }

            if (data.shopping.isEmpty()) {
                item {
                    EmptyMessage(
                        when {
                            state.data.shopping.isNotEmpty() -> "Nothing on this list yet."
                            asks -> "Nothing to buy yet. Ask for something you want."
                            else -> "Nothing on the list. Sync low stock or add something."
                        },
                        modifier = Modifier.testTag(TestTags.SHOPPING_EMPTY),
                    )
                }
            }

            val showStore = saved.isNotEmpty() && currentList == ShoppingStores.ALL
            val storeLabel: (ShoppingItem) -> String? = { row ->
                if (showStore) ShoppingStores.storeName(row.storeId, saved) else null
            }
            val onMove: ((ShoppingItem, String?) -> Unit)? =
                if (saved.isEmpty()) null else { row, storeId -> session.moveShoppingItem(row.id, storeId) }

            val pending = data.pendingApprovals
            if (pending.isNotEmpty()) {
                item { SectionHeading("Needs approval") }
                items(pending, key = { it.id }) { row ->
                    ShoppingRow(
                        item = row,
                        canPurchase = state.canMarkPurchased,
                        isOwner = state.isOwner,
                        saved = saved,
                        storeLabel = storeLabel(row),
                        onMove = onMove,
                        onToggle = {},
                        onRemove = { session.rejectShoppingItem(row.id) },
                        onApprove = { session.approveShoppingItem(row.id) },
                        onReject = { session.rejectShoppingItem(row.id) },
                    )
                }
            }

            val open = data.openShopping
            if (open.isNotEmpty()) {
                item { SectionHeading("To buy") }
                items(open, key = { it.id }) { row ->
                    ShoppingRow(
                        item = row,
                        canPurchase = state.canMarkPurchased,
                        isOwner = state.isOwner,
                        saved = saved,
                        storeLabel = storeLabel(row),
                        onMove = onMove,
                        onToggle = { session.toggleShoppingPurchased(row.id) },
                        onRemove = { session.removeShoppingItem(row.id) },
                    )
                }
            }

            val done = data.purchased
            if (done.isNotEmpty()) {
                item { SectionHeading("Purchased") }
                items(done, key = { it.id }) { row ->
                    ShoppingRow(
                        item = row,
                        canPurchase = state.canMarkPurchased,
                        isOwner = state.isOwner,
                        saved = saved,
                        storeLabel = storeLabel(row),
                        onMove = onMove,
                        onToggle = { session.toggleShoppingPurchased(row.id) },
                        onRemove = { session.removeShoppingItem(row.id) },
                    )
                }
            }
        }
    }
}

/**
 * One shopping row. [storeLabel] is the row's store, shown while "All stores" is selected;
 * [onMove] adds the "Move to…" menu when the household has saved stores. Satisfies: REQ-024 AC7
 */
@Composable
private fun ShoppingRow(
    item: ShoppingItem,
    canPurchase: Boolean,
    isOwner: Boolean,
    saved: List<SavedStore>,
    storeLabel: String?,
    onMove: ((ShoppingItem, String?) -> Unit)?,
    onToggle: () -> Unit,
    onRemove: () -> Unit,
    onApprove: (() -> Unit)? = null,
    onReject: (() -> Unit)? = null,
) {
    val palette = MekasaTheme.palette
    val locked = !item.isChecked && !canPurchase
    Card(
        modifier = Modifier.testTag(TestTags.shoppingRow(item.id)),
        padding = PaddingValues(horizontal = Space.sm, vertical = Space.sm),
        tint = if (item.needsApproval) palette.warningTint else null,
    ) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            if (!item.needsApproval) {
                IconButton(onClick = onToggle, enabled = !locked, modifier = Modifier.testTag(TestTags.shoppingToggle(item.id))) {
                    Icon(
                        imageVector = when {
                            item.isChecked -> Icons.Filled.CheckCircle
                            locked -> Icons.Outlined.Lock
                            else -> Icons.Outlined.Circle
                        },
                        contentDescription = if (item.isChecked) "Purchased" else "Mark purchased",
                        tint = when {
                            item.isChecked -> palette.success
                            locked -> palette.textMuted
                            else -> palette.border
                        },
                    )
                }
            }
            Column(modifier = Modifier.weight(1f).padding(start = if (item.needsApproval) Space.md else 0.dp)) {
                Text(
                    item.name,
                    style = Type.body,
                    color = if (item.isChecked) palette.textMuted else palette.text,
                    textDecoration = if (item.isChecked) TextDecoration.LineThrough else null,
                )
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.sm)) {
                    Text(
                        listOfNotNull(
                            item.quantityLabel ?: "qty ${item.quantity}",
                            item.requestedBy?.let { "from $it" },
                        ).joinToString(" · "),
                        style = Type.caption,
                        color = palette.textMuted,
                    )
                    when {
                        item.needsApproval -> Chip("Needs approval", color = palette.warning)
                        item.kind == "auto" -> Chip("Auto", color = palette.success)
                    }
                }
                if (storeLabel != null) {
                    Text(
                        storeLabel,
                        style = Type.caption,
                        color = palette.accent,
                        modifier = Modifier.testTag(TestTags.shoppingRowStore(item.id)),
                    )
                }
            }
            if (onMove != null) {
                MoveToStoreMenu(item = item, saved = saved, onMove = { storeId -> onMove(item, storeId) })
            }
            IconButton(onClick = onRemove, modifier = Modifier.testTag(TestTags.shoppingRemove(item.id))) {
                Icon(Icons.Outlined.Delete, contentDescription = "Remove", tint = palette.textMuted)
            }
        }
        if (item.needsApproval && isOwner && onApprove != null && onReject != null) {
            Row(modifier = Modifier.padding(start = Space.sm), horizontalArrangement = Arrangement.spacedBy(Space.sm)) {
                LinkButton("Approve", onClick = onApprove, color = palette.success, modifier = Modifier.testTag(TestTags.approve(item.id)))
                LinkButton("Reject", onClick = onReject, modifier = Modifier.testTag(TestTags.reject(item.id)))
            }
        }
    }
}

/**
 * Horizontal store selector: "All stores", each saved store, "Any store", each with its
 * count of rows still to buy. The selected chip is filled with the brand color.
 * Satisfies: REQ-024 AC7
 */
@Composable
private fun StoreSelector(
    tabs: List<ShoppingStores.Tab>,
    selected: String,
    onSelect: (String) -> Unit,
) {
    val palette = MekasaTheme.palette
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = Space.lg, vertical = Space.xs)
            .selectableGroup()
            .testTag(TestTags.SHOPPING_STORE_SELECTOR),
        horizontalArrangement = Arrangement.spacedBy(Space.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        tabs.forEach { tab ->
            val active = tab.key == selected
            Row(
                modifier = Modifier
                    .heightIn(min = 48.dp)
                    .clip(Shapes.pill)
                    .background(if (active) palette.brand else palette.surfaceElevated)
                    .border(1.dp, if (active) palette.brand else palette.border, Shapes.pill)
                    .selectable(selected = active, role = Role.Tab, onClick = { onSelect(tab.key) })
                    .semantics(mergeDescendants = true) { contentDescription = "${tab.label}, ${tab.toBuy} to buy" }
                    .padding(horizontal = Space.base)
                    .testTag(TestTags.storeChip(tab.key)),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Space.sm),
            ) {
                Text(tab.label, style = Type.caption, color = if (active) palette.onBrand else palette.text)
                Text(tab.toBuy.toString(), style = Type.label, color = if (active) palette.onBrand else palette.textMuted)
            }
        }
    }
}

/**
 * "Move to…" overflow on a row: every saved store plus "Any store", the current list
 * checked. Satisfies: REQ-024 AC7
 */
@Composable
private fun MoveToStoreMenu(
    item: ShoppingItem,
    saved: List<SavedStore>,
    onMove: (String?) -> Unit,
) {
    val palette = MekasaTheme.palette
    var open by remember { mutableStateOf(false) }
    val currentKey = ShoppingStores.listKey(item.storeId, saved)
    Box {
        IconButton(onClick = { open = true }, modifier = Modifier.testTag(TestTags.shoppingMove(item.id))) {
            Icon(Icons.Outlined.MoreVert, contentDescription = "Move ${item.name} to another store", tint = palette.textMuted)
        }
        DropdownMenu(
            expanded = open,
            onDismissRequest = { open = false },
            modifier = Modifier.testTag(TestTags.shoppingMoveMenu(item.id)),
        ) {
            Text(
                "Move to…",
                style = Type.label,
                color = palette.textMuted,
                modifier = Modifier.padding(horizontal = Space.base, vertical = Space.sm),
            )
            val targets = saved.map { it.id to it.name } + (ShoppingStores.ANY to ShoppingStores.ANY_LABEL)
            targets.forEach { (key, label) ->
                val isCurrent = key == currentKey
                DropdownMenuItem(
                    text = { Text(label, style = Type.body, color = palette.text) },
                    onClick = {
                        open = false
                        if (!isCurrent) onMove(key.takeIf { it != ShoppingStores.ANY })
                    },
                    leadingIcon = if (isCurrent) {
                        { Icon(Icons.Filled.Check, contentDescription = "Current list", tint = palette.accent) }
                    } else {
                        null
                    },
                    modifier = Modifier.heightIn(min = 48.dp).testTag(TestTags.shoppingMoveTo(item.id, key)),
                )
            }
        }
    }
}

/** REQ-012: the center + button asks a teen what they want before opening inventory add. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShoppingRequestSheet(
    state: SessionState,
    session: SessionViewModel,
    onDismiss: () -> Unit,
    onAddToHouse: () -> Unit,
) {
    val palette = MekasaTheme.palette
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var name by rememberSaveable { mutableStateOf("") }

    fun submit() {
        if (name.isBlank()) return
        session.addShoppingItem(name)
        onDismiss()
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Space.lg)
                .padding(bottom = Space.xl)
                .testTag(TestTags.TEEN_SHOPPING_ASK),
        ) {
            Text("What do you want?", style = Type.title, color = palette.text)
            Spacer(Modifier.height(Space.sm))
            Text(
                "An owner approves it before it goes on the shopping list.",
                style = Type.body,
                color = palette.textMuted,
            )
            Spacer(Modifier.height(Space.md))
            LabeledField(
                label = "Item",
                value = name,
                onValueChange = { name = it },
                placeholder = "Oreos",
                capitalization = KeyboardCapitalization.Words,
                imeAction = ImeAction.Done,
                onSubmit = ::submit,
                testTag = TestTags.SHOPPING_NAME_FIELD,
            )
            Spacer(Modifier.height(Space.md))
            PrimaryButton("Request it", onClick = ::submit, enabled = name.isNotBlank(), loading = state.busy)
            Spacer(Modifier.height(Space.sm))
            SecondaryButton("Add to the house instead", onClick = onAddToHouse)
        }
    }
}