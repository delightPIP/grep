package com.unwrap.grep.feature.loggedin.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// 공용 모바일 부품(MTopBar · UiButton · UiSettingRow · MPickBar · MSheet). iOS `LoggedInComponents.swift`와 같은 값이다.

internal enum class GrepButtonKind { PRIMARY, SECONDARY, DANGER, GHOST, QUIET }

internal enum class GrepButtonSize(val minHeight: Dp, val horizontalPadding: Dp) {
    SM(36.dp, 12.dp),
    MD(44.dp, 16.dp),
    LG(48.dp, 16.dp),
}

private val ButtonShape = RoundedCornerShape(3.dp)
private const val DISABLED_ALPHA = 0.45f

/** 시안 `UiButton.dc.html`. */
@Composable
internal fun GrepUiButton(
    label: String,
    modifier: Modifier = Modifier,
    kind: GrepButtonKind = GrepButtonKind.SECONDARY,
    size: GrepButtonSize = GrepButtonSize.MD,
    fullWidth: Boolean = false,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    val foreground = when (kind) {
        GrepButtonKind.PRIMARY -> LoggedInPalette.Surface
        GrepButtonKind.SECONDARY, GrepButtonKind.GHOST -> LoggedInPalette.Command
        GrepButtonKind.DANGER -> LoggedInPalette.Danger
        GrepButtonKind.QUIET -> LoggedInPalette.Ink
    }
    val background = when (kind) {
        GrepButtonKind.PRIMARY -> LoggedInPalette.Prompt
        GrepButtonKind.SECONDARY, GrepButtonKind.DANGER -> LoggedInPalette.Surface
        GrepButtonKind.GHOST -> Color.Transparent
        GrepButtonKind.QUIET -> LoggedInPalette.SurfaceRaised
    }
    val border = when (kind) {
        GrepButtonKind.PRIMARY -> LoggedInPalette.Prompt
        GrepButtonKind.GHOST -> Color.Transparent
        else -> LoggedInPalette.Line
    }
    Box(
        modifier = modifier
            .then(if (fullWidth) Modifier.fillMaxWidth() else Modifier)
            .heightIn(min = size.minHeight)
            .clip(ButtonShape)
            .background(background)
            .border(1.dp, border, ButtonShape)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .alpha(if (enabled) 1f else DISABLED_ALPHA)
            .padding(horizontal = size.horizontalPadding),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = foreground,
            fontFamily = FontFamily.Monospace,
            fontSize = 14.sp,
            fontWeight = if (kind == GrepButtonKind.QUIET) FontWeight.Normal else FontWeight.Bold,
            maxLines = 1,
        )
    }
}

/** 시안 `MTopBar.dc.html`. `plain`이 아니면 `그렙 — 제목`으로 쓴다. */
@Composable
internal fun GrepTopBar(
    title: String,
    status: String = "",
    plain: Boolean = false,
    statusTestTag: String? = null,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(LoggedInPalette.SurfaceRaised)
            .statusBarsPadding(),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (!plain) {
                MonoText("그렙", LoggedInPalette.Prompt, bold = true)
                Spacer(Modifier.width(4.dp))
                MonoText("— $title", LoggedInPalette.Ink, bold = true)
            } else {
                MonoText(title, LoggedInPalette.Ink, bold = true)
            }
            Spacer(Modifier.weight(1f))
            if (status.isNotEmpty()) {
                MonoText(
                    text = status,
                    color = LoggedInPalette.InkMuted,
                    size = 12,
                    modifier = if (statusTestTag != null) Modifier.testTag(statusTestTag) else Modifier,
                )
            }
        }
        HorizontalDivider(thickness = 1.dp, color = LoggedInPalette.Line)
    }
}

/** 시안 `UiSettingRow.dc.html`. 동작 버튼은 `onAction`이 없거나 `actionEnabled`가 거짓이면 흐리게 막는다. */
@Composable
internal fun GrepSettingRow(
    label: String,
    sub: String,
    actionLabel: String? = null,
    actionKind: GrepButtonKind = GrepButtonKind.SECONDARY,
    actionEnabled: Boolean = true,
    actionTestTag: String? = null,
    onAction: (() -> Unit)? = null,
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 56.dp)
                .padding(vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                MonoText(label, LoggedInPalette.Ink)
                if (sub.isNotEmpty()) {
                    MonoText(sub, LoggedInPalette.InkMuted, size = 12, singleLine = false)
                }
            }
            if (!actionLabel.isNullOrEmpty()) {
                Spacer(Modifier.width(12.dp))
                GrepUiButton(
                    label = actionLabel,
                    kind = actionKind,
                    size = GrepButtonSize.SM,
                    enabled = actionEnabled && onAction != null,
                    modifier = if (actionTestTag != null) Modifier.testTag(actionTestTag) else Modifier,
                    onClick = { onAction?.invoke() },
                )
            }
        }
        HorizontalDivider(thickness = 1.dp, color = LoggedInPalette.Line)
    }
}

/** 시안 `MPickBar.dc.html`(summary 모드). */
@Composable
internal fun GrepPickBar(
    count: Int,
    summary: String,
    onMoveToTerminal: () -> Unit,
    onClear: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(LoggedInPalette.SurfaceRaised)
            .navigationBarsPadding()
            .testTag("archivePickBar"),
    ) {
        HorizontalDivider(thickness = 1.dp, color = LoggedInPalette.Line)
        Column(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                MonoText("선택 $count", LoggedInPalette.Command, size = 13, bold = true)
                MonoText(summary, LoggedInPalette.InkMuted, size = 13)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                GrepUiButton(
                    label = "터미널에서 넘기기",
                    kind = GrepButtonKind.PRIMARY,
                    fullWidth = true,
                    modifier = Modifier.weight(1f).testTag("pickBarHandoffButton"),
                    onClick = onMoveToTerminal,
                )
                GrepUiButton(
                    label = "해제",
                    modifier = Modifier.testTag("pickBarClearButton"),
                    onClick = onClear,
                )
            }
        }
    }
}

/** 시안 `MSheet.dc.html`. 바깥을 누르면 취소한다. */
@Composable
internal fun GrepBottomSheet(
    title: String,
    lines: List<String>,
    primaryLabel: String,
    primaryKind: GrepButtonKind,
    cancelLabel: String,
    onPrimary: () -> Unit,
    onCancel: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.55f))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onCancel,
            )
            .semantics { contentDescription = "시트 닫기" }
            .testTag("confirmBottomSheet"),
        contentAlignment = Alignment.BottomCenter,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(topStart = 8.dp, topEnd = 8.dp))
                .background(LoggedInPalette.Surface)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = {},
                )
                .navigationBarsPadding()
                .padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 20.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Box(
                modifier = Modifier
                    .align(Alignment.CenterHorizontally)
                    .size(width = 36.dp, height = 4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(LoggedInPalette.Line),
            )
            MonoText(title, LoggedInPalette.Ink, size = 16, bold = true)
            lines.forEach { line ->
                Text(text = line, color = LoggedInPalette.InkMuted, fontSize = 14.sp)
            }
            Row(
                modifier = Modifier.padding(top = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                GrepUiButton(
                    label = primaryLabel,
                    kind = primaryKind,
                    size = GrepButtonSize.LG,
                    modifier = Modifier.weight(1f).testTag("sheetPrimaryButton"),
                    fullWidth = true,
                    onClick = onPrimary,
                )
                GrepUiButton(
                    label = cancelLabel,
                    size = GrepButtonSize.LG,
                    modifier = Modifier.weight(1f).testTag("sheetCancelButton"),
                    fullWidth = true,
                    onClick = onCancel,
                )
            }
        }
    }
}

@Composable
internal fun MonoText(
    text: String,
    color: Color,
    modifier: Modifier = Modifier,
    size: Int = 14,
    bold: Boolean = false,
    singleLine: Boolean = true,
) {
    Text(
        text = text,
        color = color,
        fontFamily = FontFamily.Monospace,
        fontSize = size.sp,
        fontWeight = if (bold) FontWeight.Bold else FontWeight.Normal,
        maxLines = if (singleLine) 1 else Int.MAX_VALUE,
        overflow = if (singleLine) TextOverflow.Ellipsis else TextOverflow.Clip,
        modifier = modifier,
    )
}
