package app.mekasa.android.ui.shopping

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckBoxOutlineBlank
import androidx.compose.material.icons.outlined.ShoppingCart
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import app.mekasa.android.data.ShoppingListItemDto
import app.mekasa.android.ui.components.EmptyState
import app.mekasa.android.ui.components.SoftCard
import app.mekasa.android.ui.theme.MekasaColor
import app.mekasa.android.ui.theme.MekasaType
import app.mekasa.android.ui.theme.Spacing

@Composable
fun ShoppingListScreen(
    items: List<ShoppingListItemDto>,
    contentPadding: PaddingValues = PaddingValues(),
) {
    if (items.isEmpty()) {
        EmptyState(
            message = "Shopping list is empty.",
            modifier = Modifier
                .fillMaxSize()
                .testTag("ShoppingListEmpty"),
        )
        return
    }

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
            Text(text = "Shopping list", style = MekasaType.title, color = MekasaColor.brand)
        }
        items(items, key = { it.id }) { item ->
            SoftCard {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(Spacing.md),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        imageVector = if (item.isChecked) {
                            Icons.Outlined.ShoppingCart
                        } else {
                            Icons.Outlined.CheckBoxOutlineBlank
                        },
                        contentDescription = null,
                        tint = if (item.needsApproval) MekasaColor.warning else MekasaColor.brand,
                    )
                    Column(modifier = Modifier.weight(1f)) {
                        Text(text = item.name, style = MekasaType.body, color = MekasaColor.brand)
                        Text(
                            text = buildString {
                                append("${item.category} · qty ${item.quantity}")
                                if (item.needsApproval) append(" · needs approval")
                            },
                            style = MekasaType.label,
                            color = MekasaColor.textMuted,
                        )
                    }
                }
            }
        }
    }
}
