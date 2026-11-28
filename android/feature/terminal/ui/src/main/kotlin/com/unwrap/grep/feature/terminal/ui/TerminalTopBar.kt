package com.unwrap.grep.feature.terminal.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
internal fun TerminalTopBar(
    windowTitle: String,
    statusText: String,
    isOffline: Boolean,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(SurfaceRaisedColor)
            .statusBarsPadding()
            .testTag(TerminalTags.TOP_BAR),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = buildAnnotatedString {
                    withStyle(SpanStyle(color = PromptColor, fontWeight = FontWeight.Bold)) {
                        append("그렙")
                    }
                    withStyle(SpanStyle(color = InkColor, fontWeight = FontWeight.Bold)) {
                        append(" — $windowTitle")
                    }
                },
                fontFamily = FontFamily.Monospace,
                fontSize = 14.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f, fill = false),
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = statusText,
                color = if (isOffline) NoticeColor else InkMutedColor,
                fontFamily = FontFamily.Monospace,
                fontSize = 12.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.testTag(TerminalTags.STATUS_TEXT),
            )
        }
        HorizontalDivider(thickness = 1.dp, color = LineColor)
    }
}
