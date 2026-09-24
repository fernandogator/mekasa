package app.mekasa.fable.ui.spending

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.mekasa.fable.session.SessionState
import app.mekasa.fable.session.SessionViewModel
import app.mekasa.fable.ui.components.Card
import app.mekasa.fable.ui.components.EmptyMessage
import app.mekasa.fable.ui.components.ScreenHeader
import app.mekasa.fable.ui.components.SectionLabel
import app.mekasa.fable.ui.components.money
import app.mekasa.fable.ui.theme.MekasaTheme
import app.mekasa.fable.ui.theme.Shapes
import app.mekasa.fable.ui.theme.Space
import app.mekasa.fable.ui.theme.Type

private val PERIODS = listOf("week" to "Week", "month" to "Month", "year" to "Year")

/** REQ-018: total plus category breakdown for week / month / year. */
@Composable
fun SpendingScreen(
    state: SessionState,
    session: SessionViewModel,
    contentPadding: PaddingValues,
) {
    val palette = MekasaTheme.palette
    val report = state.data.spending
    val period = state.data.spendingPeriod

    Column(modifier = Modifier.fillMaxSize().testTag("SpendingScreen")) {
        ScreenHeader(title = "Spending", eyebrow = "Household total")
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = Space.lg)
                .padding(bottom = contentPadding.calculateBottomPadding() + Space.xxl),
            verticalArrangement = Arrangement.spacedBy(Space.base),
        ) {
            PeriodToggle(selected = period, onSelect = session::selectSpendingPeriod)

            if (report == null) {
                EmptyMessage("No spending recorded yet. Receipts with prices show up here.", modifier = Modifier.testTag("SpendingEmpty"))
            } else {
                Card(modifier = Modifier.testTag("SpendingTotal")) {
                    SectionLabel("This ${report.period}")
                    Text(money(report.total, report.currency), style = Type.hero, color = palette.text)
                    Text(
                        "${report.byCategory.size} categories · ${report.currency}",
                        style = Type.caption,
                        color = palette.textMuted,
                    )
                }

                if (report.byCategory.isEmpty()) {
                    EmptyMessage("No category breakdown for this period.")
                } else {
                    SectionLabel("By category")
                    val max = report.byCategory.maxOf { it.total }.coerceAtLeast(0.01)
                    val colors = listOf(palette.accent, palette.success, palette.warning, palette.brand, palette.brandMuted)
                    report.byCategory.sortedByDescending { it.total }.forEachIndexed { index, cat ->
                        CategoryBar(
                            name = cat.category,
                            amount = money(cat.total, report.currency),
                            fraction = (cat.total / max).toFloat(),
                            share = if (report.total > 0) (cat.total / report.total * 100).toInt() else 0,
                            color = colors[index % colors.size],
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PeriodToggle(selected: String, onSelect: (String) -> Unit) {
    val palette = MekasaTheme.palette
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(palette.surfaceElevated, Shapes.pill)
            .border(1.dp, palette.brandMuted.copy(alpha = 0.3f), Shapes.pill)
            .padding(4.dp)
            .testTag("PeriodToggle"),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        PERIODS.forEach { (key, label) ->
            val active = key == selected
            Box(
                modifier = Modifier
                    .weight(1f)
                    .background(if (active) palette.brand else Color.Transparent, Shapes.pill)
                    .clickable { onSelect(key) }
                    .padding(vertical = Space.sm)
                    .testTag("Period-$key"),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    label,
                    style = Type.caption,
                    color = if (active) (if (palette.isDark) palette.surface else Color.White) else palette.textMuted,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

@Composable
private fun CategoryBar(name: String, amount: String, fraction: Float, share: Int, color: Color) {
    val palette = MekasaTheme.palette
    val animated by animateFloatAsState(targetValue = fraction.coerceIn(0.02f, 1f), animationSpec = tween(400), label = "bar")
    Card(padding = PaddingValues(Space.base)) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(name, style = Type.body, color = palette.text)
            Text(amount, style = Type.body, color = palette.text)
        }
        Spacer(Modifier.height(Space.sm))
        Box(modifier = Modifier.fillMaxWidth().height(8.dp).background(palette.overlay, Shapes.pill)) {
            Box(modifier = Modifier.fillMaxWidth(animated).height(8.dp).background(color, Shapes.pill))
        }
        Spacer(Modifier.height(Space.xs))
        Text("$share% of total", style = Type.caption, color = palette.textMuted)
    }
}
