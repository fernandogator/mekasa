package app.mekasa.fable.ui.inventory

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import app.mekasa.fable.data.model.InventoryItem
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

@Composable
fun InventoryScreen(
    items: List<InventoryItem>,
    onBack: () -> Unit,
    onConsume: (InventoryItem) -> Unit,
    onOpenItem: (InventoryItem) -> Unit,
    onAdd: () -> Unit,
) {
    val palette = MekasaTheme.palette
    var query by rememberSaveable { mutableStateOf("") }
    val filtered = items.filter { query.isBlank() || it.name.contains(query, true) || it.category.contains(query, true) }
    val grouped = filtered.groupBy { it.category }.toSortedMap()

    Backdrop(modifier = Modifier.testTag("InventoryScreen")) {
        Column(modifier = Modifier.fillMaxSize()) {
            ScreenHeader(
                title = "Inventory",
                eyebrow = "${items.size} items · ${items.count { it.isLowStock }} low",
                onBack = onBack,
                trailing = { LinkButton("Add", onClick = onAdd) },
            )
            if (items.isEmpty()) {
                EmptyMessage("Nothing in the pantry yet. Tap + to scan your first item.", modifier = Modifier.testTag("InventoryEmpty"))
                Box(modifier = Modifier.padding(horizontal = Space.lg)) {
                    PrimaryButton("Add items", onClick = onAdd)
                }
                return@Column
            }
            LazyColumn(
                modifier = Modifier.fillMaxSize().testTag("InventoryList"),
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
                        testTag = "InventorySearch",
                    )
                }
                if (filtered.isEmpty()) {
                    item { EmptyMessage("No items match \"$query\".") }
                }
                grouped.forEach { (category, rows) ->
                    item(key = "header-$category") {
                        Text(category.uppercase(), style = Type.label, color = palette.textMuted, modifier = Modifier.padding(top = Space.sm))
                    }
                    items(rows, key = { it.id }) { item ->
                        SwipeToUseRow(item = item, onConsume = { onConsume(item) }) {
                            InventoryRow(item = item, onClick = { onOpenItem(item) }, onConsume = { onConsume(item) })
                        }
                    }
                }
            }
        }
    }
}

/** REQ-INV-014: trailing swipe reveals "Use 1"; the row springs back after the decrement. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SwipeToUseRow(
    item: InventoryItem,
    onConsume: () -> Unit,
    content: @Composable () -> Unit,
) {
    val palette = MekasaTheme.palette
    val swipeState = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            if (value == SwipeToDismissBoxValue.EndToStart && item.quantity > 0) onConsume()
            false
        },
    )
    SwipeToDismissBox(
        state = swipeState,
        enableDismissFromStartToEnd = false,
        enableDismissFromEndToStart = item.quantity > 0,
        backgroundContent = {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .clip(Shapes.card)
                    .background(palette.accent)
                    .padding(horizontal = Space.lg),
                contentAlignment = Alignment.CenterEnd,
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.xs)) {
                    Icon(Icons.Filled.Remove, contentDescription = null, tint = androidx.compose.ui.graphics.Color.White)
                    Text("Use 1", style = Type.button, color = androidx.compose.ui.graphics.Color.White)
                }
            }
        },
    ) {
        content()
    }
}

@Composable
fun InventoryRow(
    item: InventoryItem,
    onClick: (() -> Unit)? = null,
    onConsume: (() -> Unit)? = null,
) {
    val palette = MekasaTheme.palette
    Card(onClick = onClick, padding = PaddingValues(Space.md), modifier = Modifier.testTag("InventoryRow-${item.id}")) {
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
                LinkButton("Use 1", onClick = onConsume, modifier = Modifier.testTag("UseOne-${item.id}"))
            }
        }
    }
}
