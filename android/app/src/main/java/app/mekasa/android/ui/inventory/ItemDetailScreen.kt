package app.mekasa.android.ui.inventory

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import app.mekasa.android.data.InventoryItemDto
import app.mekasa.android.session.AppSession
import app.mekasa.android.ui.components.SoftCard
import app.mekasa.android.ui.theme.MekasaColor
import app.mekasa.android.ui.theme.MekasaShapes
import app.mekasa.android.ui.theme.MekasaType
import app.mekasa.android.ui.theme.Spacing
import coil.compose.AsyncImage

@Composable
fun ItemDetailScreen(
    item: InventoryItemDto,
    session: AppSession,
    onBack: () -> Unit,
    contentPadding: PaddingValues = PaddingValues(),
) {
    var quantity by remember(item.id, item.quantity) { mutableIntStateOf(item.quantity) }
    var threshold by remember(item.id, item.lowStockThreshold) {
        mutableIntStateOf(item.lowStockThreshold)
    }

    LaunchedEffect(item.id, item.imageUrl) {
        if (item.imageUrl.isNullOrBlank()) {
            session.refreshInventoryItemImage(item.id)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(contentPadding)
            .padding(horizontal = Spacing.lg)
            .padding(top = Spacing.base, bottom = Spacing.xxl)
            .testTag("ItemDetailView"),
        verticalArrangement = Arrangement.spacedBy(Spacing.base),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(text = "Item detail", style = MekasaType.title, color = MekasaColor.brand)
            TextButton(onClick = onBack) {
                Text("Back", color = MekasaColor.accent, style = MekasaType.label)
            }
        }

        if (!item.imageUrl.isNullOrBlank()) {
            AsyncImage(
                model = item.imageUrl,
                contentDescription = item.name,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp)
                    .clip(MekasaShapes.nested)
                    .background(MekasaColor.overlay),
                contentScale = ContentScale.Crop,
            )
        }

        Text(text = item.name, style = MekasaType.display, color = MekasaColor.brand)
        Text(text = item.category, style = MekasaType.label, color = MekasaColor.textMuted)
        if (!item.barcode.isNullOrBlank()) {
            Text(
                text = "UPC ${item.barcode}",
                style = MekasaType.label,
                color = MekasaColor.textMuted,
            )
        }

        StepperCard(
            title = "Quantity",
            value = quantity,
            onDecrement = {
                quantity = (quantity - 1).coerceAtLeast(0)
                session.updateInventoryItem(item.id, quantity = quantity)
            },
            onIncrement = {
                quantity += 1
                session.updateInventoryItem(item.id, quantity = quantity)
            },
        )

        StepperCard(
            title = "Low-stock threshold",
            value = threshold,
            onDecrement = {
                threshold = (threshold - 1).coerceAtLeast(0)
                session.updateInventoryItem(item.id, lowStockThreshold = threshold)
            },
            onIncrement = {
                threshold += 1
                session.updateInventoryItem(item.id, lowStockThreshold = threshold)
            },
        )

        Text(
            text = if (quantity <= threshold) {
                "This item is low stock and will appear on the shopping list."
            } else {
                "Raise or lower the threshold anytime. Default is 1."
            },
            style = MekasaType.body,
            color = MekasaColor.textMuted,
        )
    }
}

@Composable
private fun StepperCard(
    title: String,
    value: Int,
    onDecrement: () -> Unit,
    onIncrement: () -> Unit,
) {
    SoftCard {
        Text(text = title, style = MekasaType.label, color = MekasaColor.textMuted)
        Box(modifier = Modifier.height(Spacing.sm))
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            TextButton(
                onClick = onDecrement,
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(MekasaColor.overlay),
            ) {
                Text("−", style = MekasaType.title, color = MekasaColor.brand)
            }
            Text(text = "$value", style = MekasaType.title, color = MekasaColor.brand)
            TextButton(
                onClick = onIncrement,
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(MekasaColor.overlay),
            ) {
                Text("+", style = MekasaType.title, color = MekasaColor.brand)
            }
        }
    }
}
