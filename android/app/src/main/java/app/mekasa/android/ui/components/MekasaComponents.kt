package app.mekasa.android.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.mekasa.android.session.OnboardingStep
import app.mekasa.android.ui.theme.MekasaColor
import app.mekasa.android.ui.theme.MekasaShapes
import app.mekasa.android.ui.theme.MekasaType
import app.mekasa.android.ui.theme.Spacing

@Composable
fun MekasaScreen(
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(MekasaColor.surface),
    ) {
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .offset(x = 80.dp, y = (-80).dp)
                .size(300.dp)
                .blur(40.dp)
                .background(MekasaColor.brandMuted.copy(alpha = 0.2f), CircleShape),
        )
        content()
    }
}

@Composable
fun OnboardingHeader(step: OnboardingStep) {
    val label = when (step) {
        OnboardingStep.Welcome -> ""
        OnboardingStep.Household -> "Step 1 of 3"
        OnboardingStep.Address -> "Step 2 of 3"
        OnboardingStep.Stores -> "Step 3 of 3"
        OnboardingStep.Done -> ""
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = Spacing.sm),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (label.isNotEmpty()) {
            Text(
                text = label.uppercase(),
                style = MekasaType.label,
                color = MekasaColor.textMuted,
            )
        }
        Text(
            text = "Mekasa",
            style = MekasaType.title,
            color = MekasaColor.brand,
        )
    }
}

@Composable
fun PrimaryButton(
    title: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isLoading: Boolean = false,
    onClick: () -> Unit,
) {
    Button(
        onClick = onClick,
        enabled = enabled && !isLoading,
        modifier = modifier
            .fillMaxWidth()
            .height(56.dp),
        shape = MekasaShapes.button,
        colors = ButtonDefaults.buttonColors(
            containerColor = MekasaColor.brand,
            contentColor = Color.White,
            disabledContainerColor = MekasaColor.brand.copy(alpha = 0.4f),
            disabledContentColor = Color.White.copy(alpha = 0.7f),
        ),
        contentPadding = PaddingValues(horizontal = Spacing.lg),
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.size(22.dp),
                color = Color.White,
                strokeWidth = 2.dp,
            )
        } else {
            Text(text = title, style = MekasaType.body)
        }
    }
}

@Composable
fun SecondaryButton(
    title: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    OutlinedButton(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier
            .fillMaxWidth()
            .height(56.dp),
        shape = MekasaShapes.button,
        colors = ButtonDefaults.outlinedButtonColors(
            contentColor = MekasaColor.brand,
        ),
        border = BorderStroke(1.5.dp, MekasaColor.brandMuted),
    ) {
        Text(text = title, style = MekasaType.body)
    }
}

@Composable
fun MekasaTextField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    fieldModifier: Modifier = Modifier,
    placeholder: String = "",
    isSecure: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
    capitalization: KeyboardCapitalization = KeyboardCapitalization.Sentences,
    imeAction: ImeAction = ImeAction.Next,
    onImeAction: (() -> Unit)? = null,
    testTag: String? = null,
) {
    Column(modifier = fieldModifier.fillMaxWidth()) {
        Text(
            text = label.uppercase(),
            style = MekasaType.label,
            color = MekasaColor.textMuted,
        )
        Box(modifier = Modifier.height(Spacing.sm))
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier
                .fillMaxWidth()
                .then(if (testTag != null) Modifier.testTag(testTag) else Modifier),
            placeholder = {
                Text(placeholder, color = MekasaColor.textMuted.copy(alpha = 0.6f))
            },
            singleLine = true,
            shape = MekasaShapes.input,
            visualTransformation = if (isSecure) {
                PasswordVisualTransformation()
            } else {
                VisualTransformation.None
            },
            keyboardOptions = KeyboardOptions(
                keyboardType = keyboardType,
                capitalization = capitalization,
                imeAction = imeAction,
            ),
            keyboardActions = KeyboardActions(
                onDone = { onImeAction?.invoke() },
                onGo = { onImeAction?.invoke() },
                onSend = { onImeAction?.invoke() },
            ),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = MekasaColor.brand,
                unfocusedBorderColor = MekasaColor.brandMuted,
                focusedContainerColor = MekasaColor.surfaceElevated,
                unfocusedContainerColor = MekasaColor.surfaceElevated,
                cursorColor = MekasaColor.accent,
            ),
        )
    }
}

@Composable
fun StickyBottomBar(
    progress: Float,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(MekasaColor.surface.copy(alpha = 0.96f))
            .padding(horizontal = Spacing.lg, vertical = Spacing.base),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(4.dp)
                .background(MekasaColor.overlay, MekasaShapes.pill),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(progress.coerceIn(0.05f, 1f))
                    .height(4.dp)
                    .background(MekasaColor.brand, MekasaShapes.pill),
            )
        }
        Box(modifier = Modifier.height(Spacing.base))
        content()
    }
}

@Composable
fun SectionTitle(
    title: String,
    subtitle: String? = null,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier) {
        Text(text = title, style = MekasaType.title, color = MekasaColor.brand)
        if (subtitle != null) {
            Box(modifier = Modifier.height(Spacing.sm))
            Text(text = subtitle, style = MekasaType.body, color = MekasaColor.textMuted)
        }
    }
}

@Composable
fun EmptyState(
    message: String,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .padding(Spacing.xl),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = message,
            style = MekasaType.body,
            color = MekasaColor.textMuted,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
fun SoftCard(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(MekasaColor.surfaceElevated, MekasaShapes.nested)
            .border(1.dp, MekasaColor.overlay, MekasaShapes.nested)
            .padding(Spacing.base),
        content = content,
    )
}
