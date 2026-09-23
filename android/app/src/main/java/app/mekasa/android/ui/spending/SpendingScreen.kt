package app.mekasa.android.ui.spending

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import app.mekasa.android.data.SpendingReportDto
import app.mekasa.android.ui.components.EmptyState
import app.mekasa.android.ui.components.SoftCard
import app.mekasa.android.ui.theme.MekasaColor
import app.mekasa.android.ui.theme.MekasaType
import app.mekasa.android.ui.theme.Spacing

@Composable
fun SpendingScreen(
    spending: SpendingReportDto?,
    contentPadding: PaddingValues = PaddingValues(),
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(contentPadding)
            .padding(horizontal = Spacing.lg)
            .padding(top = Spacing.base, bottom = Spacing.xxl)
            .testTag("SpendingView"),
        verticalArrangement = Arrangement.spacedBy(Spacing.base),
    ) {
        Text(text = "Spending", style = MekasaType.title, color = MekasaColor.brand)
        if (spending == null) {
            EmptyState("No spending data yet.")
        } else {
            SoftCard {
                Text(
                    text = spending.period.uppercase(),
                    style = MekasaType.label,
                    color = MekasaColor.textMuted,
                )
                Text(
                    text = "$%.2f".format(spending.totalSpent),
                    style = MekasaType.display,
                    color = MekasaColor.brand,
                )
            }
            spending.categories.forEach { cat ->
                SoftCard {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Text(text = cat.category, style = MekasaType.body, color = MekasaColor.brand)
                        Text(
                            text = "$%.2f".format(cat.total),
                            style = MekasaType.body,
                            color = MekasaColor.textMuted,
                        )
                    }
                }
            }
        }
    }
}
