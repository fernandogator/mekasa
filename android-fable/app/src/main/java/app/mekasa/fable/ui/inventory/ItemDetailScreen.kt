package app.mekasa.fable.ui.inventory

import androidx.compose.foundation.background
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import app.mekasa.fable.data.model.InventoryItem
import app.mekasa.fable.session.SessionViewModel
import app.mekasa.fable.ui.TestTags
import app.mekasa.fable.ui.components.Backdrop
import app.mekasa.fable.ui.components.Card
import app.mekasa.fable.ui.components.Chip
import app.mekasa.fable.ui.components.LinkButton
import app.mekasa.fable.ui.components.ProductThumbnail
import app.mekasa.fable.ui.components.ScreenHeader
import app.mekasa.fable.ui.components.SectionLabel
import app.mekasa.fable.ui.components.money
import app.mekasa.fable.ui.theme.MekasaTheme
import app.mekasa.fable.ui.theme.Shapes
import app.mekasa.fable.ui.theme.Space
import app.mekasa.fable.ui.theme.Type

/**
 * UI-006 AC2–AC5 and REQ-009: large product image (tap for full screen), metadata, and
 * steppers that PATCH quantity / threshold. Opening a row without an image asks the API
 * to look one up (`refresh-image`).
 */
@Composable
fun ItemDetailScreen(
    item: InventoryItem,
    session: SessionViewModel,
    onBack: () -> Unit,
) {
    val palette = MekasaTheme.palette
    var lightbox by remember { mutableStateOf(false) }

    LaunchedEffect(item.id) {
        if (!item.hasImage) session.refreshItemImage(item.id)
    }

    Backdrop(modifier = Modifier.testTag(TestTags.ITEM_DETAIL_VIEW)) {
        Column(modifier = Modifier.fillMaxSize()) {
            ScreenHeader(title = "Item", eyebrow = item.category, onBack = onBack)
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Space.lg)
                    .padding(bottom = Space.xxl),
                verticalArrangement = Arrangement.spacedBy(Space.base),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(280.dp)
                        .clip(Shapes.card)
                        .background(palette.surfaceElevated)
                        .clickable(enabled = item.hasImage) { lightbox = true }
                        .testTag(TestTags.ITEM_IMAGE),
                    contentAlignment = Alignment.Center,
                ) {
                    ProductThumbnail(
                        imageUrl = item.imageUrl,
                        name = item.name,
                        modifier = Modifier.fillMaxSize(),
                        size = 280.dp,
                        shape = Shapes.card,
                    )
                }
                if (!item.hasImage) {
                    LinkButton("Look up product image", onClick = { session.refreshItemImage(item.id) })
                }

                Text(item.name, style = Type.title, color = palette.text)
                Row(horizontalArrangement = Arrangement.spacedBy(Space.sm), verticalAlignment = Alignment.CenterVertically) {
                    Chip(item.category, color = palette.textMuted)
                    if (item.isLowStock) Chip("Low stock", color = palette.warning)
                    Chip(item.source, color = palette.success)
                }
                if (!item.barcode.isNullOrBlank()) {
                    Column {
                        SectionLabel("UPC")
                        Text(item.barcode, style = Type.mono, color = palette.text)
                    }
                }
                item.pricePaid?.let {
                    Column {
                        SectionLabel("Last price paid")
                        Text(money(it), style = Type.body, color = palette.text)
                    }
                }

                Stepper(
                    label = "Quantity",
                    value = item.quantity,
                    testTag = TestTags.QUANTITY_CONTROL,
                    onChange = { session.updateInventory(item.id, quantity = it) },
                )
                Stepper(
                    label = "Low-stock threshold",
                    value = item.lowStockThreshold,
                    testTag = TestTags.THRESHOLD_CONTROL,
                    onChange = { session.updateInventory(item.id, threshold = it) },
                )
                Text(
                    if (item.isLowStock) {
                        "At or below the threshold: this item shows in Low stock and syncs onto the shopping list."
                    } else {
                        "When quantity drops to ${item.lowStockThreshold} it will be flagged as low stock."
                    },
                    style = Type.caption,
                    color = palette.textMuted,
                )
            }
        }
    }

    if (lightbox) {
        Dialog(onDismissRequest = { lightbox = false }) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(420.dp)
                    .clip(Shapes.card)
                    .background(palette.surfaceElevated)
                    .clickable { lightbox = false }
                    .testTag(TestTags.ITEM_LIGHTBOX),
            ) {
                ProductThumbnail(
                    imageUrl = item.imageUrl,
                    name = item.name,
                    modifier = Modifier.fillMaxSize(),
                    size = 420.dp,
                    shape = Shapes.card,
                )
            }
        }
    }
}

@Composable
private fun Stepper(
    label: String,
    value: Int,
    testTag: String,
    onChange: (Int) -> Unit,
) {
    val palette = MekasaTheme.palette
    Card(modifier = Modifier.testTag(testTag)) {
        SectionLabel(label)
        Spacer(Modifier.height(Space.sm))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            RoundIconButton(Icons.Filled.Remove, "Decrease $label", enabled = value > 0) { onChange(value - 1) }
            Text("$value", style = Type.hero, color = palette.text)
            RoundIconButton(Icons.Filled.Add, "Increase $label") { onChange(value + 1) }
        }
    }
}

@Composable
private fun RoundIconButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    description: String,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    val palette = MekasaTheme.palette
    IconButton(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.size(48.dp).clip(CircleShape).background(palette.overlay),
    ) {
        Icon(icon, contentDescription = description, tint = if (enabled) palette.text else palette.textMuted)
    }
}

/** Compact detail preview used by the receipt confirm list. */
@Composable
fun ProductLine(name: String, meta: String, imageUrl: String?, warn: Boolean = false) {
    val palette = MekasaTheme.palette
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.md)) {
        ProductThumbnail(imageUrl = imageUrl, name = name, size = 44.dp)
        Column(modifier = Modifier.weight(1f)) {
            Text(name, style = Type.body, color = palette.text)
            Text(meta, style = Type.caption, color = if (warn) palette.warning else palette.textMuted)
        }
    }
}
