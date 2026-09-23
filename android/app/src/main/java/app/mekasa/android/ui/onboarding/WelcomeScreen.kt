package app.mekasa.android.ui.onboarding

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import app.mekasa.android.session.AppUiState
import app.mekasa.android.session.OnboardingStep
import app.mekasa.android.ui.components.MekasaScreen
import app.mekasa.android.ui.components.MekasaTextField
import app.mekasa.android.ui.components.OnboardingHeader
import app.mekasa.android.ui.components.PrimaryButton
import app.mekasa.android.ui.components.SecondaryButton
import app.mekasa.android.ui.components.StickyBottomBar
import app.mekasa.android.ui.theme.MekasaColor
import app.mekasa.android.ui.theme.MekasaType
import app.mekasa.android.ui.theme.Spacing

@Composable
fun WelcomeScreen(
    state: AppUiState,
    onSignIn: (email: String) -> Unit,
    onOfflinePreview: () -> Unit,
) {
    var email by remember { mutableStateOf("") }
    var showEmailForm by remember { mutableStateOf(false) }

    LaunchedEffect(state.lastSignedInEmail) {
        val last = state.lastSignedInEmail
        if (!last.isNullOrBlank() && email.isBlank()) {
            email = last
            showEmailForm = true
        }
    }

    MekasaScreen(modifier = Modifier.testTag("WelcomeView")) {
        Column(modifier = Modifier.fillMaxSize()) {
            OnboardingHeader(step = OnboardingStep.Welcome)
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Spacing.lg)
                    .padding(top = Spacing.xl, bottom = 140.dp),
                verticalArrangement = Arrangement.spacedBy(Spacing.base),
            ) {
                Text(
                    text = "Your house,\norganized.",
                    style = MekasaType.display,
                    color = MekasaColor.brand,
                )
                Text(
                    text = "Sign in to create a household, pick your stores, and start scanning inventory.",
                    style = MekasaType.body,
                    color = MekasaColor.textMuted,
                )
                if (showEmailForm) {
                    MekasaTextField(
                        label = "Email",
                        value = email,
                        onValueChange = { email = it },
                        placeholder = "you@example.com",
                        keyboardType = KeyboardType.Email,
                        capitalization = KeyboardCapitalization.None,
                        imeAction = ImeAction.Go,
                        onImeAction = {
                            if (email.isNotBlank()) onSignIn(email.trim())
                        },
                        testTag = "WelcomeEmailField",
                    )
                    Text(
                        text = "Firebase Auth is not wired in this build yet. Use a Cloud Run test token (email only) when ALLOW_TEST_AUTH is enabled, or Browse UI offline.",
                        style = MekasaType.label,
                        color = MekasaColor.textMuted,
                    )
                }
            }
            StickyBottomBar(progress = 1f / 6f) {
                if (showEmailForm) {
                    PrimaryButton(
                        title = "Sign in",
                        enabled = email.isNotBlank(),
                        isLoading = state.isBusy,
                        onClick = { onSignIn(email.trim()) },
                    )
                    Spacer(modifier = Modifier.height(Spacing.md))
                    SecondaryButton(title = "Back") { showEmailForm = false }
                } else {
                    PrimaryButton(
                        title = "Continue with email",
                        isLoading = state.isBusy,
                        onClick = { showEmailForm = true },
                    )
                    Spacer(modifier = Modifier.height(Spacing.md))
                    SecondaryButton(
                        title = "Browse UI offline",
                        onClick = onOfflinePreview,
                    )
                }
                TextButton(onClick = onOfflinePreview) {
                    Text(
                        text = "Skip auth · preview sample data",
                        color = MekasaColor.textMuted,
                        style = MekasaType.body,
                    )
                }
            }
        }
    }
}
