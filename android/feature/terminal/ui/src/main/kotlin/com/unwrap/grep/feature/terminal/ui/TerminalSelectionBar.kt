package com.unwrap.grep.feature.terminal.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
internal fun SelectionBar(
    selection: List<TerminalItemRefUi>,
    onHandoff: () -> Unit,
) {
    val summary = selection.joinToString(" · ") { "${it.number} ${it.title}" }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(SurfaceRaisedColor)
            .testTag(TerminalTags.SELECTION_BAR),
    ) {
        HorizontalDivider(thickness = 1.dp, color = LineColor)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = buildAnnotatedString {
                    withStyle(SpanStyle(color = CommandColor, fontWeight = FontWeight.Bold)) {
                        append("선택 ${selection.size}  ")
                    }
                    withStyle(SpanStyle(color = InkMutedColor)) {
                        append(summary)
                    }
                },
                fontFamily = FontFamily.Monospace,
                fontSize = 13.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Button(
                onClick = onHandoff,
                shape = RoundedCornerShape(4.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = PromptColor,
                    contentColor = Color(0xFF0B0D10),
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 44.dp)
                    .testTag(TerminalTags.HANDOFF_BUTTON),
            ) {
                Text(
                    text = "넘기기 ${selection.size}건",
                    fontFamily = FontFamily.Monospace,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }
}
