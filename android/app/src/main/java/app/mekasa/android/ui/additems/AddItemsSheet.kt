package app.mekasa.android.ui.additems

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import app.mekasa.android.ui.components.SecondaryButton
import app.mekasa.android.ui.theme.MekasaColor
import app.mekasa.android.ui.theme.MekasaType
import app.mekasa.android.ui.theme.Spacing

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddItemsSheet(
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MekasaColor.surface,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.lg)
                .padding(bottom = Spacing.xl)
                .testTag("AddItemsSheet"),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Text(
                text = "Add items",
                style = MekasaType.title,
                color = MekasaColor.brand,
            )
            Text(
                text = "Barcode camera, receipt OCR, and voice entry land in a follow-up. Use inventory refresh from Settings for now.",
                style = MekasaType.body,
                color = MekasaColor.textMuted,
            )
            SecondaryButton(title = "Scan barcode (soon)", enabled = false, onClick = {})
            SecondaryButton(title = "Scan receipt (soon)", enabled = false, onClick = {})
            SecondaryButton(title = "Voice add (soon)", enabled = false, onClick = {})
            SecondaryButton(title = "Close", onClick = onDismiss)
        }
    }
}
