package app.mekasa.android.ui.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import app.mekasa.android.data.Store
import app.mekasa.android.session.AppUiState
import app.mekasa.android.session.OnboardingStep
import app.mekasa.android.ui.components.EmptyState
import app.mekasa.android.ui.components.MekasaScreen
import app.mekasa.android.ui.components.OnboardingHeader
import app.mekasa.android.ui.components.PrimaryButton
import app.mekasa.android.ui.components.SectionTitle
import app.mekasa.android.ui.components.StickyBottomBar
import app.mekasa.android.ui.theme.MekasaColor
import app.mekasa.android.ui.theme.MekasaShapes
import app.mekasa.android.ui.theme.MekasaType
import app.mekasa.android.ui.theme.Spacing

@Composable
fun StoreSelectionScreen(
    state: AppUiState,
    onToggle: (storeId: String) -> Unit,
    onContinue: () -> Unit,
) {
    MekasaScreen {
        Column(modifier = Modifier.fillMaxSize()) {
            OnboardingHeader(step = OnboardingStep.Stores)
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Spacing.lg)
                    .padding(top = Spacing.xl, bottom = 140.dp),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                SectionTitle(
                    title = "Pick your stores",
                    subtitle = "Choose where you usually shop. You can change this later.",
                )
                if (state.nearbyStores.isEmpty()) {
                    EmptyState("No stores nearby yet — continue with an empty list or try another address.")
                } else {
                    state.nearbyStores.forEach { store ->
                        StoreRow(
                            store = store,
                            selected = store.id in state.selectedStoreIds,
                            onClick = { onToggle(store.id) },
                        )
                    }
                }
            }
            StickyBottomBar(progress = 4f / 6f) {
                PrimaryButton(
                    title = "Finish setup",
                    isLoading = state.isBusy,
                    onClick = onContinue,
                )
            }
        }
    }
}

@Composable
private fun StoreRow(
    store: Store,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(MekasaColor.surfaceElevated, MekasaShapes.nested)
            .border(
                width = if (selected) 2.dp else 1.dp,
                color = if (selected) MekasaColor.brand else MekasaColor.overlay,
                shape = MekasaShapes.nested,
            )
            .clickable(onClick = onClick)
            .padding(Spacing.base),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Icon(
            imageVector = if (selected) Icons.Filled.CheckCircle else Icons.Outlined.RadioButtonUnchecked,
            contentDescription = null,
            tint = if (selected) MekasaColor.accent else MekasaColor.brandMuted,
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(text = store.name, style = MekasaType.body, color = MekasaColor.brand)
            Text(
                text = buildString {
                    append(store.address)
                    if (store.distanceMiles > 0) {
                        append(" · ")
                        append("%.1f mi".format(store.distanceMiles))
                    }
                },
                style = MekasaType.label,
                color = MekasaColor.textMuted,
            )
        }
    }
}
