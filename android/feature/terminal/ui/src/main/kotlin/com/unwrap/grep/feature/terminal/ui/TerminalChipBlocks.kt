package com.unwrap.grep.feature.terminal.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** MOB-002: 자료 번호를 누르면 `고르기 <번호>`, 이미 고른 자료면 `고르기 빼기 <번호>`. */
internal fun pickCommand(number: Int, isPicked: Boolean): String =
    if (isPicked) "고르기 빼기 $number" else "고르기 $number"

/** 새 탭(브라우저)으로 열 주소. http·https만 연다(`javascript:` 같은 주소를 막는다). */
internal fun isWebUrl(url: String): Boolean =
    url.startsWith("https://", ignoreCase = true) || url.startsWith("http://", ignoreCase = true)

private fun toneSymbol(tone: TerminalTone): String = when (tone) {
    TerminalTone.OK -> "✓"
    TerminalTone.WARN -> "!"
    TerminalTone.ERROR -> "✗"
    TerminalTone.MUTED, TerminalTone.INFO -> "·"
}

private fun toneColor(tone: TerminalTone): Color = when (tone) {
    TerminalTone.OK -> PromptColor
    TerminalTone.WARN -> NoticeColor
    TerminalTone.ERROR -> DangerColor
    TerminalTone.MUTED -> InkMutedColor
    TerminalTone.INFO -> CommandColor
}

@Composable
internal fun TerminalPlainLine(line: TerminalEntryUi.PlainLine) {
    Text(
        text = line.text,
        color = if (line.dim) InkMutedColor else InkColor,
        fontFamily = FontFamily.Monospace,
        fontSize = 13.sp,
        lineHeight = 20.sp,
    )
}

@Composable
private fun MonoSpan(text: String, color: Color = InkMutedColor) {
    Text(text = text, color = color, fontFamily = FontFamily.Monospace, fontSize = 13.sp, lineHeight = 20.sp)
}

/** 누르는 명령 칩. 터치 목표 44dp(모바일 시안 규칙 9). */
@Composable
private fun TerminalChip(chip: TerminalChipUi, onClick: (TerminalChipUi) -> Unit) {
    Text(
        text = chip.label,
        color = CommandColor,
        fontFamily = FontFamily.Monospace,
        fontSize = 13.sp,
        fontWeight = FontWeight.Bold,
        textDecoration = TextDecoration.Underline,
        modifier = Modifier
            .heightIn(min = 44.dp)
            .clickable(role = Role.Button) { onClick(chip) }
            .padding(vertical = 12.dp),
    )
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun TerminalChipLine(line: TerminalEntryUi.ChipLine, onChip: (TerminalChipUi) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        line.tone?.let { tone ->
            Text(
                text = toneSymbol(tone),
                color = toneColor(tone),
                fontFamily = FontFamily.Monospace,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.width(20.dp),
            )
        }
        FlowRow(itemVerticalAlignment = Alignment.CenterVertically) {
            if (line.prefix.isNotEmpty()) MonoSpan(line.prefix, if (line.tone != null) InkColor else InkMutedColor)
            line.chips.forEachIndexed { index, chip ->
                if (index > 0) MonoSpan(line.separator)
                TerminalChip(chip, onChip)
            }
            if (line.suffix.isNotEmpty()) MonoSpan(line.suffix)
        }
    }
}

/** ARC-011 규칙 6 자세히 보기. 값이 없는 줄은 디코더가 뺀다. */
@Composable
internal fun ItemDetailBlock(entry: TerminalEntryUi.ItemDetail, onChip: (TerminalChipUi) -> Unit) {
    var expanded by rememberSaveable(entry.number, entry.body) { mutableStateOf(entry.bodyExpandedInitially) }
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TerminalChip(
                chip = TerminalChipUi(
                    label = if (entry.isPicked) "▸${entry.number}" else "${entry.number}",
                    command = pickCommand(entry.number, entry.isPicked),
                ),
                onClick = onChip,
            )
            Text(
                text = "  ${entry.title}",
                color = InkColor,
                fontFamily = FontFamily.Monospace,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
            )
        }
        entry.rows.forEach { row -> DetailRow(row, onChip) }
        if (entry.bodyHead != null && entry.body != null) {
            DetailRow(
                row = TerminalDetailRowUi(
                    label = "본문",
                    value = entry.bodyHead,
                    chips = listOf(TerminalChipUi(if (expanded) "접기" else "펼치기", "")),
                ),
                onChip = { expanded = !expanded },
            )
            if (expanded) BodyPreview(entry.body)
        } else if (entry.noBodyReason != null) {
            TerminalTextLine(TerminalEntryUi.TextLine(TerminalTone.MUTED, "·", "본문 없음: ${entry.noBodyReason}"))
        }
        entry.originalUrl?.let { url ->
            DetailRow(TerminalDetailRowUi(label = "원본", value = "원본 열기", linkUrl = url), onChip)
        }
        TerminalChipLine(TerminalEntryUi.ChipLine(prefix = "→ ", chips = entry.actions), onChip)
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DetailRow(row: TerminalDetailRowUi, onChip: (TerminalChipUi) -> Unit) {
    val uriHandler = LocalUriHandler.current
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = row.label,
            color = InkMutedColor,
            fontFamily = FontFamily.Monospace,
            fontSize = 13.sp,
            modifier = Modifier.width(112.dp),
        )
        FlowRow(modifier = Modifier.weight(1f), itemVerticalAlignment = Alignment.CenterVertically) {
            val valueColor = when {
                row.isWarning -> NoticeColor
                row.isMuted -> InkMutedColor
                else -> InkColor
            }
            val url = row.linkUrl
            when {
                url != null && isWebUrl(url) -> Text(
                    text = row.value,
                    color = CommandColor,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 13.sp,
                    textDecoration = TextDecoration.Underline,
                    modifier = Modifier
                        .heightIn(min = 44.dp)
                        .clickable(role = Role.Button) { uriHandler.openUri(url) }
                        .padding(vertical = 12.dp),
                )
                row.value.isNotEmpty() -> MonoSpan(row.value, valueColor)
            }
            row.chips.forEachIndexed { index, chip ->
                if (index > 0 || row.value.isNotEmpty()) MonoSpan(" ")
                TerminalChip(chip, onChip)
            }
        }
    }
}

@Composable
private fun BodyPreview(text: String) {
    SelectionContainer {
        Text(
            text = text,
            color = InkColor,
            fontFamily = FontFamily.Monospace,
            fontSize = 13.sp,
            lineHeight = 19.sp,
            modifier = Modifier
                .fillMaxWidth()
                .background(SurfaceRaisedColor, RoundedCornerShape(4.dp))
                .padding(10.dp),
        )
    }
}
