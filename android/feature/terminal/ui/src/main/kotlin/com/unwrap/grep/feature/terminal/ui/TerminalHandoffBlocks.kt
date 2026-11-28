package com.unwrap.grep.feature.terminal.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
internal fun HandedOffBlock(
    entry: TerminalEntryUi.HandedOff,
    onShare: () -> Unit,
) {
    var expanded by rememberSaveable(entry.previewText) { mutableStateOf(false) }

    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        TerminalTextLine(
            TerminalEntryUi.TextLine(
                tone = TerminalTone.OK,
                symbol = "✓",
                emphasis = entry.summaryLine,
            ),
        )
        entry.items.forEach { ref ->
            Text(
                text = "  ${ref.number}  ${ref.title}",
                color = InkColor,
                fontFamily = FontFamily.Monospace,
                fontSize = 13.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        if (entry.missingSummaryCount > 0) {
            TerminalTextLine(
                TerminalEntryUi.TextLine(
                    tone = TerminalTone.WARN,
                    symbol = "!",
                    emphasis = "요약 없음 ${entry.missingSummaryCount}건",
                ),
            )
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = "· 미리보기:",
                color = InkMutedColor,
                fontFamily = FontFamily.Monospace,
                fontSize = 13.sp,
            )
            Text(
                text = if (expanded) "접기" else "펼치기",
                color = CommandColor,
                fontFamily = FontFamily.Monospace,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .clickable { expanded = !expanded }
                    .padding(vertical = 4.dp, horizontal = 4.dp),
            )
        }
        if (expanded) {
            SelectionContainer {
                Text(
                    text = entry.previewText,
                    color = InkColor,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 12.sp,
                    lineHeight = 18.sp,
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(SurfaceRaisedColor, RoundedCornerShape(6.dp))
                        .border(1.dp, LineColor, RoundedCornerShape(6.dp))
                        .padding(12.dp),
                )
            }
        }
        Button(
            onClick = onShare,
            shape = RoundedCornerShape(4.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = PromptColor,
                contentColor = Color(0xFF0B0D10),
            ),
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 44.dp)
                .testTag(TerminalTags.SHARE_BUTTON),
        ) {
            Text(
                text = "다른 앱으로 공유",
                fontFamily = FontFamily.Monospace,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
            )
        }
        TerminalTextLine(
            TerminalEntryUi.TextLine(
                tone = TerminalTone.MUTED,
                symbol = "·",
                emphasis = "클립보드에 있음 → AI 도구 입력창에 붙여 넣기",
            ),
        )
    }
}

@Composable
internal fun HandoffFailedBlock(
    entry: TerminalEntryUi.HandoffFailed,
    onRetry: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        TerminalTextLine(
            TerminalEntryUi.TextLine(
                tone = TerminalTone.ERROR,
                symbol = "✗",
                emphasis = entry.errorLine,
            ),
        )
        if (entry.isClipboardDenied && !entry.previewText.isNullOrEmpty()) {
            SelectionContainer {
                Text(
                    text = entry.previewText,
                    color = InkColor,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 12.sp,
                    lineHeight = 18.sp,
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(SurfaceRaisedColor, RoundedCornerShape(6.dp))
                        .border(1.dp, LineColor, RoundedCornerShape(6.dp))
                        .padding(12.dp),
                )
            }
        }
        val prefix = if (entry.isClipboardDenied) "→ 직접 복사: 길게 눌러 복사 · 다시: " else "→ "
        Row(
            modifier = Modifier
                .clickable(onClick = onRetry)
                .padding(vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = buildAnnotatedString {
                    withStyle(SpanStyle(color = InkMutedColor)) { append(prefix) }
                    withStyle(SpanStyle(color = CommandColor, fontWeight = FontWeight.Bold)) { append("넘기기") }
                },
                fontFamily = FontFamily.Monospace,
                fontSize = 13.sp,
            )
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun HandoffConfirmBlock(
    entry: TerminalEntryUi.HandoffConfirm,
    onChoice: (TerminalChoiceUi) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        TerminalTextLine(
            TerminalEntryUi.TextLine(
                tone = TerminalTone.WARN,
                symbol = "!",
                emphasis = entry.warningLine,
            ),
        )
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            entry.choices.forEach { choice ->
                OutlinedButton(
                    onClick = { onChoice(choice) },
                    shape = RoundedCornerShape(4.dp),
                    border = BorderStroke(1.dp, LineColor),
                    colors = ButtonDefaults.outlinedButtonColors(
                        containerColor = SurfaceRaisedColor,
                        contentColor = CommandColor,
                    ),
                    modifier = Modifier
                        .heightIn(min = 44.dp)
                        .testTag("choice_${choice.command}"),
                ) {
                    Text(
                        text = "${choice.command} · ${choice.label}",
                        fontFamily = FontFamily.Monospace,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
        }
    }
}
