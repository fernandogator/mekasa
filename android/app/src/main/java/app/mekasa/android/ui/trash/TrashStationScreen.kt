package app.mekasa.android.ui.trash

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
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
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import app.mekasa.android.session.AppSession
import app.mekasa.android.session.AppUiState
import app.mekasa.android.session.ConsumeResult
import app.mekasa.android.ui.components.BarcodeCameraOrPermission
import app.mekasa.android.ui.components.MekasaScreen
import app.mekasa.android.ui.components.MekasaTextField
import app.mekasa.android.ui.components.PrimaryButton
import app.mekasa.android.ui.components.ScanFeedback
import app.mekasa.android.ui.components.SecondaryButton
import app.mekasa.android.ui.components.SoftCard
import app.mekasa.android.ui.components.rememberScanFeedbackContext
import app.mekasa.android.ui.theme.MekasaColor
import app.mekasa.android.ui.theme.MekasaType
import app.mekasa.android.ui.theme.Spacing
import kotlinx.coroutines.delay

@Composable
fun TrashStationScreen(
    state: AppUiState,
    session: AppSession,
    kioskMode: Boolean,
    onExit: () -> Unit,
    contentPadding: PaddingValues = PaddingValues(),
) {
    val feedbackContext = rememberScanFeedbackContext()
    var scanKey by remember { mutableIntStateOf(0) }
    var manualCode by remember { mutableStateOf("") }
    var toast by remember { mutableStateOf<String?>(null) }
    // Bumped per accepted scan; drives the 5 s disarm window below.
    var cooldownGeneration by remember { mutableIntStateOf(0) }
    var cooldownSecondsLeft by remember { mutableStateOf<Int?>(null) }
    val coolingDown = cooldownSecondsLeft != null
    val inStock = state.inventory.filter { it.quantity > 0 }

    LaunchedEffect(Unit) {
        session.refreshUnknownTrashScans()
    }

    // REQ-008: one accepted scan per window. The scanner stays disarmed (no scanKey
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
        scanKey += 1
    }

    fun handleCode(code: String) {
        if (coolingDown) return
        session.consumeInventoryByBarcode(code) { result ->
            toast = when (result) {
                is ConsumeResult.Decremented -> "Used ${result.item.name}"
                is ConsumeResult.Depleted -> "Depleted ${result.item.name}"
                is ConsumeResult.Unknown -> "Unknown barcode ${result.barcode}"
                is ConsumeResult.Failed -> result.message
            }
            when (result) {
                is ConsumeResult.Decremented, is ConsumeResult.Depleted ->
                    ScanFeedback.accepted(feedbackContext)
                is ConsumeResult.Unknown, is ConsumeResult.Failed ->
                    ScanFeedback.unknown(feedbackContext)
            }
            manualCode = ""
            cooldownGeneration += 1
        }
    }

    MekasaScreen(modifier = Modifier.testTag("TrashStationView")) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                start = Spacing.lg,
                end = Spacing.lg,
                top = contentPadding.calculateTopPadding() + Spacing.base,
                bottom = contentPadding.calculateBottomPadding() + Spacing.xxl,
            ),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(
                        text = if (kioskMode) "Trash station" else "Dispose item",
                        style = MekasaType.title,
                        color = MekasaColor.brand,
                        modifier = Modifier.weight(1f),
                    )
                }
                Box(modifier = Modifier.height(Spacing.sm))
                SecondaryButton(
                    title = if (kioskMode) "Exit kiosk" else "Close",
                    onClick = onExit,
                )
            }

            if (toast != null) {
                item {
                    SoftCard {
                        Text(text = toast!!, style = MekasaType.body, color = MekasaColor.brand)
                    }
                }
            }

            if (coolingDown) {
                item {
                    SoftCard(modifier = Modifier.testTag("TrashScanCooldown")) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                        ) {
                            Text(
                                text = "${cooldownSecondsLeft ?: ScanFeedback.COOLDOWN_SECONDS}",
                                style = MekasaType.title,
                                color = MekasaColor.accent,
                            )
                            Text(
                                text = "Next scan in a moment",
                                style = MekasaType.subhead,
                                color = MekasaColor.accent,
                                modifier = Modifier.weight(1f),
                            )
                        }
                    }
                }
            }

            item {
                Text(
                    text = "Scan barcode to use 1",
                    style = MekasaType.subhead,
                    color = MekasaColor.brand,
                )
                Box(modifier = Modifier.height(Spacing.sm))
                BarcodeCameraOrPermission(
                    scanKey = scanKey,
                    onBarcode = { handleCode(it) },
                )
            }

            item {
                MekasaTextField(
                    label = "Or type UPC",
                    value = manualCode,
                    onValueChange = { manualCode = it.filter { ch -> ch.isDigit() } },
                    placeholder = "049000028911",
                    keyboardType = KeyboardType.Number,
                    imeAction = ImeAction.Go,
                    onImeAction = { if (manualCode.length >= 6) handleCode(manualCode) },
                    testTag = "TrashManualBarcode",
                )
                Box(modifier = Modifier.height(Spacing.sm))
                PrimaryButton(
                    title = "Use barcode",
                    enabled = manualCode.length >= 6 && !coolingDown,
                    onClick = { handleCode(manualCode) },
                )
            }

            item {
                Text(text = "In stock", style = MekasaType.subhead, color = MekasaColor.brand)
            }
            if (inStock.isEmpty()) {
                item {
                    SoftCard {
                        Text(
                            text = "Nothing left to dispose.",
                            style = MekasaType.body,
                            color = MekasaColor.textMuted,
                        )
                    }
                }
            } else {
                items(inStock, key = { it.id }) { item ->
                    SoftCard {
                        Column(modifier = Modifier.fillMaxWidth()) {
                            Text(text = item.name, style = MekasaType.body, color = MekasaColor.brand)
                            Text(
                                text = "qty ${item.quantity}" +
                                    (item.barcode?.let { " · $it" } ?: ""),
                                style = MekasaType.label,
                                color = MekasaColor.textMuted,
                            )
                            Box(modifier = Modifier.height(Spacing.sm))
                            SecondaryButton(
                                title = "Use 1",
                                onClick = { session.consumeInventoryItem(item.id) },
                            )
                        }
                    }
                }
            }

            if (state.trashEvents.isNotEmpty()) {
                item {
                    Text(text = "Recent", style = MekasaType.subhead, color = MekasaColor.brand)
                }
                items(state.trashEvents, key = { it.id }) { event ->
                    SoftCard {
                        Text(
                            text = event.message,
                            style = MekasaType.body,
                            color = if (event.isUnknown) MekasaColor.warning else MekasaColor.brand,
                        )
                    }
                }
            }

            if (state.unknownTrashScans.isNotEmpty()) {
                item {
                    Text(
                        text = "Unknown scans",
                        style = MekasaType.subhead,
                        color = MekasaColor.brand,
                    )
                }
                items(state.unknownTrashScans, key = { it.id }) { event ->
                    SoftCard {
                        Text(text = event.barcode, style = MekasaType.body, color = MekasaColor.warning)
                        Text(
                            text = event.createdAt ?: "logged",
                            style = MekasaType.label,
                            color = MekasaColor.textMuted,
                        )
                    }
                }
            }
        }
    }
}
