package app.mekasa.fable.ui.shopping

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import app.mekasa.fable.data.model.ShoppingItem
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
import app.mekasa.fable.ui.theme.Space
import app.mekasa.fable.ui.theme.Type

/**
 * UI-003 / REQ-011–014: grouped list (needs approval → to buy → purchased), custom adds,
 * owner-gated purchase toggle, approve/reject for requests, and inventory sync.
 */
@Composable
fun ShoppingListScreen(
    state: SessionState,
    session: SessionViewModel,
    contentPadding: PaddingValues,
) {
    val palette = MekasaTheme.palette
    val data = state.data
    var composing by rememberSaveable { mutableStateOf(false) }
    var newName by rememberSaveable { mutableStateOf("") }
    var newQty by rememberSaveable { mutableStateOf("1") }

    fun submitNew() {
        if (newName.isBlank()) return
        session.addShoppingItem(newName, newQty.toIntOrNull() ?: 1)
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
                            placeholder = "Avocados",
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
                        Spacer(Modifier.height(Space.md))
                        PrimaryButton("Add to list", onClick = ::submitNew, enabled = newName.isNotBlank(), loading = state.busy, modifier = Modifier.testTag(TestTags.SHOPPING_ADD_SUBMIT))
                        Spacer(Modifier.height(Space.sm))
                        SecondaryButton("Cancel", onClick = { composing = false })
                    }
                }
                if (!composing) {
                    SecondaryButton("Add an item", onClick = { composing = true }, modifier = Modifier.testTag(TestTags.SHOPPING_ADD_TOGGLE))
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
                item { EmptyMessage("Nothing on the list. Sync low stock or add something.", modifier = Modifier.testTag(TestTags.SHOPPING_EMPTY)) }
            }

            val pending = data.pendingApprovals
            if (pending.isNotEmpty()) {
                item { SectionHeading("Needs approval") }
                items(pending, key = { it.id }) { row ->
                    ShoppingRow(
                        item = row,
                        canPurchase = state.canMarkPurchased,
                        isOwner = state.isOwner,
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
                        onToggle = { session.toggleShoppingPurchased(row.id) },
                        onRemove = { session.removeShoppingItem(row.id) },
                    )
                }
            }
        }
    }
}

@Composable
private fun ShoppingRow(
    item: ShoppingItem,
    canPurchase: Boolean,
    isOwner: Boolean,
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
                            else -> palette.brandMuted
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