package com.unwrap.grep.feature.terminal.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
internal fun TerminalBlockItem(
    block: TerminalBlockUi,
    shareGuideDismissed: Boolean,
    onDismissShareGuide: () -> Unit,
    onSubmit: (String) -> Unit,
    onPrefill: (String) -> Unit,
    onMoreRequested: () -> Unit,
    onShare: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        if (block.prompt != null) {
            Text(
                text = buildAnnotatedString {
                    withStyle(
                        SpanStyle(
                            color = if (block.failed) DangerColor else PromptColor,
                            fontWeight = FontWeight.Bold,
                        ),
                    ) {
                        append("그렙 ~ $ ")
                    }
                    withStyle(SpanStyle(color = InkColor)) {
                        append(block.prompt)
                    }
                },
                fontFamily = FontFamily.Monospace,
                fontSize = 14.sp,
                lineHeight = 20.sp,
            )
        }

        block.entries.forEach { entry ->
            when (entry) {
                is TerminalEntryUi.TextLine -> TerminalTextLine(entry)
                is TerminalEntryUi.ItemList -> ItemListBlock(
                    entry = entry,
                    onPick = { number -> onSubmit(pickCommand(number, entry.items.any { it.number == number && it.isPicked })) },
                    onMoreRequested = onMoreRequested,
                )
                is TerminalEntryUi.ItemRow -> MobileItemRow(
                    item = entry.item,
                    onClick = { onSubmit(pickCommand(entry.item.number, entry.item.isPicked)) },
                )
                is TerminalEntryUi.CommandHint -> CommandHintLine(
                    hint = entry,
                    onClick = {
                        if (entry.submitImmediately) {
                            onSubmit(entry.command)
                        } else {
                            onPrefill(entry.command)
                        }
                    },
                )
                is TerminalEntryUi.HandedOff -> HandedOffBlock(
                    entry = entry,
                    onShare = { onShare(entry.previewText) },
                )
                is TerminalEntryUi.HandoffFailed -> HandoffFailedBlock(
                    entry = entry,
                    onRetry = { onSubmit("넘기기") },
                )
                is TerminalEntryUi.HandoffConfirm -> HandoffConfirmBlock(
                    entry = entry,
                    onChoice = { onSubmit(it.command) },
                )
                TerminalEntryUi.Welcome -> WelcomeBlock(
                    shareGuideDismissed = shareGuideDismissed,
                    onDismissShareGuide = onDismissShareGuide,
                    onSubmit = onSubmit,
                    onPrefill = onPrefill,
                )
                is TerminalEntryUi.PlainLine -> TerminalPlainLine(entry)
                is TerminalEntryUi.ChipLine -> TerminalChipLine(
                    line = entry,
                    onChip = { chip -> if (chip.submitsImmediately) onSubmit(chip.command) else onPrefill(chip.command) },
                )
                is TerminalEntryUi.ItemDetail -> ItemDetailBlock(
                    entry = entry,
                    onChip = { chip -> if (chip.submitsImmediately) onSubmit(chip.command) else onPrefill(chip.command) },
                )
                is TerminalEntryUi.Guide -> GuideBlock(
                    entry = entry,
                    onExampleClick = { onPrefill(entry.exampleCommand) },
                )
            }
        }
    }
}

@Composable
internal fun TerminalTextLine(line: TerminalEntryUi.TextLine) {
    val toneColor = when (line.tone) {
        TerminalTone.OK -> PromptColor
        TerminalTone.WARN -> NoticeColor
        TerminalTone.ERROR -> DangerColor
        TerminalTone.MUTED -> InkMutedColor
        TerminalTone.INFO -> CommandColor
    }
    val emphasisColor = when (line.tone) {
        TerminalTone.OK -> InkColor
        TerminalTone.WARN -> NoticeColor
        TerminalTone.ERROR -> DangerColor
        TerminalTone.MUTED -> InkMutedColor
        TerminalTone.INFO -> InkColor
    }
    Row(verticalAlignment = Alignment.Top) {
        Text(
            text = line.symbol,
            color = toneColor,
            fontFamily = FontFamily.Monospace,
            fontSize = 14.sp,
            lineHeight = 20.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.width(20.dp),
        )
        Text(
            text = buildAnnotatedString {
                withStyle(
                    SpanStyle(
                        color = emphasisColor,
                        fontWeight = if (line.tone == TerminalTone.MUTED) FontWeight.Normal else FontWeight.Bold,
                    ),
                ) {
                    append(line.emphasis)
                }
                if (line.tail.isNotEmpty()) {
                    withStyle(SpanStyle(color = if (line.tone == TerminalTone.MUTED) InkMutedColor else InkColor)) {
                        append(line.tail)
                    }
                }
            },
            fontFamily = FontFamily.Monospace,
            fontSize = 14.sp,
            lineHeight = 20.sp,
        )
    }
}
