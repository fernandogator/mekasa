package app.mekasa.fable.ui.inventory

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Verified
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.testTag
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import app.mekasa.fable.data.DismissedDuplicates
import app.mekasa.fable.data.InventoryDuplicates
import app.mekasa.fable.data.model.DuplicateGroup
import app.mekasa.fable.data.model.InventoryItem
import app.mekasa.fable.session.SessionState
import app.mekasa.fable.session.SessionViewModel
import app.mekasa.fable.ui.TestTags
import app.mekasa.fable.ui.components.Backdrop
import app.mekasa.fable.ui.components.Card
import app.mekasa.fable.ui.components.Chip
import app.mekasa.fable.ui.components.PrimaryButton
import app.mekasa.fable.ui.components.ProductThumbnail
import app.mekasa.fable.ui.components.ScreenHeader
import app.mekasa.fable.ui.components.SecondaryButton
import app.mekasa.fable.ui.theme.MekasaTheme
import app.mekasa.fable.ui.theme.Shapes
import app.mekasa.fable.ui.theme.Space
import app.mekasa.fable.ui.theme.Type

/**
 * Duplicates review: one card per group with the survivor marked "Keeps this photo",
 * Merge / Not duplicates per card and "Merge all N" at the bottom.
 * Satisfies: REQ-INV-021 AC5–AC7
 * Design: design/pages/inventory-duplicates.html
 * Spec version: 1.0
 */
@Composable
fun DuplicatesScreen(
    state: SessionState,
    session: SessionViewModel,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val dismissed = remember(state.household?.id) {
        DismissedDuplicates(context.getSharedPreferences(DismissedDuplicates.PREFS, Context.MODE_PRIVATE), state.household?.id)
    }
    var groups by remember { mutableStateOf<List<DuplicateGroup>?>(null) }
    var merging by remember { mutableStateOf(emptySet<String>()) }
    var confirmation by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        session.findDuplicates { outcome ->
            groups = outcome.groups?.let(dismissed::visible) ?: emptyList()
            error = outcome.error
        }
    }

    fun merge(selected: List<DuplicateGroup>) {
        merging = merging + selected.map { it.id }
        session.mergeDuplicates(selected) { outcome ->
            val mergedIds = outcome.merged.mapTo(HashSet()) { it.id }
            groups = groups?.filterNot { it.id in mergedIds }
            merging = merging - selected.map { it.id }.toSet()
            outcome.confirmation?.let { confirmation = it }
            error = outcome.error
        }
    }

    val shown = groups
    Backdrop(modifier = Modifier.testTag(TestTags.DUPLICATES_VIEW)) {
        Column(modifier = Modifier.fillMaxSize()) {
            ScreenHeader(
                title = "Duplicates",
                eyebrow = shown?.takeIf { it.isNotEmpty() }?.let { InventoryDuplicates.headline(it.size) },
                onBack = onBack,
            )
            confirmation?.let { Banner(it) }
            error?.let {
                Text(
                    it,
                    style = Type.caption,
                    color = MekasaTheme.palette.danger,
                    modifier = Modifier.padding(horizontal = Space.lg, vertical = Space.xs).testTag(TestTags.DUPLICATES_ERROR),
                )
            }
            when {
                shown == null -> Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(modifier = Modifier.testTag(TestTags.DUPLICATES_LOADING))
                }
                shown.isEmpty() -> EmptyState()
                else -> {
                    LazyColumn(
                        modifier = Modifier.weight(1f),
                        contentPadding = PaddingValues(start = Space.lg, end = Space.lg, top = Space.sm, bottom = Space.base),
                        verticalArrangement = Arrangement.spacedBy(Space.base),
                    ) {
                        items(shown, key = { it.id }) { group ->
                            GroupCard(
                                group = group,
                                busy = merging.isNotEmpty(),
                                merging = group.id in merging,
                                onMerge = { merge(listOf(group)) },
                                onDismiss = {
                                    dismissed.dismiss(group)
                                    groups = groups?.filterNot { it.id == group.id }
                                },
                            )
                        }
                    }
                    PrimaryButton(
                        "Merge all ${shown.size}",
                        onClick = { merge(shown) },
                        enabled = merging.isEmpty(),
                        loading = merging.size > 1,
                        accent = true,
                        modifier = Modifier
                            .navigationBarsPadding()
                            .padding(horizontal = Space.lg, vertical = Space.base)
                            .testTag(TestTags.DUPLICATES_MERGE_ALL_BUTTON),
                    )
                }
            }
        }
    }
}

@Composable
private fun Banner(text: String) {
    val palette = MekasaTheme.palette
    Text(
        text,
        style = Type.body,
        color = palette.onBrand,
        modifier = Modifier
            .padding(horizontal = Space.lg, vertical = Space.xs)
            .fillMaxWidth()
            .background(palette.brand, Shapes.pill)
            .padding(horizontal = Space.lg, vertical = Space.md)
            .testTag(TestTags.DUPLICATES_CONFIRMATION),
    )
}

@Composable
private fun EmptyState() {
    val palette = MekasaTheme.palette
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(Space.lg)
            .testTag(TestTags.DUPLICATES_EMPTY_STATE),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(Icons.Outlined.Verified, contentDescription = null, tint = palette.accent, modifier = Modifier.size(40.dp))
        Text(InventoryDuplicates.EMPTY_TITLE, style = Type.subhead, color = palette.text, modifier = Modifier.padding(top = Space.sm))
        Text(InventoryDuplicates.EMPTY_SUBTITLE, style = Type.bodyRegular, color = palette.textMuted)
    }
}

@Composable
private fun GroupCard(
    group: DuplicateGroup,
    busy: Boolean,
    merging: Boolean,
    onMerge: () -> Unit,
    onDismiss: () -> Unit,
) {
    val palette = MekasaTheme.palette
    Card(modifier = Modifier.testTag(TestTags.duplicatesGroup(group.id))) {
        Column(verticalArrangement = Arrangement.spacedBy(Space.md)) {
            Chip(group.reason.label, color = palette.accent, background = palette.accentTint)
            group.items.forEach { item -> ItemRow(item, keeps = item.id == group.keepId) }
            group.survivor?.let { survivor ->
                Text(
                    buildAnnotatedString {
                        append("Merges into ")
                        withStyle(SpanStyle(color = palette.text, fontWeight = FontWeight.Black)) { append(survivor.name) }
                        append(" · ${InventoryDuplicates.resultDetail(group)}")
                    },
                    style = Type.caption,
                    color = palette.textMuted,
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(Space.md)) {
                PrimaryButton(
                    "Merge",
                    onClick = onMerge,
                    enabled = !busy,
                    loading = merging,
                    modifier = Modifier.weight(1f).testTag(TestTags.duplicatesMerge(group.id)),
                )
                SecondaryButton(
                    "Not duplicates",
                    onClick = onDismiss,
                    enabled = !busy,
                    modifier = Modifier.weight(1f).testTag(TestTags.duplicatesDismiss(group.id)),
                )
            }
        }
    }
}

@Composable
private fun ItemRow(item: InventoryItem, keeps: Boolean) {
    val palette = MekasaTheme.palette
    val photoAge = InventoryDuplicates.photoAge(item)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clearAndSetSemantics {
                testTag = TestTags.duplicatesItem(item.id)
                contentDescription = if (keeps) "${item.name}, keeps this photo" else item.name
                stateDescription = "${item.category}, quantity ${item.quantity}, $photoAge"
            },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Space.md),
    ) {
        ProductThumbnail(imageUrl = item.imageUrl, name = item.name, size = 48.dp)
        Column(modifier = Modifier.weight(1f)) {
            Text(item.name, style = Type.body, color = palette.text, maxLines = 2)
            Text("${item.category} · qty ${item.quantity}", style = Type.caption, color = palette.textMuted)
            Text(photoAge, style = Type.caption, color = palette.textMuted)
        }
        if (keeps) Chip(InventoryDuplicates.KEEPS_PHOTO, color = palette.onAccent, background = palette.accent)
    }
}
