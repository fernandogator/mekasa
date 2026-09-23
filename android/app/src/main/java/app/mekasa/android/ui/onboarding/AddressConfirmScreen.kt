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
fun AddressConfirmScreen(
    state: AppUiState,
    onContinue: (address: String) -> Unit,
) {
    var address by remember {
        mutableStateOf(state.household?.address.orEmpty())
    }

    MekasaScreen {
        Column(modifier = Modifier.fillMaxSize()) {
            OnboardingHeader(step = OnboardingStep.Address)
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Spacing.lg)
                    .padding(top = Spacing.xl, bottom = 140.dp),
            ) {
                SectionTitle(
                    title = "Where’s home?",
                    subtitle = "We use this to suggest nearby grocery stores.",
                )
                MekasaTextField(
                    label = "Address",
                    value = address,
                    onValueChange = { address = it },
                    placeholder = "123 Peachtree St, Atlanta, GA",
                    imeAction = ImeAction.Done,
                    onImeAction = {
                        if (address.isNotBlank()) onContinue(address.trim())
                    },
                    fieldModifier = Modifier.padding(top = Spacing.lg),
                )
            }
            StickyBottomBar(progress = 3f / 6f) {
                PrimaryButton(
                    title = "Find stores",
                    enabled = address.isNotBlank(),
                    isLoading = state.isBusy,
                    onClick = { onContinue(address.trim()) },
                )
            }
        }
    }
}
