package app.mekasa.android.ui.spending

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.mekasa.android.session.AppSession
import app.mekasa.android.session.AppUiState
import app.mekasa.android.ui.components.EmptyState
import app.mekasa.android.ui.components.SoftCard
import app.mekasa.android.ui.theme.MekasaColor
import app.mekasa.android.ui.theme.MekasaShapes
import app.mekasa.android.ui.theme.MekasaType
import app.mekasa.android.ui.theme.Spacing

private val Periods = listOf("week", "month", "year")

@Composable
fun SpendingScreen(
    state: AppUiState,
    session: AppSession,
    contentPadding: PaddingValues = PaddingValues(),
) {
    val spending = state.spending
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
        PeriodPicker(
            selected = state.spendingPeriod,
            onSelect = session::refreshSpending,
        )
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
                    text = "$%.2f".format(spending.total),
                    style = MekasaType.display,
                    color = MekasaColor.brand,
                )
            }
            spending.byCategory.forEach { cat ->
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

@Composable
private fun PeriodPicker(
    selected: String,
    onSelect: (String) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(MekasaColor.surfaceElevated, MekasaShapes.pill)
            .border(1.dp, MekasaColor.overlay, MekasaShapes.pill)
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Periods.forEach { period ->
            val isSelected = period == selected
            Box(
                modifier = Modifier
                    .weight(1f)
                    .background(
                        if (isSelected) MekasaColor.brand else MekasaColor.surfaceElevated,
                        MekasaShapes.pill,
                    )
                    .clickable { onSelect(period) }
                    .padding(vertical = Spacing.sm),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = period.replaceFirstChar { it.uppercase() },
                    style = MekasaType.label,
                    color = if (isSelected) MekasaColor.surfaceElevated else MekasaColor.textMuted,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}
