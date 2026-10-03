package app.mekasa.fable.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextClearance
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.mekasa.fable.data.demo.DemoBackend
import app.mekasa.fable.support.UiHarness
import app.mekasa.fable.support.UiHarness.awaitDisplayed
import app.mekasa.fable.support.UiHarness.awaitGone
import app.mekasa.fable.support.UiHarness.node
import app.mekasa.fable.support.UiHarness.setApp
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Verifies: UI-001, UI-003 / AC1–AC4 / Design: design/baselines/android/Welcome_baseline.png,
 * HouseholdName_baseline.png, Address_baseline.png, StoreSelection_baseline.png
 *
 * Structural (Layer 1) checks for the welcome screen and the three onboarding steps. The
 * flow runs through the production SessionViewModel: the CI stub has Firebase disabled, so
 * the Welcome screen exposes test-token sign-in, and a scripted API serves a fresh account
 * with no household.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = UiHarness.DEVICE)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class OnboardingUITest {
    @get:Rule
    val compose = createComposeRule()

    @Before
    fun setUp() = UiHarness.installFakeImageLoader()

    @Test
    fun layout_keyComposablesVisible() {
        compose.setApp(UiHarness.signedOutSession())

        compose.awaitDisplayed(TestTags.WELCOME_VIEW)
        compose.onNodeWithText("MEKASA").assertIsDisplayed()
        compose.onNodeWithText("Your house,\norganized.").assertIsDisplayed()
        compose.node(TestTags.CONTINUE_WITH_EMAIL).assertIsDisplayed()
        compose.node(TestTags.BROWSE_OFFLINE).assertIsDisplayed()
        // Firebase is not configured in the CI stub: Google sign-in is hidden, the notice explains why.
        compose.onNodeWithText("Continue with Google").assertDoesNotExist()
        compose.onNodeWithText("Firebase isn't configured", substring = true).assertIsDisplayed()
    }

    @Test
    fun interaction_tapsInputsAndNavigationTriggers() {
        compose.setApp(UiHarness.signedOutSession())
        compose.awaitDisplayed(TestTags.WELCOME_VIEW)

        // Email mode reveals the field and the submit button stays disabled until an email is typed.
        compose.node(TestTags.CONTINUE_WITH_EMAIL).performClick()
        compose.awaitDisplayed(TestTags.EMAIL_FIELD)
        compose.node(TestTags.SUBMIT_EMAIL).assertIsNotEnabled()
        compose.node(TestTags.EMAIL_FIELD).performTextInput("ana@example.com")
        compose.node(TestTags.SUBMIT_EMAIL).assertIsEnabled()
        // Password field only exists when Firebase is configured (UI-001 AC2 fallback).
        compose.node(TestTags.PASSWORD_FIELD).assertDoesNotExist()

        // "Back" returns to the choices without losing the screen.
        compose.onNodeWithText("Back").performClick()
        compose.awaitDisplayed(TestTags.BROWSE_OFFLINE)
    }

    @Test
    fun flow_navigatesToNextScreen() {
        compose.setApp(UiHarness.onboardingSession())

        // Step 1 of 3: household name pre-filled from the account.
        compose.awaitDisplayed(TestTags.HOUSEHOLD_NAME_VIEW)
        compose.onNodeWithText("STEP 1 OF 3").assertIsDisplayed()
        compose.node(TestTags.HOUSEHOLD_NAME_FIELD).performTextClearance()
        compose.node(TestTags.HOUSEHOLD_NAME_FIELD).performTextInput("The Guerrero Home")
        compose.node(TestTags.HOUSEHOLD_CONTINUE).performClick()

        // Step 2 of 3: address gate stays disabled until typed.
        compose.awaitDisplayed(TestTags.ADDRESS_VIEW)
        compose.onNodeWithText("STEP 2 OF 3").assertIsDisplayed()
        compose.node(TestTags.ADDRESS_CONTINUE).assertIsNotEnabled()
        compose.node(TestTags.ADDRESS_FIELD).performTextInput("123 Peachtree St, Atlanta, GA")
        compose.node(TestTags.ADDRESS_CONTINUE).assertIsEnabled()
        compose.node(TestTags.ADDRESS_CONTINUE).performClick()

        // Step 3 of 3: nearby stores, first two preselected; toggling one changes the footer label.
        compose.awaitDisplayed(TestTags.STORE_SELECTION_VIEW)
        compose.onNodeWithText("STEP 3 OF 3").assertIsDisplayed()
        DemoBackend.SAMPLE_STORES.forEach { compose.node(TestTags.storeRow(it.id)).assertIsDisplayed() }
        compose.onNodeWithText("Finish setup").assertIsDisplayed()
        compose.node(TestTags.STORES_CONTINUE).performClick()

        // Finishing lands on the signed-in shell (UI-003 AC4 → UI-004).
        compose.awaitDisplayed(TestTags.MAIN_SHELL_VIEW)
        compose.awaitDisplayed(TestTags.DASHBOARD_VIEW)
        compose.awaitGone(TestTags.STORE_SELECTION_VIEW)
    }

    @Test
    fun visual_semanticStructureMatchesBaseline() {
        compose.setApp(UiHarness.onboardingSession())
        compose.awaitDisplayed(TestTags.HOUSEHOLD_NAME_VIEW)

        // Baseline: centred step eyebrow + wordmark, title, subtitle, single field, primary CTA, skip link.
        compose.onNodeWithText("Mekasa").assertIsDisplayed()
        compose.onNodeWithText("Name your household").assertIsDisplayed()
        compose.onNodeWithText("Optional — it shows on the dashboard", substring = true).assertIsDisplayed()
        compose.node(TestTags.HOUSEHOLD_NAME_FIELD).assertIsDisplayed()
        compose.node(TestTags.HOUSEHOLD_CONTINUE).assertIsDisplayed()
        compose.node(TestTags.HOUSEHOLD_SKIP).assertIsDisplayed()

        // Skip is a real path too: it creates an unnamed household and moves on.
        compose.node(TestTags.HOUSEHOLD_SKIP).performClick()
        compose.awaitDisplayed(TestTags.ADDRESS_VIEW)
        compose.onNodeWithText("Where's home?").assertIsDisplayed()
    }
}
