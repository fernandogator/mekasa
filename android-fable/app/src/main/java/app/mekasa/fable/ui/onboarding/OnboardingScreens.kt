package app.mekasa.fable.ui.onboarding

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import app.mekasa.fable.session.SessionState
import app.mekasa.fable.session.Stage
import app.mekasa.fable.ui.TestTags
import app.mekasa.fable.ui.components.Backdrop
import app.mekasa.fable.ui.components.LabeledField
import app.mekasa.fable.ui.components.LinkButton
import app.mekasa.fable.ui.components.OnboardingFooter
import app.mekasa.fable.ui.components.PrimaryButton
import app.mekasa.fable.ui.stores.StoreList
import app.mekasa.fable.ui.theme.MekasaTheme
import app.mekasa.fable.ui.theme.Space
import app.mekasa.fable.ui.theme.Type

/** Shared onboarding chrome: step eyebrow, wordmark, scrolling body, sticky footer. */
@Composable
private fun OnboardingScaffold(
    stage: Stage,
    title: String,
    subtitle: String,
    footer: @Composable ColumnScope.() -> Unit,
    testTag: String,
    body: @Composable ColumnScope.() -> Unit,
) {
    val palette = MekasaTheme.palette
    val stepLabel = when (stage) {
        Stage.NameHousehold -> "Step 1 of 3"
        Stage.ConfirmAddress -> "Step 2 of 3"
        Stage.PickStores -> "Step 3 of 3"
        else -> ""
    }
    Backdrop(modifier = Modifier.testTag(testTag)) {
        Column(modifier = Modifier.fillMaxSize()) {
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .statusBarsPadding()
                    .padding(horizontal = Space.lg)
                    .padding(top = Space.lg, bottom = Space.lg),
                verticalArrangement = Arrangement.spacedBy(Space.base),
            ) {
                Column(modifier = Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(stepLabel.uppercase(), style = Type.label, color = palette.textMuted)
                    Text("Mekasa", style = Type.subhead, color = palette.text)
                }
                Spacer(Modifier.height(Space.md))
                Text(title, style = Type.title, color = palette.text)
                Text(subtitle, style = Type.bodyRegular, color = palette.textMuted)
                Spacer(Modifier.height(Space.sm))
                body()
            }
            OnboardingFooter(progress = stage.progress, content = footer)
        }
    }
}

@Composable
fun HouseholdNameScreen(
    state: SessionState,
    onContinue: (String) -> Unit,
) {
    val suggested = state.account?.shortName
        ?.replaceFirstChar { it.uppercase() }
        ?.let { "The $it Home" }
        .orEmpty()
    var name by rememberSaveable { mutableStateOf(suggested) }

    OnboardingScaffold(
        stage = Stage.NameHousehold,
        title = "Name your household",
        subtitle = "Optional — it shows on the dashboard and on invites. You can change it later.",
        testTag = TestTags.HOUSEHOLD_NAME_VIEW,
        footer = {
            PrimaryButton(
                text = "Continue",
                onClick = { onContinue(name) },
                loading = state.busy,
                modifier = Modifier.testTag(TestTags.HOUSEHOLD_CONTINUE),
            )
            LinkButton(
                text = "Skip for now",
                onClick = { onContinue("") },
                modifier = Modifier.align(Alignment.CenterHorizontally).testTag(TestTags.HOUSEHOLD_SKIP),
                enabled = !state.busy,
            )
        },
    ) {
        LabeledField(
            label = "Household name",
            value = name,
            onValueChange = { name = it },
            placeholder = "The Guerrero Home",
            imeAction = ImeAction.Done,
            onSubmit = { onContinue(name) },
            testTag = TestTags.HOUSEHOLD_NAME_FIELD,
        )
    }
}

@Composable
fun AddressScreen(
    state: SessionState,
    onContinue: (String) -> Unit,
) {
    var address by rememberSaveable { mutableStateOf(state.household?.address.orEmpty()) }

    OnboardingScaffold(
        stage = Stage.ConfirmAddress,
        title = "Where's home?",
        subtitle = "We look for grocery and retail stores within 15 miles of this address.",
        testTag = TestTags.ADDRESS_VIEW,
        footer = {
            PrimaryButton(
                text = "Find nearby stores",
                onClick = { onContinue(address) },
                enabled = address.isNotBlank(),
                loading = state.busy,
                modifier = Modifier.testTag(TestTags.ADDRESS_CONTINUE),
            )
        },
    ) {
        LabeledField(
            label = "Home address",
            value = address,
            onValueChange = { address = it },
            placeholder = "123 Peachtree St, Atlanta, GA",
            imeAction = ImeAction.Done,
            onSubmit = { if (address.isNotBlank()) onContinue(address) },
            testTag = TestTags.ADDRESS_FIELD,
        )
        Text(
            "Location detection isn't wired in this build — type the address and we'll take it from there.",
            style = Type.caption,
            color = MekasaTheme.palette.textMuted,
        )
    }
}

/** Onboarding step 3: the shared store list; finishing saves the stores with details. Satisfies: REQ-003 AC11 */
@Composable
fun StoresScreen(
    state: SessionState,
    onToggle: (String) -> Unit,
    onContinue: () -> Unit,
) {
    OnboardingScaffold(
        stage = Stage.PickStores,
        title = "Pick your stores",
        subtitle = "Where do you usually shop? Receipts and prices get tied to these.",
        testTag = TestTags.STORE_SELECTION_VIEW,
        footer = {
            PrimaryButton(
                text = if (state.selectedStoreIds.isEmpty()) "Skip and finish" else "Finish setup",
                onClick = onContinue,
                loading = state.busy,
                modifier = Modifier.testTag(TestTags.STORES_CONTINUE),
            )
        },
    ) {
        StoreList(
            stores = state.nearbyStores,
            selectedIds = state.selectedStoreIds,
            onToggle = onToggle,
            emptyText = "No stores came back for that address. You can finish now and add stores later.",
        )
    }
}
