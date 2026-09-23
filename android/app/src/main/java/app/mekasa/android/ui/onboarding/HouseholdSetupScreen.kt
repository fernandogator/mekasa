package app.mekasa.android.ui.onboarding

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import app.mekasa.android.session.AppUiState
import app.mekasa.android.session.OnboardingStep
import app.mekasa.android.ui.components.MekasaScreen
import app.mekasa.android.ui.components.MekasaTextField
import app.mekasa.android.ui.components.OnboardingHeader
import app.mekasa.android.ui.components.PrimaryButton
import app.mekasa.android.ui.components.SectionTitle
import app.mekasa.android.ui.components.StickyBottomBar
import app.mekasa.android.ui.theme.Spacing

@Composable
fun HouseholdSetupScreen(
    state: AppUiState,
    onContinue: (name: String) -> Unit,
) {
    var name by remember {
        mutableStateOf(
            state.displayName
                ?.substringBefore("@")
                ?.replaceFirstChar { it.uppercase() }
                ?.let { "The $it Home" }
                ?: "",
        )
    }

    MekasaScreen {
        Column(modifier = Modifier.fillMaxSize()) {
            OnboardingHeader(step = OnboardingStep.Household)
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Spacing.lg)
                    .padding(top = Spacing.xl, bottom = 140.dp),
            ) {
                SectionTitle(
                    title = "Name your household",
                    subtitle = "This shows up on the dashboard and invites.",
                )
                MekasaTextField(
                    label = "Household name",
                    value = name,
                    onValueChange = { name = it },
                    placeholder = "The Guerrero Home",
                    imeAction = ImeAction.Done,
                    onImeAction = { onContinue(name.trim()) },
                    fieldModifier = Modifier.padding(top = Spacing.lg),
                )
            }
            StickyBottomBar(progress = 2f / 6f) {
                PrimaryButton(
                    title = "Continue",
                    enabled = name.isNotBlank(),
                    isLoading = state.isBusy,
                    onClick = { onContinue(name.trim()) },
                )
            }
        }
    }
}
