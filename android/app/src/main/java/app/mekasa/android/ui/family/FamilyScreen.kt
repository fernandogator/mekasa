package app.mekasa.android.ui.family

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import app.mekasa.android.session.AppUiState
import app.mekasa.android.ui.components.PrimaryButton
import app.mekasa.android.ui.components.SecondaryButton
import app.mekasa.android.ui.components.SoftCard
import app.mekasa.android.ui.theme.MekasaColor
import app.mekasa.android.ui.theme.MekasaType
import app.mekasa.android.ui.theme.Spacing

@Composable
fun FamilyScreen(
    state: AppUiState,
    onSignOut: () -> Unit,
    onRefresh: () -> Unit,
    contentPadding: PaddingValues = PaddingValues(),
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(contentPadding)
            .padding(horizontal = Spacing.lg)
            .padding(top = Spacing.base, bottom = Spacing.xxl)
            .testTag("FamilyView"),
        verticalArrangement = Arrangement.spacedBy(Spacing.base),
    ) {
        Text(text = "Family & settings", style = MekasaType.title, color = MekasaColor.brand)
        SoftCard {
            Text(
                text = state.displayName ?: "Signed in",
                style = MekasaType.subhead,
                color = MekasaColor.brand,
            )
            Text(
                text = state.email ?: "",
                style = MekasaType.body,
                color = MekasaColor.textMuted,
            )
            if (state.isOfflinePreview) {
                Text(
                    text = "Offline preview mode",
                    style = MekasaType.label,
                    color = MekasaColor.warning,
                    modifier = Modifier.padding(top = Spacing.sm),
                )
            }
        }
        SoftCard {
            Text(
                text = state.household?.name ?: "No household",
                style = MekasaType.body,
                color = MekasaColor.brand,
            )
            Text(
                text = state.household?.address ?: "Address not set",
                style = MekasaType.label,
                color = MekasaColor.textMuted,
            )
        }
        PrimaryButton(title = "Refresh data", onClick = onRefresh)
        SecondaryButton(title = "Sign out", onClick = onSignOut)
    }
}
