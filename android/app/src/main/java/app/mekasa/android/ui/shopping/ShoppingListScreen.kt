package app.mekasa.android.ui.shopping

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckBox
import androidx.compose.material.icons.outlined.CheckBoxOutlineBlank
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import app.mekasa.android.data.ShoppingListItemDto
import app.mekasa.android.session.AppSession
import app.mekasa.android.session.AppUiState
import app.mekasa.android.ui.components.EmptyState
import app.mekasa.android.ui.components.MekasaTextField
import app.mekasa.android.ui.components.PrimaryButton
import app.mekasa.android.ui.components.SecondaryButton
import app.mekasa.android.ui.components.SoftCard
import app.mekasa.android.ui.theme.MekasaColor
import app.mekasa.android.ui.theme.MekasaType
import app.mekasa.android.ui.theme.Spacing

@Composable
fun ShoppingListScreen(
    state: AppUiState,
    session: AppSession,
    contentPadding: PaddingValues = PaddingValues(),
) {
    var showAdd by remember { mutableStateOf(false) }
    var newName by remember { mutableStateOf("") }
    var newQty by remember { mutableStateOf("1") }
    val items = state.shoppingList

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .testTag("ShoppingListView"),
        contentPadding = PaddingValues(
            start = Spacing.lg,
            end = Spacing.lg,
            top = contentPadding.calculateTopPadding() + Spacing.base,
            bottom = contentPadding.calculateBottomPadding() + Spacing.xxl,
        ),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(text = "Shopping list", style = MekasaType.title, color = MekasaColor.brand)
                TextButton(onClick = session::syncShoppingFromInventory) {
                    Text("Sync low stock", color = MekasaColor.accent, style = MekasaType.label)
                }
            }
        }
        if (items.isEmpty()) {
            item {
                EmptyState(
                    message = "Nothing to buy yet. Sync low stock or add a custom item.",
                    modifier = Modifier.testTag("ShoppingListEmpty"),
                )
            }
        } else {
            items(items, key = { it.id }) { item ->
                ShoppingRow(
                    item = item,
                    onToggle = { session.toggleShoppingChecked(item.id) },
                    onApprove = { session.approveShoppingItem(item.id) },
                    onReject = { session.rejectShoppingItem(item.id) },
                )
            }
        }
        item {
            if (showAdd) {
                SoftCard {
                    MekasaTextField(
                        label = "Item name",
                        value = newName,
                        onValueChange = { newName = it },
                        placeholder = "Avocados",
                        imeAction = ImeAction.Next,
                        testTag = "ShoppingAddName",
                    )
                    Box(modifier = Modifier.height(Spacing.sm))
                    MekasaTextField(
                        label = "Quantity",
                        value = newQty,
                        onValueChange = { newQty = it.filter { ch -> ch.isDigit() }.take(4) },
                        keyboardType = KeyboardType.Number,
                        imeAction = ImeAction.Done,
                    )
                    Box(modifier = Modifier.height(Spacing.md))
                    PrimaryButton(
                        title = "Add to list",
                        enabled = newName.isNotBlank(),
                        isLoading = state.isBusy,
                        onClick = {
                            session.addShoppingListItem(
                                newName,
                                newQty.toIntOrNull() ?: 1,
                            )
                            newName = ""
                            newQty = "1"
                            showAdd = false
                        },
                    )
                    Box(modifier = Modifier.height(Spacing.sm))
                    SecondaryButton(title = "Cancel") { showAdd = false }
                }
            } else {
                SecondaryButton(title = "Add custom item") { showAdd = true }
            }
        }
    }
}

@Composable
private fun ShoppingRow(
    item: ShoppingListItemDto,
    onToggle: () -> Unit,
    onApprove: () -> Unit,
    onReject: () -> Unit,
) {
    SoftCard {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onToggle),
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = if (item.isChecked) {
                    Icons.Outlined.CheckBox
                } else {
                    Icons.Outlined.CheckBoxOutlineBlank
                },
                contentDescription = if (item.isChecked) "Checked" else "Unchecked",
                tint = if (item.needsApproval) MekasaColor.warning else MekasaColor.brand,
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(text = item.name, style = MekasaType.body, color = MekasaColor.brand)
                Text(
                    text = buildString {
                        append("qty ${item.quantity}")
                        if (item.kind.isNotBlank()) append(" · ${item.kind}")
                        if (item.needsApproval) append(" · needs approval")
                        item.requestedBy?.let { append(" · $it") }
                    },
                    style = MekasaType.label,
                    color = MekasaColor.textMuted,
                )
            }
        }
        if (item.needsApproval) {
            Box(modifier = Modifier.height(Spacing.sm))
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                TextButton(onClick = onApprove) {
                    Text("Approve", color = MekasaColor.success, style = MekasaType.label)
                }
                TextButton(onClick = onReject) {
                    Text("Reject", color = MekasaColor.accent, style = MekasaType.label)
                }
            }
        }
    }
}
