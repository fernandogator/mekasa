package app.mekasa.fable.ui.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.outlined.Inventory2
import androidx.compose.material.icons.outlined.PieChart
import androidx.compose.material.icons.outlined.WarningAmber
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import app.mekasa.fable.data.model.InventoryItem
import app.mekasa.fable.session.SessionState
import app.mekasa.fable.session.SessionViewModel
import app.mekasa.fable.ui.components.Card
import app.mekasa.fable.ui.components.Chip
import app.mekasa.fable.ui.components.HomePhoto
import app.mekasa.fable.ui.components.IconWell
import app.mekasa.fable.ui.components.LinkButton
import app.mekasa.fable.ui.components.SectionHeading
import app.mekasa.fable.ui.components.moneyCompact
import app.mekasa.fable.ui.components.plural
import app.mekasa.fable.ui.inventory.InventoryRow
import app.mekasa.fable.ui.theme.MekasaTheme
import app.mekasa.fable.ui.theme.Shapes
import app.mekasa.fable.ui.theme.Space
import app.mekasa.fable.ui.theme.Type

@Composable
fun DashboardScreen(
    state: SessionState,
    session: SessionViewModel,
    contentPadding: PaddingValues,
    onOpenInventory: () -> Unit,
    onOpenItem: (InventoryItem) -> Unit,
    onOpenList: () -> Unit,
    onOpenSpending: () -> Unit,
    onEditHome: () -> Unit,
) {
    val palette = MekasaTheme.palette
    val data = state.data
    val household = state.household
    val lowStock = data.lowStock
    val approvals = data.pendingApprovals

    LazyColumn(
        modifier = Modifier.fillMaxSize().testTag("DashboardScreen"),
        contentPadding = PaddingValues(
            start = Space.lg,
            end = Space.lg,
            top = Space.base,
            bottom = contentPadding.calculateBottomPadding() + Space.xxl,
        ),
        verticalArrangement = Arrangement.spacedBy(Space.base),
    ) {
        item {
            HeroBand(
                name = household?.name?.takeIf { it.isNotBlank() } ?: "Your home",
                address = household?.address,
                photoUrl = household?.photoUrl,
                isDemo = state.isDemo,
                onEdit = onEditHome,
            )
        }

        item {
            Row(horizontalArrangement = Arrangement.spacedBy(Space.md)) {
                StatCard(
                    modifier = Modifier.weight(1f).testTag("LowStockStat"),
                    label = "Low stock",
                    value = plural(lowStock.size, "item"),
                    icon = Icons.Outlined.WarningAmber,
                    tint = palette.accent,
                    tintBackground = palette.accentTint,
                    onClick = onOpenInventory,
                )
                StatCard(
                    modifier = Modifier.weight(1f).testTag("SpendStat"),
                    label = "Spend",
                    value = data.spending?.let { moneyCompact(it.total, it.currency) } ?: "—",
                    suffix = "/${data.spendingPeriod.take(2)}",
                    icon = Icons.Outlined.PieChart,
                    tint = palette.success,
                    tintBackground = palette.successTint,
                    onClick = onOpenSpending,
                )
            }
        }

        if (approvals.isNotEmpty()) {
            item {
                SectionHeading("Needs approval", actionLabel = "Open list", onAction = onOpenList)
            }
            items(approvals.take(3), key = { "approval-${it.id}" }) { request ->
                Card(tint = palette.warningTint) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.md)) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(request.name, style = Type.body, color = palette.text)
                            Text(
                                listOfNotNull("qty ${request.quantity}", request.requestedBy?.let { "asked by $it" }).joinToString(" · "),
                                style = Type.caption,
                                color = palette.warning,
                            )
                        }
                        Chip("Pending", color = palette.warning)
                    }
                    if (state.isOwner) {
                        Row(horizontalArrangement = Arrangement.spacedBy(Space.sm)) {
                            LinkButton("Approve", onClick = { session.approveShoppingItem(request.id) }, color = palette.success)
                            LinkButton("Reject", onClick = { session.rejectShoppingItem(request.id) })
                        }
                    }
                }
            }
        }

        item {
            SectionHeading("Low stock", actionLabel = "See inventory", onAction = onOpenInventory)
        }
        if (lowStock.isEmpty()) {
            item {
                Card {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.md)) {
                        IconWell(Icons.Outlined.Inventory2, tint = palette.success, background = palette.successTint)
                        Text("Everything is stocked up.", style = Type.body, color = palette.textMuted)
                    }
                }
            }
        } else {
            items(lowStock.take(4), key = { "low-${it.id}" }) { item ->
                InventoryRow(item = item, onClick = { onOpenItem(item) }, onConsume = { session.consume(item.id) })
            }
        }

        item {
            SectionHeading("Shopping list", actionLabel = "Open list", onAction = onOpenList)
            Spacer(Modifier.height(Space.sm))
            val open = data.openShopping
            Card(onClick = onOpenList) {
                Text(
                    if (open.isEmpty()) "Nothing to pick up right now." else "${plural(open.size, "item")} to pick up",
                    style = Type.body,
                    color = palette.text,
                )
                if (open.isNotEmpty()) {
                    Text(
                        open.take(4).joinToString(", ") { it.name } + if (open.size > 4) "…" else "",
                        style = Type.caption,
                        color = palette.textMuted,
                    )
                }
            }
        }

        val recent = data.inventory.take(5)
        if (recent.isNotEmpty()) {
            item { SectionHeading("Recently added") }
            items(recent, key = { "recent-${it.id}" }) { item ->
                InventoryRow(item = item, onClick = { onOpenItem(item) }, onConsume = { session.consume(item.id) })
            }
        }
    }
}

/** UI-004 AC3: the home photo is the hero band; the name and address sit on a gradient scrim. */
@Composable
private fun HeroBand(
    name: String,
    address: String?,
    photoUrl: String?,
    isDemo: Boolean,
    onEdit: () -> Unit,
) {
    val palette = MekasaTheme.palette
    Column(modifier = Modifier.fillMaxWidth().statusBarsPadding()) {
        Text(
            if (isDemo) "Offline preview" else "Welcome back",
            style = Type.label,
            color = palette.textMuted,
            modifier = Modifier.padding(bottom = Space.sm),
        )
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(190.dp)
                .clip(Shapes.card)
                .clickable(onClick = onEdit)
                .testTag("HomeHero"),
        ) {
            HomePhoto(photoUrl = photoUrl, modifier = Modifier.fillMaxSize())
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(Color(0x1A171E19), Color(0x99171E19)),
                        ),
                    ),
            )
            Column(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(Space.base),
            ) {
                Text(name, style = Type.title, color = Color.White)
                if (!address.isNullOrBlank()) {
                    Text(address, style = Type.caption, color = Color.White.copy(alpha = 0.85f))
                }
            }
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(Space.md)
                    .size(40.dp)
                    .background(Color.White.copy(alpha = 0.25f), CircleShape)
                    .testTag("EditHomeButton"),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.PhotoCamera, contentDescription = "Edit home photo", tint = Color.White, modifier = Modifier.size(20.dp))
            }
        }
    }
}

@Composable
private fun StatCard(
    modifier: Modifier,
    label: String,
    value: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    tint: Color,
    tintBackground: Color,
    onClick: () -> Unit,
    suffix: String? = null,
) {
    val palette = MekasaTheme.palette
    Card(modifier = modifier, onClick = onClick, padding = PaddingValues(Space.base)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.sm)) {
            IconWell(icon, tint = tint, background = tintBackground, size = 32.dp)
            Text(label, style = Type.caption, color = palette.textMuted)
        }
        Spacer(Modifier.height(Space.sm))
        Row(verticalAlignment = Alignment.Bottom) {
            Text(value, style = Type.stat, color = palette.text)
            if (suffix != null) {
                Text(suffix, style = Type.caption, color = palette.textMuted, modifier = Modifier.padding(start = 2.dp, bottom = 3.dp))
            }
        }
    }
}
