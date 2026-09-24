package app.mekasa.fable.ui.family

import android.content.Intent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.DeleteSweep
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
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
import app.mekasa.fable.session.SessionState
import app.mekasa.fable.session.SessionViewModel
import app.mekasa.fable.ui.components.Card
import app.mekasa.fable.ui.components.Chip
import app.mekasa.fable.ui.components.IconWell
import app.mekasa.fable.ui.components.LabeledField
import app.mekasa.fable.ui.components.LinkButton
import app.mekasa.fable.ui.components.PrimaryButton
import app.mekasa.fable.ui.components.ScreenHeader
import app.mekasa.fable.ui.components.SecondaryButton
import app.mekasa.fable.ui.components.SectionHeading
import app.mekasa.fable.ui.theme.MekasaTheme
import app.mekasa.fable.ui.theme.Space
import app.mekasa.fable.ui.theme.Type

/** REQ-019: members, invites (share link), pending invite acceptance, plus account actions. */
@Composable
fun FamilyScreen(
    state: SessionState,
    session: SessionViewModel,
    contentPadding: PaddingValues,
    onOpenTrash: () -> Unit,
) {
    val palette = MekasaTheme.palette
    val context = LocalContext.current
    var inviteName by rememberSaveable { mutableStateOf("") }
    var inviteEmail by rememberSaveable { mutableStateOf("") }
    var inviteRole by rememberSaveable { mutableStateOf("member") }

    LaunchedEffect(state.household?.id) {
        if (!state.isDemo) session.refreshFamily()
    }

    Column(modifier = Modifier.fillMaxSize().testTag("FamilyScreen")) {
        ScreenHeader(title = "Family", eyebrow = state.household?.name ?: "Household")
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = Space.lg)
                .padding(bottom = contentPadding.calculateBottomPadding() + Space.xxl),
            verticalArrangement = Arrangement.spacedBy(Space.base),
        ) {
            Card {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.md)) {
                    IconWell(Icons.Outlined.Person, tint = palette.text, background = palette.overlay, size = 44.dp)
                    Column(modifier = Modifier.weight(1f)) {
                        Text(state.account?.shortName ?: "Signed in", style = Type.subhead, color = palette.text)
                        Text(state.account?.email ?: "", style = Type.caption, color = palette.textMuted)
                    }
                    Chip(if (state.isOwner) "Owner" else "Member", color = if (state.isOwner) palette.success else palette.textMuted)
                }
                if (state.isDemo) {
                    Spacer(Modifier.height(Space.sm))
                    Chip("Offline preview", color = palette.warning)
                }
            }

            state.pendingInviteToken?.let {
                Card(tint = palette.warningTint) {
                    Text("You have a pending invite.", style = Type.body, color = palette.text)
                    Text("Accept to join that household.", style = Type.caption, color = palette.textMuted)
                    Spacer(Modifier.height(Space.sm))
                    PrimaryButton("Accept invite", onClick = session::acceptPendingInviteIfPossible, loading = state.busy)
                }
            }

            SectionHeading("Members", actionLabel = "Refresh", onAction = { session.refreshFamily() })
            if (state.data.members.isEmpty()) {
                Card { Text("You're the only member so far.", style = Type.body, color = palette.textMuted) }
            }
            state.data.members.forEach { member ->
                Card(modifier = Modifier.testTag("Member-${member.uid}")) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.md)) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(member.displayLabel, style = Type.body, color = palette.text)
                            Text(
                                listOfNotNull(member.email, member.status).joinToString(" · "),
                                style = Type.caption,
                                color = palette.textMuted,
                            )
                        }
                        Chip(member.role.replaceFirstChar { it.uppercase() }, color = if (member.isOwner) palette.success else palette.textMuted)
                    }
                    if (state.isOwner && !member.isOwner && member.uid != state.account?.uid) {
                        LinkButton("Make owner", onClick = { session.promoteToOwner(member.uid) })
                    }
                }
            }

            SectionHeading("Invite someone")
            Card {
                LabeledField(label = "Name", value = inviteName, onValueChange = { inviteName = it }, placeholder = "Alex", testTag = "InviteName")
                Spacer(Modifier.height(Space.sm))
                LabeledField(
                    label = "Email (optional)",
                    value = inviteEmail,
                    onValueChange = { inviteEmail = it },
                    placeholder = "alex@example.com",
                    keyboardType = KeyboardType.Email,
                    capitalization = KeyboardCapitalization.None,
                    imeAction = ImeAction.Done,
                    testTag = "InviteEmail",
                )
                Spacer(Modifier.height(Space.sm))
                Row(horizontalArrangement = Arrangement.spacedBy(Space.sm)) {
                    listOf("member" to "Member (kid)", "owner" to "Owner (adult)").forEach { (role, label) ->
                        val active = inviteRole == role
                        LinkButton(
                            text = (if (active) "● " else "○ ") + label,
                            onClick = { inviteRole = role },
                            color = if (active) palette.text else palette.textMuted,
                        )
                    }
                }
                Spacer(Modifier.height(Space.sm))
                PrimaryButton(
                    text = "Create invite",
                    onClick = {
                        session.createInvite(inviteName, inviteEmail, inviteRole)
                        inviteName = ""
                        inviteEmail = ""
                    },
                    enabled = inviteName.isNotBlank(),
                    loading = state.busy,
                    modifier = Modifier.testTag("CreateInvite"),
                )
            }

            val pending = state.data.invites.filter { it.status == "pending" }
            if (pending.isNotEmpty()) {
                SectionHeading("Pending invites")
                pending.forEach { invite ->
                    Card {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(invite.name, style = Type.body, color = palette.text)
                                Text(
                                    listOfNotNull(invite.email, invite.role).joinToString(" · "),
                                    style = Type.caption,
                                    color = palette.textMuted,
                                )
                            }
                            LinkButton(
                                "Share",
                                onClick = {
                                    val send = Intent(Intent.ACTION_SEND).apply {
                                        type = "text/plain"
                                        putExtra(Intent.EXTRA_SUBJECT, "Join ${state.household?.name ?: "our household"} on Mekasa")
                                        putExtra(Intent.EXTRA_TEXT, "Join our household on Mekasa: ${invite.shareLink}")
                                    }
                                    context.startActivity(Intent.createChooser(send, "Share invite"))
                                },
                            )
                        }
                    }
                }
            }

            SectionHeading("Devices")
            SecondaryButton("Trash station kiosk", onClick = { session.setKioskMode(true) }, icon = Icons.Outlined.DeleteSweep, modifier = Modifier.testTag("OpenKiosk"))
            SecondaryButton("Dispose one item", onClick = onOpenTrash, icon = Icons.Outlined.Share)

            SectionHeading("Account")
            SecondaryButton("Refresh everything", onClick = { session.refreshAll() })
            PrimaryButton("Sign out", onClick = session::signOut, accent = true, modifier = Modifier.testTag("SignOut"))
        }
    }
}