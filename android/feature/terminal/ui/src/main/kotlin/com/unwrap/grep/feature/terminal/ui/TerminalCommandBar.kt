package com.unwrap.grep.feature.terminal.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
internal fun CommandBar(
    input: String,
    expanded: Boolean,
    focusRequester: FocusRequester,
    onToggleExpanded: () -> Unit,
    onInputChange: (String) -> Unit,
    onSubmit: (String) -> Unit,
    onPrefill: (String) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(SurfaceRaisedColor),
    ) {
        HorizontalDivider(thickness = 1.dp, color = LineColor)

        if (expanded) {
            ExpandedCommandGrid(
                onClose = onToggleExpanded,
                onSubmit = onSubmit,
                onPrefill = onPrefill,
            )
        } else {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                CompactCommandChip(label = "최근", onClick = { onSubmit("최근") }, modifier = Modifier.weight(1f))
                CompactCommandChip(label = "찾기 _", onClick = { onPrefill("찾기 ") }, modifier = Modifier.weight(1f))
                CompactCommandChip(label = "고르기 _", onClick = { onPrefill("고르기 ") }, modifier = Modifier.weight(1f))
                CompactCommandChip(
                    label = "더보기",
                    onClick = onToggleExpanded,
                    modifier = Modifier
                        .weight(1f)
                        .testTag(TerminalTags.MORE_COMMANDS_BUTTON),
                )
            }
        }

        HorizontalDivider(thickness = 1.dp, color = LineColor)

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = "그렙 ~ $",
                color = PromptColor,
                fontFamily = FontFamily.Monospace,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .heightIn(min = 44.dp)
                    .background(SurfaceColor, RoundedCornerShape(4.dp))
                    .border(1.dp, LineColor, RoundedCornerShape(4.dp))
                    .padding(horizontal = 10.dp),
                contentAlignment = Alignment.CenterStart,
            ) {
                if (input.isEmpty()) {
                    Text(
                        text = "명령 · 링크",
                        color = InkMutedColor,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 14.sp,
                    )
                }
                BasicTextField(
                    value = input,
                    onValueChange = onInputChange,
                    singleLine = true,
                    textStyle = TextStyle(
                        color = InkColor,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 14.sp,
                    ),
                    cursorBrush = SolidColor(PromptColor),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                    keyboardActions = KeyboardActions(onSend = { onSubmit(input) }),
                    modifier = Modifier
                        .fillMaxWidth()
                        .focusRequester(focusRequester)
                        .testTag(TerminalTags.INPUT_FIELD),
                )
            }
            OutlinedButton(
                onClick = { onSubmit(input) },
                enabled = input.trim().isNotEmpty(),
                shape = RoundedCornerShape(4.dp),
                border = BorderStroke(1.dp, LineColor),
                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 0.dp),
                colors = ButtonDefaults.outlinedButtonColors(
                    containerColor = SurfaceColor,
                    contentColor = PromptColor,
                    disabledContainerColor = SurfaceColor.copy(alpha = 0.5f),
                    disabledContentColor = InkMutedColor,
                ),
                modifier = Modifier
                    .heightIn(min = 44.dp)
                    .testTag(TerminalTags.SUBMIT_BUTTON),
            ) {
                Text(
                    text = "실행",
                    fontFamily = FontFamily.Monospace,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }
}

@Composable
private fun CompactCommandChip(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .heightIn(min = 40.dp)
            .background(SurfaceColor, RoundedCornerShape(4.dp))
            .border(1.dp, LineColor, RoundedCornerShape(4.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 6.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = CommandColor,
            fontFamily = FontFamily.Monospace,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
        )
    }
}

@Composable
private fun ExpandedCommandGrid(
    onClose: () -> Unit,
    onSubmit: (String) -> Unit,
    onPrefill: (String) -> Unit,
) {
    val cells = listOf(
        Triple("최근", "바로 실행") { onSubmit("최근") },
        Triple("찾기 _", "검색어 치기") { onPrefill("찾기 ") },
        Triple("고르기 _", "번호 치기") { onPrefill("고르기 ") },
        Triple("담기 _", "링크·글 저장") { onPrefill("담기 ") },
        Triple("도움말", "바로 실행") { onSubmit("도움말") },
        Triple("로그아웃", "세션 종료") { onSubmit("로그아웃") },
    )
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = "명령 전체 · _ 는 이어 치기",
                color = InkMutedColor,
                fontFamily = FontFamily.Monospace,
                fontSize = 12.sp,
            )
            Text(
                text = "닫기",
                color = CommandColor,
                fontFamily = FontFamily.Monospace,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .clickable(onClick = onClose)
                    .padding(horizontal = 6.dp, vertical = 4.dp),
            )
        }
        cells.chunked(3).forEach { rowCells ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                rowCells.forEach { (title, subtitle, action) ->
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .heightIn(min = 48.dp)
                            .background(SurfaceColor, RoundedCornerShape(4.dp))
                            .border(1.dp, LineColor, RoundedCornerShape(4.dp))
                            .clickable(onClick = action)
                            .padding(horizontal = 8.dp, vertical = 6.dp),
                        verticalArrangement = Arrangement.Center,
                    ) {
                        Text(
                            text = title,
                            color = CommandColor,
                            fontFamily = FontFamily.Monospace,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                        )
                        Text(
                            text = subtitle,
                            color = InkMutedColor,
                            fontFamily = FontFamily.Monospace,
                            fontSize = 10.sp,
                            maxLines = 1,
                        )
                    }
                }
            }
        }
    }
}
