package app.mekasa.android.ui.inventory

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import app.mekasa.android.data.InventoryItemDto
import app.mekasa.android.ui.components.EmptyState
import app.mekasa.android.ui.components.SoftCard
import app.mekasa.android.ui.theme.MekasaColor
import app.mekasa.android.ui.theme.MekasaType
import app.mekasa.android.ui.theme.Spacing
import coil.compose.AsyncImage

@Composable
fun InventoryScreen(
    items: List<InventoryItemDto>,
    onConsume: (String) -> Unit,
    onBack: (() -> Unit)? = null,
    contentPadding: PaddingValues = PaddingValues(),
) {
    if (items.isEmpty()) {
        EmptyState(
            message = "No inventory yet. Tap + to add items.",
            modifier = Modifier
                .fillMaxSize()
                .padding(contentPadding)
                .testTag("InventoryEmpty"),
        )
        return
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .testTag("InventoryList"),
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
                Text(
                    text = "Inventory",
                    style = MekasaType.title,
                    color = MekasaColor.brand,
                )
                if (onBack != null) {
                    TextButton(onClick = onBack) {
                        Text("Back", color = MekasaColor.accent, style = MekasaType.label)
                    }
                }
            }
        }
        items(items, key = { it.id }) { item ->
            InventoryRow(item = item, onConsume = { onConsume(item.id) })
        }
    }
}

@Composable
fun InventoryRow(
    item: InventoryItemDto,
    onConsume: (() -> Unit)? = null,
) {
    SoftCard {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (!item.imageUrl.isNullOrBlank()) {
                AsyncImage(
                    model = item.imageUrl,
                    contentDescription = item.name,
                    modifier = Modifier
                        .size(56.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .background(MekasaColor.overlay),
                    contentScale = ContentScale.Crop,
                )
            } else {
                Column(
                    modifier = Modifier
                        .size(56.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .background(MekasaColor.overlay),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = item.name.take(1).uppercase(),
                        style = MekasaType.subhead,
                        color = MekasaColor.brand,
                    )
                }
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(text = item.name, style = MekasaType.body, color = MekasaColor.brand)
                Text(
                    text = "${item.category} · qty ${item.quantity}",
                    style = MekasaType.label,
                    color = if (item.quantity <= item.lowStockThreshold) {
                        MekasaColor.warning
                    } else {
                        MekasaColor.textMuted
                    },
                )
            }
            if (onConsume != null && item.quantity > 0) {
                TextButton(onClick = onConsume) {
                    Text("Use 1", color = MekasaColor.accent, style = MekasaType.label)
                }
            }
        }
    }
}
