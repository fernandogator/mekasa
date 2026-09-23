package app.mekasa.android.ui.dashboard

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import app.mekasa.android.data.InventoryItemDto
import app.mekasa.android.data.SpendingReportDto
import app.mekasa.android.session.AppSession
import app.mekasa.android.session.AppUiState
import app.mekasa.android.ui.components.SoftCard
import app.mekasa.android.ui.inventory.InventoryRow
import app.mekasa.android.ui.shell.MainTab
import app.mekasa.android.ui.theme.MekasaColor
import app.mekasa.android.ui.theme.MekasaType
import app.mekasa.android.ui.theme.Spacing
import coil.compose.AsyncImage

@Composable
fun DashboardScreen(
    state: AppUiState,
    session: AppSession,
    onSelectTab: (MainTab) -> Unit,
    onOpenInventory: () -> Unit,
    contentPadding: PaddingValues = PaddingValues(),
) {
    val household = state.household
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(contentPadding)
            .padding(horizontal = Spacing.lg)
            .padding(top = Spacing.base, bottom = Spacing.xxl)
            .testTag("DashboardView"),
        verticalArrangement = Arrangement.spacedBy(Spacing.base),
    ) {
        Text(
            text = household?.name ?: "Your home",
            style = MekasaType.display,
            color = MekasaColor.brand,
        )
        if (!household?.photoUrl.isNullOrBlank()) {
            AsyncImage(
                model = household?.photoUrl,
                contentDescription = "Home photo",
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp),
                contentScale = ContentScale.Crop,
            )
        } else if (!household?.address.isNullOrBlank()) {
            Text(
                text = household?.address.orEmpty(),
                style = MekasaType.body,
                color = MekasaColor.textMuted,
            )
        }

        SpendingCard(
            spending = state.spending,
            onClick = { onSelectTab(MainTab.Spend) },
        )

        val pending = state.shoppingList.filter { it.needsApproval }
        if (pending.isNotEmpty()) {
            SectionHeader(
                title = "Needs approval",
                action = "Open list",
                onAction = { onSelectTab(MainTab.List) },
            )
            pending.take(3).forEach { item ->
                SoftCard {
                    Text(text = item.name, style = MekasaType.body, color = MekasaColor.brand)
                    Text(
                        text = "qty ${item.quantity}" +
                            (item.requestedBy?.let { " · $it" } ?: ""),
                        style = MekasaType.label,
                        color = MekasaColor.warning,
                    )
                    Row {
                        TextButton(onClick = { session.approveShoppingItem(item.id) }) {
                            Text("Approve", color = MekasaColor.success, style = MekasaType.label)
                        }
                        TextButton(onClick = { session.rejectShoppingItem(item.id) }) {
                            Text("Reject", color = MekasaColor.accent, style = MekasaType.label)
                        }
                    }
                }
            }
        }

        SectionHeader(
            title = "Low stock",
            action = "See inventory",
            onAction = onOpenInventory,
        )
        val lowStock = state.inventory.filter { it.quantity <= it.lowStockThreshold }.take(4)
        if (lowStock.isEmpty()) {
            SoftCard {
                Text(
                    text = "Everything looks stocked.",
                    style = MekasaType.body,
                    color = MekasaColor.textMuted,
                )
            }
        } else {
            lowStock.forEach { item ->
                InventoryRow(
                    item = item,
                    onConsume = { session.consumeInventoryItem(item.id) },
                )
            }
        }

        SectionHeader(
            title = "Shopping list",
            action = "Open list",
            onAction = { onSelectTab(MainTab.List) },
        )
        SoftCard {
            val open = state.shoppingList.filter { !it.isChecked }
            Text(
                text = if (open.isEmpty()) {
                    "List is clear"
                } else {
                    "${open.size} item${if (open.size == 1) "" else "s"} to pick up"
                },
                style = MekasaType.body,
                color = MekasaColor.brand,
                modifier = Modifier.clickable { onSelectTab(MainTab.List) },
            )
        }

        RecentInventory(
            items = state.inventory.take(5),
            onConsume = { session.consumeInventoryItem(it) },
        )
    }
}

@Composable
private fun SpendingCard(
    spending: SpendingReportDto?,
    onClick: () -> Unit,
) {
    SoftCard(modifier = Modifier.clickable(onClick = onClick)) {
        Text(
            text = "SPENDING THIS WEEK",
            style = MekasaType.label,
            color = MekasaColor.textMuted,
        )
        Box(modifier = Modifier.height(Spacing.sm))
        Text(
            text = spending?.totalSpent?.let { "$%.2f".format(it) } ?: "—",
            style = MekasaType.title,
            color = MekasaColor.brand,
        )
        if (!spending?.categories.isNullOrEmpty()) {
            Box(modifier = Modifier.height(Spacing.sm))
            Text(
                text = spending!!.categories.take(3).joinToString(" · ") {
                    "${it.category} $%.0f".format(it.total)
                },
                style = MekasaType.label,
                color = MekasaColor.textMuted,
            )
        }
    }
}

@Composable
private fun SectionHeader(
    title: String,
    action: String,
    onAction: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(text = title, style = MekasaType.subhead, color = MekasaColor.brand)
        TextButton(onClick = onAction) {
            Text(text = action, color = MekasaColor.accent, style = MekasaType.label)
        }
    }
}

@Composable
private fun RecentInventory(
    items: List<InventoryItemDto>,
    onConsume: (String) -> Unit,
) {
    if (items.isEmpty()) return
    Text(text = "Recent items", style = MekasaType.subhead, color = MekasaColor.brand)
    items.forEach { item ->
        InventoryRow(item = item, onConsume = { onConsume(item.id) })
    }
}
