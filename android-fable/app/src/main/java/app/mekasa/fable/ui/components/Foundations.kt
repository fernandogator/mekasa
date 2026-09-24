package app.mekasa.fable.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.mekasa.fable.ui.theme.MekasaTheme
import app.mekasa.fable.ui.theme.Shapes
import app.mekasa.fable.ui.theme.Space
import app.mekasa.fable.ui.theme.Type

/** Page backdrop: warm surface plus the blurred sage blob in the upper-right corner. */
@Composable
fun Backdrop(
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit,
) {
    val palette = MekasaTheme.palette
    Box(modifier = modifier.fillMaxSize().background(palette.surface)) {
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .offset(x = 60.dp, y = (-60).dp)
                .size(300.dp)
                .blur(40.dp)
                .background(palette.brandMuted.copy(alpha = 0.22f), CircleShape),
        )
        content()
    }
}

/** Title row with optional back arrow and trailing actions; pads for the status bar. */
@Composable
fun ScreenHeader(
    title: String,
    modifier: Modifier = Modifier,
    eyebrow: String? = null,
    onBack: (() -> Unit)? = null,
    trailing: @Composable () -> Unit = {},
) {
    val palette = MekasaTheme.palette
    Row(
        modifier = modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .padding(horizontal = Space.base, vertical = Space.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (onBack != null) {
            IconButton(onClick = onBack, modifier = Modifier.testTag("BackButton")) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = palette.text)
            }
        } else {
            Spacer(Modifier.size(Space.sm))
        }
        Column(modifier = Modifier.weight(1f)) {
            if (eyebrow != null) {
                Text(eyebrow.uppercase(), style = Type.label, color = palette.textMuted)
            }
            Text(title, style = Type.title, color = palette.text)
        }
        trailing()
    }
}

@Composable
fun SectionLabel(text: String, modifier: Modifier = Modifier) {
    Text(text.uppercase(), style = Type.label, color = MekasaTheme.palette.textMuted, modifier = modifier)
}

@Composable
fun SectionHeading(
    title: String,
    modifier: Modifier = Modifier,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
) {
    val palette = MekasaTheme.palette
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = Type.subhead, color = palette.text)
        if (actionLabel != null && onAction != null) {
            TextButton(onClick = onAction) {
                Text(actionLabel, style = Type.caption, color = palette.accent)
            }
        }
    }
}

/** White card with the 24dp nested radius used for rows and grouped content. */
@Composable
fun Card(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    padding: PaddingValues = PaddingValues(Space.base),
    tint: Color? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val palette = MekasaTheme.palette
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(Shapes.card)
            .background(tint ?: palette.surfaceElevated)
            .border(1.dp, palette.brandMuted.copy(alpha = 0.3f), Shapes.card)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(padding),
        content = content,
    )
}

/** Large sheet-style container (40dp radius) for hero groups. */
@Composable
fun Sheet(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    val palette = MekasaTheme.palette
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(Shapes.sheet)
            .background(palette.surfaceElevated)
            .border(1.dp, palette.brandMuted.copy(alpha = 0.3f), Shapes.sheet)
            .padding(Space.lg),
        content = content,
    )
}

@Composable
fun PrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    loading: Boolean = false,
    accent: Boolean = false,
    icon: ImageVector? = null,
) {
    val palette = MekasaTheme.palette
    val container = if (accent) palette.accent else palette.brand
    val content = if (palette.isDark && !accent) palette.surface else Color.White
    Button(
        onClick = onClick,
        enabled = enabled && !loading,
        modifier = modifier.fillMaxWidth().height(56.dp),
        shape = Shapes.button,
        colors = ButtonDefaults.buttonColors(
            containerColor = container,
            contentColor = content,
            disabledContainerColor = container.copy(alpha = 0.35f),
            disabledContentColor = content.copy(alpha = 0.7f),
        ),
    ) {
        if (loading) {
            CircularProgressIndicator(modifier = Modifier.size(22.dp), color = content, strokeWidth = 2.dp)
        } else {
            if (icon != null) {
                Icon(icon, contentDescription = null, modifier = Modifier.size(20.dp))
                Spacer(Modifier.size(Space.sm))
            }
            Text(text, style = Type.button)
        }
    }
}

@Composable
fun SecondaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    icon: ImageVector? = null,
) {
    val palette = MekasaTheme.palette
    OutlinedButton(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.fillMaxWidth().height(56.dp),
        shape = Shapes.button,
        colors = ButtonDefaults.outlinedButtonColors(
            containerColor = palette.surfaceElevated,
            contentColor = palette.text,
            disabledContentColor = palette.textMuted,
        ),
        border = BorderStroke(1.dp, palette.brandMuted),
    ) {
        if (icon != null) {
            Icon(icon, contentDescription = null, modifier = Modifier.size(20.dp))
            Spacer(Modifier.size(Space.sm))
        }
        Text(text, style = Type.button)
    }
}

@Composable
fun LinkButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    color: Color = MekasaTheme.palette.accent,
    enabled: Boolean = true,
) {
    TextButton(onClick = onClick, modifier = modifier, enabled = enabled) {
        Text(text, style = Type.caption, color = if (enabled) color else MekasaTheme.palette.textMuted)
    }
}

@Composable
fun LabeledField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    placeholder: String = "",
    secure: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
    capitalization: KeyboardCapitalization = KeyboardCapitalization.Sentences,
    imeAction: ImeAction = ImeAction.Next,
    onSubmit: (() -> Unit)? = null,
    singleLine: Boolean = true,
    testTag: String? = null,
    trailing: @Composable (() -> Unit)? = null,
) {
    val palette = MekasaTheme.palette
    Column(modifier = modifier.fillMaxWidth()) {
        SectionLabel(label)
        Spacer(Modifier.height(Space.sm))
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier
                .fillMaxWidth()
                .then(if (testTag != null) Modifier.testTag(testTag) else Modifier),
            placeholder = { Text(placeholder, style = Type.body, color = palette.textMuted.copy(alpha = 0.6f)) },
            singleLine = singleLine,
            minLines = if (singleLine) 1 else 3,
            shape = Shapes.field,
            textStyle = Type.body,
            visualTransformation = if (secure) PasswordVisualTransformation() else VisualTransformation.None,
            keyboardOptions = KeyboardOptions(
                keyboardType = keyboardType,
                capitalization = capitalization,
                imeAction = imeAction,
            ),
            keyboardActions = KeyboardActions(
                onDone = { onSubmit?.invoke() },
                onGo = { onSubmit?.invoke() },
                onSearch = { onSubmit?.invoke() },
                onSend = { onSubmit?.invoke() },
            ),
            trailingIcon = trailing,
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = palette.accent,
                unfocusedBorderColor = palette.brandMuted.copy(alpha = 0.6f),
                focusedContainerColor = palette.surfaceElevated,
                unfocusedContainerColor = palette.surfaceElevated,
                cursorColor = palette.accent,
                focusedTextColor = palette.text,
                unfocusedTextColor = palette.text,
            ),
        )
    }
}

/** Small rounded status chip ("Needs approval", "Low stock"). */
@Composable
fun Chip(
    text: String,
    color: Color,
    modifier: Modifier = Modifier,
    background: Color = color.copy(alpha = 0.12f),
) {
    Text(
        text = text,
        style = Type.label,
        color = color,
        modifier = modifier
            .background(background, Shapes.pill)
            .padding(horizontal = Space.md, vertical = Space.xs),
    )
}

/** Circular tinted icon well from the stat-card pattern. */
@Composable
fun IconWell(
    icon: ImageVector,
    tint: Color,
    background: Color,
    modifier: Modifier = Modifier,
    size: androidx.compose.ui.unit.Dp = 36.dp,
) {
    Box(
        modifier = modifier.size(size).background(background, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(size / 2))
    }
}

@Composable
fun EmptyMessage(text: String, modifier: Modifier = Modifier) {
    Box(modifier = modifier.fillMaxWidth().padding(Space.xl), contentAlignment = Alignment.Center) {
        Text(text, style = Type.body, color = MekasaTheme.palette.textMuted, textAlign = TextAlign.Center)
    }
}

/** Onboarding footer: progress track plus CTA stack that sticks to the bottom. */
@Composable
fun OnboardingFooter(
    progress: Float,
    content: @Composable ColumnScope.() -> Unit,
) {
    val palette = MekasaTheme.palette
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(palette.surface.copy(alpha = 0.96f))
            .padding(horizontal = Space.lg, vertical = Space.base),
    ) {
        Box(modifier = Modifier.fillMaxWidth().height(4.dp).background(palette.overlay, Shapes.pill)) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(progress.coerceIn(0.04f, 1f))
                    .height(4.dp)
                    .background(palette.accent, Shapes.pill),
            )
        }
        Spacer(Modifier.height(Space.base))
        content()
    }
}
