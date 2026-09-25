package app.mekasa.fable.ui.inventory

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import app.mekasa.fable.data.model.InventoryItem
import app.mekasa.fable.session.PendingRemoval
import app.mekasa.fable.ui.TestTags
import app.mekasa.fable.ui.components.Backdrop
import app.mekasa.fable.ui.components.Card
import app.mekasa.fable.ui.components.Chip
import app.mekasa.fable.ui.components.EmptyMessage
import app.mekasa.fable.ui.components.LabeledField
import app.mekasa.fable.ui.components.LinkButton
import app.mekasa.fable.ui.components.PrimaryButton
import app.mekasa.fable.ui.components.ProductThumbnail
import app.mekasa.fable.ui.components.ScreenHeader
import app.mekasa.fable.ui.theme.MekasaTheme
import app.mekasa.fable.ui.theme.Shapes
import app.mekasa.fable.ui.theme.Space
import app.mekasa.fable.ui.theme.Type

/**
 * UI-006: grouped inventory with search and thumbnails. Trailing swipe is "Use 1" when
 * quantity > 1 (REQ-INV-014) and "Remove" when quantity is 1 or less (REQ-INV-015); a
 * removal shows the "Item removed · Undo" toast until the undo window closes (REQ-INV-016/017).
 */
@Composable
fun InventoryScreen(
    items: List<InventoryItem>,
    onBack: () -> Unit,
    onConsume: (InventoryItem) -> Unit,
    onOpenItem: (InventoryItem) -> Unit,
    onAdd: () -> Unit,
    pendingRemoval: PendingRemoval? = null,
    onRemove: (InventoryItem) -> Unit = {},
    onUndoRemove: () -> Unit = {},
) {
    val palette = MekasaTheme.palette
    var query by rememberSaveable { mutableStateOf("") }
    val filtered = items.filter { query.isBlank() || it.name.contains(query, true) || it.category.contains(query, true) }
    val grouped = filtered.groupBy { it.category }.toSortedMap()

    Backdrop(modifier = Modifier.testTag(TestTags.INVENTORY_LIST_VIEW)) {
        Column(modifier = Modifier.fillMaxSize()) {
            ScreenHeader(
                title = "Inventory",
                eyebrow = "${items.size} items · ${items.count { it.isLowStock }} low",
                onBack = onBack,
                trailing = { LinkButton("Add", onClick = onAdd, modifier = Modifier.testTag(TestTags.INVENTORY_ADD_BUTTON)) },
            )
            if (items.isEmpty()) {
                EmptyMessage(
                    "Nothing in the pantry yet. Tap + to scan your first item.",
                    modifier = Modifier.testTag(TestTags.EMPTY_STATE_VIEW),
                )
                Box(modifier = Modifier.padding(horizontal = Space.lg)) {
                    PrimaryButton("Add items", onClick = onAdd)
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize().testTag(TestTags.ITEM_LIST),
                    contentPadding = PaddingValues(start = Space.lg, end = Space.lg, top = Space.sm, bottom = Space.xxl),
                    verticalArrangement = Arrangement.spacedBy(Space.md),
                ) {
                    item {
                        LabeledField(
                            label = "Search",
                            value = query,
                            onValueChange = { query = it },
                            placeholder = "milk, snacks…",
                            imeAction = ImeAction.Search,
                            capitalization = KeyboardCapitalization.None,
                            testTag = TestTags.INVENTORY_SEARCH,
                        )
                    }
                    if (filtered.isEmpty()) {
                        item { EmptyMessage("No items match \"$query\".") }
                    }
                    grouped.forEach { (category, rows) ->
                        item(key = "header-$category") {
                            Text(
                                category.uppercase(),
                                style = Type.label,
                                color = palette.textMuted,
                                modifier = Modifier.padding(top = Space.sm),
                            )
                        }
                        items(rows, key = { it.id }) { item ->
                            SwipeableInventoryRow(
                                item = item,
                                onConsume = { onConsume(item) },
                                onRemove = { onRemove(item) },
                            ) {
                                InventoryRow(item = item, onClick = { onOpenItem(item) }, onConsume = { onConsume(item) })
                            }
                        }
                    }
                }
            }
        }

        UndoToast(
            visible = pendingRemoval != null,
            onUndo = onUndoRemove,
            modifier = Modifier.align(Alignment.BottomCenter),
        )
    }
}

/** Which trailing action a swipe reveals for [item] (REQ-INV-014 vs REQ-INV-015). */
enum class SwipeAction { UseOne, Remove }

fun InventoryItem.swipeAction(): SwipeAction = if (quantity > 1) SwipeAction.UseOne else SwipeAction.Remove

/**
 * Trailing swipe reveals the accent-red action pane. Use 1 springs the row back after the
 * decrement; Remove hands off to the caller, who drops the row from the list.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SwipeableInventoryRow(
    item: InventoryItem,
    onConsume: () -> Unit,
    onRemove: () -> Unit,
    content: @Composable () -> Unit,
) {
    val action = item.swipeAction()
    val swipeState = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            if (value == SwipeToDismissBoxValue.EndToStart) {
                when (action) {
                    SwipeAction.UseOne -> onConsume()
                    SwipeAction.Remove -> onRemove()
                }
            }
            false
        },
    )
    SwipeToDismissBox(
        state = swipeState,
        enableDismissFromStartToEnd = false,
        backgroundContent = { SwipeActionPane(action) },
    ) {
        content()
    }
}

/** The revealed pane behind a swiped row: minus + "Use 1" or trash + "Remove", both in accent red. */
@Composable
fun SwipeActionPane(action: SwipeAction, modifier: Modifier = Modifier) {
    val palette = MekasaTheme.palette
    val tag = when (action) {
        SwipeAction.UseOne -> TestTags.INVENTORY_USE_ONE_ACTION
        SwipeAction.Remove -> TestTags.INVENTORY_REMOVE_ACTION
    }
    Box(
        modifier = modifier
            .fillMaxSize()
            .clip(Shapes.card)
            .background(palette.accent)
            .padding(horizontal = Space.lg)
            .testTag(tag),
        contentAlignment = Alignment.CenterEnd,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.xs)) {
            when (action) {
                SwipeAction.UseOne -> {
                    Icon(Icons.Filled.Remove, contentDescription = null, tint = Color.White)
                    Text("Use 1", style = Type.button, color = Color.White)
                }
                SwipeAction.Remove -> {
                    Icon(Icons.Filled.Delete, contentDescription = null, tint = Color.White)
                    Text("Remove", style = Type.button, color = Color.White)
                }
            }
        }
    }
}

/** REQ-INV-016 AC3: bottom toast on brand charcoal with an Undo action. */
@Composable
private fun UndoToast(
    visible: Boolean,
    onUndo: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val palette = MekasaTheme.palette
    AnimatedVisibility(
        visible = visible,
        modifier = modifier,
        enter = slideInVertically { it } + fadeIn(),
        exit = slideOutVertically { it } + fadeOut(),
    ) {
        Row(
            modifier = Modifier
                .navigationBarsPadding()
                .padding(horizontal = Space.lg, vertical = Space.base)
                .fillMaxWidth()
                .clip(Shapes.pill)
                .background(palette.brand)
                .padding(start = Space.lg, end = Space.sm, top = Space.xs, bottom = Space.xs)
                .testTag(TestTags.INVENTORY_UNDO_TOAST),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Item removed", style = Type.body, color = Color.White, modifier = Modifier.weight(1f))
            TextButton(onClick = onUndo, modifier = Modifier.testTag(TestTags.INVENTORY_UNDO_BUTTON)) {
                Text("Undo", style = Type.button, color = palette.brandMuted)
            }
        }
    }
}

@Composable
fun InventoryRow(
    item: InventoryItem,
    onClick: (() -> Unit)? = null,
    onConsume: (() -> Unit)? = null,
) {
    val palette = MekasaTheme.palette
    Card(onClick = onClick, padding = PaddingValues(Space.md), modifier = Modifier.testTag(TestTags.itemCell(item.id))) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Space.md),
        ) {
            ProductThumbnail(imageUrl = item.imageUrl, name = item.name)
            Column(modifier = Modifier.weight(1f)) {
                Text(item.name, style = Type.body, color = palette.text, maxLines = 2)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.sm)) {
                    Text("${item.category} · qty ${item.quantity}", style = Type.caption, color = palette.textMuted)
                    if (item.isLowStock) Chip(if (item.quantity == 0) "Out" else "Low", color = palette.warning)
                }
            }
            if (onConsume != null && item.quantity > 0) {
                LinkButton("Use 1", onClick = onConsume, modifier = Modifier.testTag(TestTags.useOne(item.id)))
            }
        }
    }
}
