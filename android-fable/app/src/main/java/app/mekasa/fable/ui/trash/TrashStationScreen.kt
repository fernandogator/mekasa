package app.mekasa.fable.ui.trash

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import app.mekasa.fable.session.ConsumeOutcome
import app.mekasa.fable.session.ScanEvent
import app.mekasa.fable.session.SessionState
import app.mekasa.fable.session.SessionViewModel
import app.mekasa.fable.ui.TestTags
import app.mekasa.fable.ui.components.Backdrop
import app.mekasa.fable.ui.components.Card
import app.mekasa.fable.ui.components.Chip
import app.mekasa.fable.ui.components.LabeledField
import app.mekasa.fable.ui.components.LinkButton
import app.mekasa.fable.ui.components.PrimaryButton
import app.mekasa.fable.ui.components.ScreenHeader
import app.mekasa.fable.ui.components.SectionHeading
import app.mekasa.fable.ui.components.BarcodeScanner
import app.mekasa.fable.ui.theme.MekasaTheme
import app.mekasa.fable.ui.theme.Space
import app.mekasa.fable.ui.theme.Type
import kotlinx.coroutines.delay

/**
 * REQ-008 / UI-005: single-purpose scan-to-consume surface. In kiosk mode the shell is
 * hidden entirely and the last result is shown briefly, then resets (AC3).
 */
@Composable
fun TrashStationScreen(
    state: SessionState,
    session: SessionViewModel,
    kiosk: Boolean,
    onExit: () -> Unit,
) {
    val palette = MekasaTheme.palette
    val haptics = LocalHapticFeedback.current
    var scanGeneration by remember { mutableIntStateOf(0) }
    var manual by remember { mutableStateOf("") }
    var flash by remember { mutableStateOf<Pair<String, ScanEvent.Tone>?>(null) }
    // Bumped per accepted scan; drives the 5 s disarm window below.
    var cooldownGeneration by remember { mutableIntStateOf(0) }
    var cooldownSecondsLeft by remember { mutableStateOf<Int?>(null) }
    val coolingDown = cooldownSecondsLeft != null
    val inStock = state.data.inventory.filter { it.quantity > 0 }

    BackHandler(onBack = onExit)

    LaunchedEffect(Unit) {
        if (!state.isDemo) session.refreshUnknownScans()
    }

    LaunchedEffect(flash) {
        if (flash != null) {
            delay(2_500)
            flash = null
        }
    }

    // REQ-008: one accepted scan per window. The scanner stays disarmed (no generation
    // bump) and manual entry is disabled until the countdown ends, so a single toss
    // cannot be consumed twice by the same beep.
    LaunchedEffect(cooldownGeneration) {
        if (cooldownGeneration == 0) return@LaunchedEffect
        var left = ScanFeedback.COOLDOWN_SECONDS
        while (left > 0) {
            cooldownSecondsLeft = left
            delay(1_000)
            left -= 1
        }
        cooldownSecondsLeft = null
        scanGeneration += 1
    }

    fun consume(code: String) {
        if (coolingDown) return
        session.consumeByBarcode(code) { outcome ->
            flash = when (outcome) {
                is ConsumeOutcome.Used -> "Used 1 ${outcome.item.name} · ${outcome.item.quantity} left" to ScanEvent.Tone.Used
                is ConsumeOutcome.Depleted -> "${outcome.item.name} is now out" to ScanEvent.Tone.Depleted
                is ConsumeOutcome.Unknown -> "Unknown barcode ${outcome.barcode} logged" to ScanEvent.Tone.Unknown
                is ConsumeOutcome.Failed -> outcome.message to ScanEvent.Tone.Failed
            }
            when (outcome) {
                is ConsumeOutcome.Used, is ConsumeOutcome.Depleted -> ScanFeedback.accepted()
                is ConsumeOutcome.Unknown, is ConsumeOutcome.Failed -> ScanFeedback.unknown()
            }
            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
            manual = ""
            cooldownGeneration += 1
        }
    }

    Backdrop(modifier = Modifier.testTag(if (kiosk) TestTags.TRASH_KIOSK_VIEW else TestTags.TRASH_STATION_VIEW)) {
        Column(modifier = Modifier.fillMaxSize()) {
            ScreenHeader(
                title = if (kiosk) "Trash station" else "Dispose",
                eyebrow = if (kiosk) "Scan before you toss" else "Use one by barcode",
                onBack = if (kiosk) null else onExit,
                trailing = { if (kiosk) LinkButton("Exit kiosk", onClick = onExit, modifier = Modifier.testTag(TestTags.EXIT_KIOSK)) },
            )
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = Space.lg, end = Space.lg, top = Space.sm, bottom = Space.xxl),
                verticalArrangement = Arrangement.spacedBy(Space.md),
            ) {
                item {
                    AnimatedVisibility(visible = flash != null) {
                        val (message, tone) = flash ?: ("" to ScanEvent.Tone.Used)
                        Card(tint = tone.tint(), modifier = Modifier.testTag(TestTags.SCAN_FLASH)) {
                            Text(message, style = Type.subhead, color = tone.color())
                        }
                    }
                }
                item {
                    BarcodeScanner(
                        generation = scanGeneration,
                        onBarcode = ::consume,
                        modifier = Modifier.fillMaxWidth(),
                        height = if (kiosk) 320 else 220,
                    )
                }
                item {
                    AnimatedVisibility(visible = coolingDown) {
                        Card(tint = palette.accentTint, modifier = Modifier.testTag(TestTags.SCAN_COOLDOWN)) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.sm)) {
                                Text(
                                    "${cooldownSecondsLeft ?: ScanFeedback.COOLDOWN_SECONDS}",
                                    style = Type.title,
                                    color = palette.accent,
                                )
                                Text("Next scan in a moment", style = Type.subhead, color = palette.accent, modifier = Modifier.weight(1f))
                            }
                        }
                    }
                }
                item {
                    LabeledField(
                        label = "Or type the UPC",
                        value = manual,
                        onValueChange = { manual = it.filter(Char::isDigit).take(14) },
                        placeholder = "049000028911",
                        keyboardType = KeyboardType.Number,
                        imeAction = ImeAction.Go,
                        onSubmit = { if (manual.length >= 6) consume(manual) },
                        testTag = TestTags.MANUAL_BARCODE,
                    )
                    Spacer(Modifier.height(Space.sm))
                    PrimaryButton(
                        "Use 1 by barcode",
                        onClick = { consume(manual) },
                        enabled = manual.length >= 6 && !coolingDown,
                        modifier = Modifier.testTag(TestTags.MANUAL_CONSUME),
                    )
                }

                if (!kiosk) {
                    item { SectionHeading("In stock") }
                    if (inStock.isEmpty()) {
                        item { Card { Text("Nothing left to dispose.", style = Type.body, color = palette.textMuted) } }
                    }
                    items(inStock, key = { "stock-${it.id}" }) { item ->
                        Card {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(item.name, style = Type.body, color = palette.text)
                                    Text(
                                        listOfNotNull("qty ${item.quantity}", item.barcode).joinToString(" · "),
                                        style = Type.caption,
                                        color = palette.textMuted,
                                    )
                                }
                                LinkButton("Use 1", onClick = { session.consume(item.id) }, modifier = Modifier.testTag(TestTags.trashUse(item.id)))
                            }
                        }
                    }
                }

                if (state.data.scanFeed.isNotEmpty()) {
                    item { SectionHeading("Recent") }
                    items(state.data.scanFeed, key = { it.id }) { event ->
                        Card(padding = PaddingValues(horizontal = Space.base, vertical = Space.md)) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.sm)) {
                                Text(event.message, style = Type.bodyRegular, color = palette.text, modifier = Modifier.weight(1f))
                                Chip(event.tone.name, color = event.tone.color())
                            }
                        }
                    }
                }

                if (state.data.unknownScans.isNotEmpty()) {
                    item { SectionHeading("Unknown scans") }
                    items(state.data.unknownScans, key = { "unknown-${it.id}" }) { event ->
                        Card(tint = palette.warningTint) {
                            Text(event.barcode, style = Type.mono, color = palette.warning)
                            Text(event.createdAt ?: "logged", style = Type.caption, color = palette.textMuted)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ScanEvent.Tone.color() = when (this) {
    ScanEvent.Tone.Used -> MekasaTheme.palette.success
    ScanEvent.Tone.Depleted -> MekasaTheme.palette.accent
    ScanEvent.Tone.Unknown -> MekasaTheme.palette.warning
    ScanEvent.Tone.Failed -> MekasaTheme.palette.accent
}

@Composable
private fun ScanEvent.Tone.tint() = when (this) {
    ScanEvent.Tone.Used -> MekasaTheme.palette.successTint
    ScanEvent.Tone.Depleted, ScanEvent.Tone.Failed -> MekasaTheme.palette.accentTint
    ScanEvent.Tone.Unknown -> MekasaTheme.palette.warningTint
}
