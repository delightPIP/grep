package com.unwrap.grep.feature.terminal.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedButton
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
internal fun WelcomeBlock(
    shareGuideDismissed: Boolean,
    onDismissShareGuide: () -> Unit,
    onSubmit: (String) -> Unit,
    onPrefill: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            MoleMascotIdle(size = 44.dp)
            Column {
                Text(
                    text = "그렙 ~ $",
                    color = PromptColor,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 26.sp,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    text = "담기 → 찾기 → 넘기기",
                    color = InkMutedColor,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 13.sp,
                )
            }
        }

        TerminalTextLine(TerminalEntryUi.TextLine(TerminalTone.MUTED, "·", "자료 0건"))
        TerminalTextLine(
            TerminalEntryUi.TextLine(
                TerminalTone.MUTED,
                "·",
                "저장: 다른 앱에서 공유 → 그렙, 또는 링크·글 붙여 넣기",
            ),
        )

        if (!shareGuideDismissed) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(SurfaceRaisedColor, RoundedCornerShape(8.dp))
                    .border(1.dp, LineColor, RoundedCornerShape(8.dp))
                    .padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    text = "공유 시트에 그렙 꺼내 두기 (처음 한 번)",
                    color = InkColor,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    text = "1. 브라우저·메모에서 공유 버튼 누르기\n2. 앱 목록에서 그렙 찾기\n3. 고정해 두면 한 번에 저장",
                    color = InkMutedColor,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 12.sp,
                    lineHeight = 18.sp,
                )
                OutlinedButton(
                    onClick = onDismissShareGuide,
                    shape = RoundedCornerShape(4.dp),
                    border = BorderStroke(1.dp, LineColor),
                    colors = ButtonDefaults.outlinedButtonColors(
                        containerColor = SurfaceColor,
                        contentColor = CommandColor,
                    ),
                    modifier = Modifier.heightIn(min = 44.dp),
                ) {
                    Text(
                        text = "알겠음",
                        fontFamily = FontFamily.Monospace,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
        }

        val quickCommands = listOf(
            Triple("최근", "최근 자료 목록", true),
            Triple("찾기 ", "검색어 치기", false),
            Triple("고르기 ", "번호로 선택", false),
            Triple("넘기기", "AI 도구용 글 복사", true),
            Triple("도움말", "명령 목록", true),
        )
        quickCommands.forEach { (cmd, desc, immediate) ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { if (immediate) onSubmit(cmd) else onPrefill(cmd) }
                    .padding(vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    text = cmd.trim(),
                    color = CommandColor,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.width(68.dp),
                )
                Text(
                    text = desc,
                    color = InkMutedColor,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 13.sp,
                )
            }
        }

        Text(
            text = "→ 아래 버튼을 누르면 실행. _ 붙은 명령은 뒤를 이어 침. 나머지 명령: 더보기",
            color = InkMutedColor,
            fontFamily = FontFamily.Monospace,
            fontSize = 12.sp,
            lineHeight = 18.sp,
        )
    }
}

@Composable
internal fun GuideBlock(
    entry: TerminalEntryUi.Guide,
    onExampleClick: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            text = entry.header,
            color = InkMutedColor,
            fontFamily = FontFamily.Monospace,
            fontSize = 12.sp,
            lineHeight = 18.sp,
        )
        entry.rows.forEach { row ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = row.korean,
                    color = CommandColor,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.width(66.dp),
                )
                Text(
                    text = row.english,
                    color = InkMutedColor,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 12.sp,
                    modifier = Modifier.width(64.dp),
                )
                Text(
                    text = row.description,
                    color = InkColor,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 13.sp,
                    modifier = Modifier.weight(1f),
                )
            }
        }
        Row(
            modifier = Modifier
                .clickable(onClick = onExampleClick)
                .padding(vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = buildAnnotatedString {
                    withStyle(SpanStyle(color = InkMutedColor)) { append("→ 예: ") }
                    withStyle(SpanStyle(color = CommandColor, fontWeight = FontWeight.Bold)) {
                        append(entry.exampleCommand)
                    }
                },
                fontFamily = FontFamily.Monospace,
                fontSize = 13.sp,
            )
        }
    }
}
