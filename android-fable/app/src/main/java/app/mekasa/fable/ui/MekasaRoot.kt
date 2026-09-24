package app.mekasa.fable.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.mekasa.fable.session.SessionViewModel
import app.mekasa.fable.session.Stage
import app.mekasa.fable.ui.home.HomeShell
import app.mekasa.fable.ui.onboarding.AddressScreen
import app.mekasa.fable.ui.onboarding.HouseholdNameScreen
import app.mekasa.fable.ui.onboarding.StoresScreen
import app.mekasa.fable.ui.onboarding.WelcomeScreen
import app.mekasa.fable.ui.theme.MekasaTheme
import app.mekasa.fable.ui.theme.Shapes
import app.mekasa.fable.ui.theme.Type
import app.mekasa.fable.ui.trash.TrashStationScreen

private enum class RootDestination { Welcome, NameHousehold, Address, Stores, Kiosk, Home }

/** Top-level router: the [Stage] in session state decides which surface is shown. */
@Composable
fun MekasaRoot(session: SessionViewModel) {
    val state by session.state.collectAsStateWithLifecycle()
    val palette = MekasaTheme.palette

    val destination = when (state.stage) {
        Stage.SignedOut -> RootDestination.Welcome
        Stage.NameHousehold -> RootDestination.NameHousehold
        Stage.ConfirmAddress -> RootDestination.Address
        Stage.PickStores -> RootDestination.Stores
        Stage.Home -> if (state.kioskMode) RootDestination.Kiosk else RootDestination.Home
    }

    AnimatedContent(
        targetState = destination,
        transitionSpec = { fadeIn() togetherWith fadeOut() },
        label = "root",
    ) { target ->
        when (target) {
            RootDestination.Welcome -> WelcomeScreen(state = state, session = session)
            RootDestination.NameHousehold -> HouseholdNameScreen(state = state, onContinue = session::createHousehold)
            RootDestination.Address -> AddressScreen(state = state, onContinue = session::saveAddress)
            RootDestination.Stores -> StoresScreen(
                state = state,
                onToggle = session::toggleStore,
                onContinue = { session.finishStoreSelection() },
            )
            RootDestination.Kiosk -> TrashStationScreen(
                state = state,
                session = session,
                kiosk = true,
                onExit = { session.setKioskMode(false) },
            )
            RootDestination.Home -> HomeShell(state = state, session = session)
        }
    }

    state.error?.let { message ->
        AlertDialog(
            onDismissRequest = session::dismissError,
            confirmButton = {
                TextButton(onClick = session::dismissError) { Text("OK", color = palette.accent) }
            },
            title = { Text("Something went wrong", style = Type.subhead, color = palette.text) },
            text = { Text(message, style = Type.bodyRegular, color = palette.textMuted) },
            shape = Shapes.card,
            containerColor = palette.surfaceElevated,
            modifier = Modifier.testTag("ErrorDialog"),
        )
    }
}
