package com.unwrap.grep.feature.terminal.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
internal fun ItemListBlock(
    entry: TerminalEntryUi.ItemList,
    onPick: (Int) -> Unit,
    onMoreRequested: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        if (entry.header != null) {
            Text(
                text = "· ${entry.header}",
                color = InkMutedColor,
                fontFamily = FontFamily.Monospace,
                fontSize = 13.sp,
            )
        }
        entry.items.forEach { item ->
            MobileItemRow(item = item, onClick = { onPick(item.number) })
        }
        if (entry.hasMore) {
            Text(
                text = "→ 더 보기",
                color = CommandColor,
                fontFamily = FontFamily.Monospace,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .clickable(onClick = onMoreRequested)
                    .padding(vertical = 8.dp),
            )
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun MobileItemRow(
    item: TerminalItemRowUi,
    onClick: () -> Unit,
) {
    val backgroundColor = if (item.isPicked) SelectColor else Color.Transparent
    val numberPrefix = if (item.isPicked) "▸${item.number}" else "${item.number}"
    val numberColor = if (item.isPicked) CommandColor else InkMutedColor

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(backgroundColor, RoundedCornerShape(6.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 8.dp, vertical = 8.dp)
            .testTag("itemRow_${item.number}"),
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = numberPrefix,
                color = numberColor,
                fontFamily = FontFamily.Monospace,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = item.title,
                color = InkColor,
                fontFamily = FontFamily.Monospace,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
        }
        if (item.meta.isNotEmpty()) {
            Text(
                text = item.meta,
                color = InkMutedColor,
                fontFamily = FontFamily.Monospace,
                fontSize = 12.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(start = 28.dp),
            )
        }
        if (!item.summary.isNullOrEmpty()) {
            Text(
                text = item.summary,
                color = if (item.summaryIsWarning) NoticeColor else InkMutedColor,
                fontFamily = FontFamily.Monospace,
                fontSize = 13.sp,
                lineHeight = 19.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(start = 28.dp),
            )
        }
        if (item.matchLabel != null || item.tags.isNotEmpty()) {
            FlowRow(
                modifier = Modifier.padding(start = 28.dp, top = 2.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                if (item.matchLabel != null) {
                    Text(
                        text = item.matchLabel,
                        color = NoticeColor,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 11.sp,
                        modifier = Modifier
                            .background(SurfaceRaisedColor, RoundedCornerShape(3.dp))
                            .border(1.dp, LineColor, RoundedCornerShape(3.dp))
                            .padding(horizontal = 6.dp, vertical = 2.dp),
                    )
                }
                item.tags.forEach { tag ->
                    Text(
                        text = "#$tag",
                        color = CommandColor,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 12.sp,
                    )
                }
            }
        }
    }
}

@Composable
internal fun CommandHintLine(
    hint: TerminalEntryUi.CommandHint,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .clickable(onClick = onClick)
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = buildAnnotatedString {
                withStyle(SpanStyle(color = InkMutedColor)) { append(hint.prefix) }
                withStyle(SpanStyle(color = CommandColor, fontWeight = FontWeight.Bold)) { append(hint.command) }
                if (hint.suffix.isNotEmpty()) {
                    withStyle(SpanStyle(color = InkMutedColor)) { append(hint.suffix) }
                }
            },
            fontFamily = FontFamily.Monospace,
            fontSize = 13.sp,
        )
    }
}
