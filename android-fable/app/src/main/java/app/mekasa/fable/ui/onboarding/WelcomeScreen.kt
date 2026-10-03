package app.mekasa.fable.ui.onboarding

import android.app.Activity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import app.mekasa.fable.auth.AuthError
import app.mekasa.fable.session.SessionState
import app.mekasa.fable.session.SessionViewModel
import app.mekasa.fable.ui.TestTags
import app.mekasa.fable.ui.components.Backdrop
import app.mekasa.fable.ui.components.Card
import app.mekasa.fable.ui.components.LabeledField
import app.mekasa.fable.ui.components.LinkButton
import app.mekasa.fable.ui.components.OnboardingFooter
import app.mekasa.fable.ui.components.PrimaryButton
import app.mekasa.fable.ui.components.SecondaryButton
import app.mekasa.fable.ui.theme.MekasaTheme
import app.mekasa.fable.ui.theme.Space
import app.mekasa.fable.ui.theme.Type
import kotlinx.coroutines.launch

private enum class WelcomeMode { Choices, Email }

@Composable
fun WelcomeScreen(
    state: SessionState,
    session: SessionViewModel,
) {
    val palette = MekasaTheme.palette
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var mode by rememberSaveable { mutableStateOf(WelcomeMode.Choices) }
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var createAccount by rememberSaveable { mutableStateOf(false) }

    LaunchedEffect(state.rememberedEmail) {
        val remembered = state.rememberedEmail
        if (!remembered.isNullOrBlank() && email.isBlank()) {
            email = remembered
            mode = WelcomeMode.Email
        }
    }

    val googleLauncher = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        scope.launch {
            try {
                val user = session.authGateway.finishGoogleSignIn(result.data)
                session.completeExternalSignIn(user)
            } catch (_: AuthError.Cancelled) {
                // Person backed out of the account chooser.
            } catch (e: Exception) {
                session.fail(e.message)
            }
        }
    }

    fun startGoogle() {
        val activity = context as? Activity ?: return
        val resId = context.resources.getIdentifier("default_web_client_id", "string", context.packageName)
        val webClientId = if (resId == 0) null else context.getString(resId)
        if (webClientId.isNullOrBlank()) {
            session.fail(AuthError.MissingWebClientId().message)
            return
        }
        runCatching { googleLauncher.launch(session.authGateway.googleSignInIntent(activity, webClientId)) }
            .onFailure { session.fail(it.message) }
    }

    val passwordOk = password.length >= 6
    val usesFirebase = state.firebaseConfigured
    val canSubmitEmail = email.contains('@') && (passwordOk || (!usesFirebase && state.allowTestTokenSignIn))

    fun submitEmail() {
        if (!canSubmitEmail) return
        if (usesFirebase) {
            session.signInWithEmail(email.trim(), password, createAccount)
        } else {
            session.signInWithTestToken(email)
        }
    }

    Backdrop(modifier = Modifier.testTag(TestTags.WELCOME_VIEW)) {
        Column(modifier = Modifier.fillMaxSize()) {
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .statusBarsPadding()
                    .padding(horizontal = Space.lg)
                    .padding(top = Space.xl, bottom = Space.lg),
                verticalArrangement = Arrangement.spacedBy(Space.base),
            ) {
                Text("MEKASA", style = Type.label, color = palette.textMuted)
                Text("Your house,\norganized.", style = Type.hero, color = palette.text)
                Text(
                    "Scan what comes in, scan what goes out, and let the shopping list write itself.",
                    style = Type.bodyRegular,
                    color = palette.textMuted,
                )

                state.notice?.let { notice ->
                    Card(tint = palette.warningTint, padding = androidx.compose.foundation.layout.PaddingValues(Space.md)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.sm)) {
                            Icon(Icons.Outlined.Info, contentDescription = null, tint = palette.warning)
                            Text(notice, style = Type.caption, color = palette.warning, modifier = Modifier.weight(1f).testTag(TestTags.SESSION_NOTICE))
                            LinkButton("Dismiss", onClick = session::dismissNotice, color = palette.warning)
                        }
                    }
                }

                AnimatedVisibility(visible = mode == WelcomeMode.Email) {
                    Column(verticalArrangement = Arrangement.spacedBy(Space.base)) {
                        LabeledField(
                            label = "Email",
                            value = email,
                            onValueChange = { email = it },
                            placeholder = "you@example.com",
                            keyboardType = KeyboardType.Email,
                            capitalization = KeyboardCapitalization.None,
                            testTag = TestTags.EMAIL_FIELD,
                        )
                        if (usesFirebase) {
                            LabeledField(
                                label = "Password",
                                value = password,
                                onValueChange = { password = it },
                                placeholder = "At least 6 characters",
                                secure = true,
                                keyboardType = KeyboardType.Password,
                                capitalization = KeyboardCapitalization.None,
                                imeAction = ImeAction.Go,
                                onSubmit = ::submitEmail,
                                testTag = TestTags.PASSWORD_FIELD,
                            )
                            LinkButton(
                                text = if (createAccount) "Already have an account? Sign in" else "New here? Create an account",
                                onClick = { createAccount = !createAccount },
                                modifier = Modifier.testTag(TestTags.TOGGLE_CREATE_ACCOUNT),
                            )
                        } else {
                            Text(
                                "Debug build without Firebase: this signs in with a Cloud Run test token for the email above.",
                                style = Type.caption,
                                color = palette.warning,
                            )
                        }
                    }
                }

                if (!usesFirebase && mode == WelcomeMode.Choices) {
                    Text(
                        "Firebase isn't configured (CI stub google-services.json). Browse the UI offline, or add a real config for email and Google sign-in.",
                        style = Type.caption,
                        color = palette.textMuted,
                    )
                }
            }

            OnboardingFooter(progress = state.stage.progress) {
                when (mode) {
                    WelcomeMode.Choices -> {
                        if (usesFirebase) {
                            PrimaryButton(text = "Continue with Google", onClick = ::startGoogle, loading = state.busy)
                            Spacer(Modifier.height(Space.md))
                        }
                        if (usesFirebase || state.allowTestTokenSignIn) {
                            PrimaryButton(
                                text = if (usesFirebase) "Continue with email" else "Sign in with test token",
                                onClick = { mode = WelcomeMode.Email },
                                modifier = Modifier.testTag(TestTags.CONTINUE_WITH_EMAIL),
                            )
                            Spacer(Modifier.height(Space.md))
                        }
                        SecondaryButton(
                            text = "Browse UI offline",
                            onClick = session::browseOffline,
                            modifier = Modifier.testTag(TestTags.BROWSE_OFFLINE),
                        )
                    }
                    WelcomeMode.Email -> {
                        PrimaryButton(
                            text = when {
                                !usesFirebase -> "Sign in with test token"
                                createAccount -> "Create account"
                                else -> "Sign in"
                            },
                            onClick = ::submitEmail,
                            enabled = canSubmitEmail,
                            loading = state.busy,
                            modifier = Modifier.testTag(TestTags.SUBMIT_EMAIL),
                        )
                        Spacer(Modifier.height(Space.md))
                        SecondaryButton(text = "Back", onClick = { mode = WelcomeMode.Choices })
                    }
                }
                Spacer(Modifier.height(8.dp))
            }
        }
    }
}
