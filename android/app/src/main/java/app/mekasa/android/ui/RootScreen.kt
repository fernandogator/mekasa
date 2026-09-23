package app.mekasa.android.ui

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.mekasa.android.session.AppSession
import app.mekasa.android.session.OnboardingStep
import app.mekasa.android.ui.onboarding.AddressConfirmScreen
import app.mekasa.android.ui.onboarding.HouseholdSetupScreen
import app.mekasa.android.ui.onboarding.StoreSelectionScreen
import app.mekasa.android.ui.onboarding.WelcomeScreen
import app.mekasa.android.ui.shell.MainShellScreen
import app.mekasa.android.ui.trash.TrashStationScreen

@Composable
fun RootScreen(session: AppSession) {
    val state by session.state.collectAsStateWithLifecycle()

    when {
        state.step == OnboardingStep.Done && state.isTrashKioskMode -> {
            TrashStationScreen(
                state = state,
                session = session,
                kioskMode = true,
                onExit = { session.setTrashKioskMode(false) },
            )
        }
        state.step == OnboardingStep.Welcome -> WelcomeScreen(
            state = state,
            session = session,
        )
        state.step == OnboardingStep.Household -> HouseholdSetupScreen(
            state = state,
            onContinue = session::createHousehold,
        )
        state.step == OnboardingStep.Address -> AddressConfirmScreen(
            state = state,
            onContinue = session::saveAddress,
        )
        state.step == OnboardingStep.Stores -> StoreSelectionScreen(
            state = state,
            onToggle = session::toggleStore,
            onContinue = session::saveStores,
        )
        state.step == OnboardingStep.Done -> MainShellScreen(state = state, session = session)
    }

    if (state.lastError != null) {
        AlertDialog(
            onDismissRequest = session::clearError,
            confirmButton = {
                TextButton(onClick = session::clearError) {
                    Text("OK")
                }
            },
            title = { Text("Something went wrong") },
            text = { Text(state.lastError.orEmpty()) },
            modifier = Modifier.testTag("ErrorDialog"),
        )
    }
}
