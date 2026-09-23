package app.mekasa.android.ui.onboarding

import android.app.Activity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
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
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import app.mekasa.android.auth.AuthException
import app.mekasa.android.session.AppSession
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
import kotlinx.coroutines.launch
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box

@Composable
fun WelcomeScreen(
    state: AppUiState,
    session: AppSession,
) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var isSignUp by remember { mutableStateOf(false) }
    var showEmailForm by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val activity = context as? Activity

    LaunchedEffect(state.lastSignedInEmail) {
        val last = state.lastSignedInEmail
        if (!last.isNullOrBlank() && email.isBlank()) {
            email = last
            showEmailForm = true
        }
    }

    val googleSignInLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) { activityResult ->
        scope.launch {
            try {
                val authResult = session.authService.completeGoogleSignIn(activityResult.data)
                session.applyAuth(authResult)
            } catch (_: AuthException.Cancelled) {
                // user backed out
            } catch (e: Exception) {
                session.reportError(e.message)
            }
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
                        imeAction = ImeAction.Next,
                        testTag = "WelcomeEmailField",
                    )
                    MekasaTextField(
                        label = "Password",
                        value = password,
                        onValueChange = { password = it },
                        placeholder = "At least 6 characters",
                        isSecure = true,
                        keyboardType = KeyboardType.Password,
                        capitalization = KeyboardCapitalization.None,
                        imeAction = ImeAction.Go,
                        onImeAction = {
                            if (email.isNotBlank() && password.length >= 6) {
                                submitEmail(session, state, email, password, isSignUp)
                            }
                        },
                        testTag = "WelcomePasswordField",
                    )
                    TextButton(
                        onClick = { isSignUp = !isSignUp },
                        modifier = Modifier.testTag("WelcomeCreateAccountToggle"),
                    ) {
                        Text(
                            text = if (isSignUp) "Have an account? Sign in" else "Create a new account",
                            color = MekasaColor.accent,
                            style = MekasaType.body,
                        )
                    }
                }
                if (!state.firebaseConfigured) {
                    Text(
                        text = "Firebase is using the CI stub. Drop in a real google-services.json for email/Google auth, or Browse UI offline.",
                        style = MekasaType.label,
                        color = MekasaColor.textMuted,
                    )
                }
            }
            StickyBottomBar(progress = 1f / 6f) {
                if (showEmailForm) {
                    PrimaryButton(
                        title = if (isSignUp) "Create account" else "Sign in",
                        enabled = email.isNotBlank() && (
                            !state.firebaseConfigured || password.length >= 6
                            ),
                        isLoading = state.isBusy,
                        onClick = { submitEmail(session, state, email, password, isSignUp) },
                    )
                    Box(modifier = Modifier.height(Spacing.md))
                    SecondaryButton(title = "Back") { showEmailForm = false }
                } else {
                    if (state.firebaseConfigured) {
                        PrimaryButton(
                            title = "Continue with Google",
                            isLoading = state.isBusy,
                            onClick = {
                                val act = activity ?: return@PrimaryButton
                                val webClientId = runCatching {
                                    val resId = context.resources.getIdentifier(
                                        "default_web_client_id",
                                        "string",
                                        context.packageName,
                                    )
                                    if (resId == 0) null else context.getString(resId)
                                }.getOrNull()
                                if (webClientId.isNullOrBlank()) {
                                    session.reportError(AuthException.MissingGoogleClient().message)
                                    return@PrimaryButton
                                }
                                googleSignInLauncher.launch(
                                    session.authService.googleSignInIntent(act, webClientId),
                                )
                            },
                        )
                        Box(modifier = Modifier.height(Spacing.md))
                    }
                    PrimaryButton(
                        title = "Continue with email",
                        onClick = { showEmailForm = true },
                    )
                    Box(modifier = Modifier.height(Spacing.md))
                    SecondaryButton(
                        title = "Browse UI offline",
                        onClick = session::startOfflinePreview,
                    )
                }
            }
        }
    }
}

private fun submitEmail(
    session: AppSession,
    state: AppUiState,
    email: String,
    password: String,
    isSignUp: Boolean,
) {
    val trimmed = email.trim()
    if (state.firebaseConfigured) {
        session.signInWithEmail(trimmed, password, isSignUp)
    } else {
        session.signInWithTestToken(trimmed)
    }
}
