package app.mekasa.android.ui.family

import android.content.Intent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import app.mekasa.android.session.AppSession
import app.mekasa.android.session.AppUiState
import app.mekasa.android.ui.components.MekasaTextField
import app.mekasa.android.ui.components.PrimaryButton
import app.mekasa.android.ui.components.SecondaryButton
import app.mekasa.android.ui.components.SoftCard
import app.mekasa.android.ui.theme.MekasaColor
import app.mekasa.android.ui.theme.MekasaType
import app.mekasa.android.ui.theme.Spacing

@Composable
fun FamilyScreen(
    state: AppUiState,
    session: AppSession,
    contentPadding: PaddingValues = PaddingValues(),
) {
    var inviteName by remember { mutableStateOf("") }
    var inviteEmail by remember { mutableStateOf("") }
    val context = LocalContext.current

    LaunchedEffect(state.household?.id, state.isOfflinePreview) {
        session.refreshFamily()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(contentPadding)
            .padding(horizontal = Spacing.lg)
            .padding(top = Spacing.base, bottom = Spacing.xxl)
            .testTag("FamilyView"),
        verticalArrangement = Arrangement.spacedBy(Spacing.base),
    ) {
        Text(text = "Family & settings", style = MekasaType.title, color = MekasaColor.brand)

        SoftCard {
            Text(
                text = state.displayName ?: "Signed in",
                style = MekasaType.subhead,
                color = MekasaColor.brand,
            )
            Text(
                text = state.email ?: "",
                style = MekasaType.body,
                color = MekasaColor.textMuted,
            )
            if (state.isOfflinePreview) {
                Text(
                    text = "Offline preview mode",
                    style = MekasaType.label,
                    color = MekasaColor.warning,
                    modifier = Modifier.padding(top = Spacing.sm),
                )
            }
        }

        SoftCard {
            Text(
                text = state.household?.name ?: "No household",
                style = MekasaType.body,
                color = MekasaColor.brand,
            )
            Text(
                text = state.household?.address ?: "Address not set",
                style = MekasaType.label,
                color = MekasaColor.textMuted,
            )
        }

        if (!state.pendingInviteToken.isNullOrBlank()) {
            SoftCard {
                Text(
                    text = "You have a pending invite.",
                    style = MekasaType.body,
                    color = MekasaColor.brand,
                )
                Box(modifier = Modifier.height(Spacing.sm))
                PrimaryButton(
                    title = "Accept invite",
                    isLoading = state.isBusy,
                    onClick = session::acceptPendingInviteIfNeeded,
                )
            }
        }

        Text(text = "Members", style = MekasaType.subhead, color = MekasaColor.brand)
        if (state.members.isEmpty()) {
            SoftCard {
                Text(
                    text = "You’re the only member so far.",
                    style = MekasaType.body,
                    color = MekasaColor.textMuted,
                )
            }
        } else {
            state.members.forEach { member ->
                SoftCard {
                    Text(
                        text = member.name ?: member.email ?: member.uid,
                        style = MekasaType.body,
                        color = MekasaColor.brand,
                    )
                    Text(
                        text = "${member.role} · ${member.status}",
                        style = MekasaType.label,
                        color = MekasaColor.textMuted,
                    )
                    if (member.role != "owner" && member.uid != state.userUid) {
                        TextButton(onClick = { session.promoteMemberToOwner(member.uid) }) {
                            Text("Make owner", color = MekasaColor.accent, style = MekasaType.label)
                        }
                    }
                }
            }
        }

        Text(text = "Invite someone", style = MekasaType.subhead, color = MekasaColor.brand)
        SoftCard {
            MekasaTextField(
                label = "Name",
                value = inviteName,
                onValueChange = { inviteName = it },
                placeholder = "Alex",
                imeAction = ImeAction.Next,
            )
            Box(modifier = Modifier.height(Spacing.sm))
            MekasaTextField(
                label = "Email (optional)",
                value = inviteEmail,
                onValueChange = { inviteEmail = it },
                placeholder = "alex@example.com",
                keyboardType = KeyboardType.Email,
                capitalization = KeyboardCapitalization.None,
                imeAction = ImeAction.Done,
            )
            Box(modifier = Modifier.height(Spacing.md))
            PrimaryButton(
                title = "Send invite",
                enabled = inviteName.isNotBlank(),
                isLoading = state.isBusy,
                onClick = {
                    session.createInvite(inviteName, inviteEmail.ifBlank { null })
                    inviteName = ""
                    inviteEmail = ""
                },
            )
        }

        if (state.invites.isNotEmpty()) {
            Text(text = "Pending invites", style = MekasaType.subhead, color = MekasaColor.brand)
            state.invites.filter { it.status == "pending" }.forEach { invite ->
                SoftCard {
                    Text(text = invite.name, style = MekasaType.body, color = MekasaColor.brand)
                    Text(
                        text = listOfNotNull(invite.email, invite.role, invite.status)
                            .joinToString(" · "),
                        style = MekasaType.label,
                        color = MekasaColor.textMuted,
                    )
                    val link = invite.inviteLink ?: "mekasa://invite?token=${invite.token}"
                    TextButton(
                        onClick = {
                            val share = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, link)
                            }
                            context.startActivity(Intent.createChooser(share, "Share invite"))
                        },
                    ) {
                        Text("Share link", color = MekasaColor.accent, style = MekasaType.label)
                    }
                }
            }
        }

        PrimaryButton(title = "Refresh data", onClick = {
            session.refreshDashboard()
            session.refreshFamily()
        })
        SecondaryButton(title = "Sign out", onClick = session::signOut)
    }
}
