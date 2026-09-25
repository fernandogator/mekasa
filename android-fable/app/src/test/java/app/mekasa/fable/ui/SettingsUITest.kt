package app.mekasa.fable.ui

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.mekasa.fable.data.demo.DemoBackend
import app.mekasa.fable.support.UiHarness
import app.mekasa.fable.support.UiHarness.awaitDisplayed
import app.mekasa.fable.support.UiHarness.awaitGone
import app.mekasa.fable.support.UiHarness.node
import app.mekasa.fable.support.UiHarness.scrollToBottom
import app.mekasa.fable.support.UiHarness.setApp
import app.mekasa.fable.ui.home.Routes
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Verifies: REQ-019 (family members & invites), REQ-002 (owner role), REQ-022 (sign out) /
 * Design: design/baselines/android/Family_baseline.png
 *
 * Structural (Layer 1) checks for the Family tab, which doubles as settings: account card,
 * member list with roles, invite form, device actions and sign-out.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = UiHarness.DEVICE)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class SettingsUITest {
    @get:Rule
    val compose = createComposeRule()

    @Before
    fun setUp() = UiHarness.installFakeImageLoader()

    @Test
    fun layout_keyComposablesVisible() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.FAMILY)

        compose.awaitDisplayed(TestTags.FAMILY_VIEW)
        compose.onNodeWithText("Family").assertIsDisplayed()
        compose.onNodeWithText("THE GUERRERO HOME").assertIsDisplayed()
        // Account card: preview account, owner chip, offline badge.
        compose.onAllNodesWithText("Preview").onFirst().assertIsDisplayed()
        compose.onNodeWithText(DemoBackend.DEMO_EMAIL).assertIsDisplayed()
        // "Owner" chips: one on the account card, one on the owner's member row.
        compose.onAllNodesWithText("Owner").assertCountEquals(2)
        compose.onNodeWithText("Offline preview").assertIsDisplayed()
        // Members: the owner and the kid, each with a role chip.
        compose.onNodeWithText("Members").assertIsDisplayed()
        compose.node(TestTags.member(DemoBackend.DEMO_UID)).assertIsDisplayed()
        compose.node(TestTags.member("demo-kid")).assertIsDisplayed()
        compose.onNodeWithText("Mateo").assertIsDisplayed()
        compose.onNodeWithText("Member").assertIsDisplayed()
        compose.node(TestTags.INVITE_NAME).assertIsDisplayed()
        compose.node(TestTags.BOTTOM_NAV_BAR).assertIsDisplayed()
    }

    @Test
    fun interaction_tapsInputsAndNavigationTriggers() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.FAMILY)
        compose.awaitDisplayed(TestTags.FAMILY_VIEW)

        // Invite form gates the CTA on a name, then lists the pending invite with a Share action.
        compose.node(TestTags.CREATE_INVITE).performScrollTo().assertIsNotEnabled()
        compose.node(TestTags.INVITE_NAME).performTextInput("Alex")
        compose.node(TestTags.INVITE_EMAIL).performTextInput("alex@example.com")
        compose.node(TestTags.CREATE_INVITE).assertIsEnabled().performClick()
        compose.waitUntil(UiHarness.WAIT_MS) { compose.onAllNodes(hasText("Pending invites")).fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithText("alex@example.com · member").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Share").assertIsDisplayed()

        // Owners can promote the kid.
        compose.onNodeWithText("Make owner").performScrollTo().performClick()
        compose.waitUntil(UiHarness.WAIT_MS) { compose.onAllNodes(hasText("Owner")).fetchSemanticsNodes().size >= 3 }
    }

    @Test
    fun flow_navigatesToNextScreen() {
        compose.setApp(UiHarness.demoSession())
        compose.awaitDisplayed(TestTags.DASHBOARD_VIEW)

        // Pill nav → Family; "Dispose one item" pushes the trash route; back returns.
        compose.node(TestTags.FAMILY_TAB).performClick()
        compose.awaitDisplayed(TestTags.FAMILY_VIEW)
        // Scroll past the Devices section so the button is not under the floating pill nav.
        compose.node(TestTags.SIGN_OUT).performScrollTo()
        compose.node(TestTags.OPEN_TRASH).performClick()
        compose.awaitDisplayed(TestTags.TRASH_STATION_VIEW)
        compose.node(TestTags.BACK_BUTTON).performClick()
        compose.awaitDisplayed(TestTags.FAMILY_VIEW)

        // Sign out ends the session and lands on Welcome (REQ-022).
        compose.scrollToBottom(TestTags.FAMILY_VIEW)
        compose.node(TestTags.SIGN_OUT).performClick()
        compose.awaitDisplayed(TestTags.WELCOME_VIEW)
        compose.awaitGone(TestTags.MAIN_SHELL_VIEW)
    }

    @Test
    fun visual_semanticStructureMatchesBaseline() {
        compose.setApp(UiHarness.demoSession(), startRoute = Routes.FAMILY)
        compose.awaitDisplayed(TestTags.FAMILY_VIEW)

        // Baseline section order: account → Members → Invite someone → Devices → Account actions.
        compose.onNodeWithText("Members").assertIsDisplayed()
        compose.onNodeWithText("Invite someone").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("● Member (kid)").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("○ Owner (adult)").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Devices").performScrollTo().assertIsDisplayed()
        compose.node(TestTags.OPEN_KIOSK).performScrollTo().assertIsDisplayed()
        compose.node(TestTags.OPEN_TRASH).performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Account").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Refresh everything").performScrollTo().assertIsDisplayed()
        compose.node(TestTags.SIGN_OUT).performScrollTo().assertIsDisplayed()
    }
}
