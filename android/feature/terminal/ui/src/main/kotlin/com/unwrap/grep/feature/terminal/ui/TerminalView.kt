package com.unwrap.grep.feature.terminal.ui

import android.content.Intent
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

object TerminalTags {
    const val TOP_BAR = "terminalTopBar"
    const val STATUS_TEXT = "terminalStatusText"
    const val INPUT_FIELD = "terminalInputField"
    const val SUBMIT_BUTTON = "terminalSubmitButton"
    const val SELECTION_BAR = "terminalSelectionBar"
    const val HANDOFF_BUTTON = "terminalHandoffButton"
    const val MORE_COMMANDS_BUTTON = "terminalMoreCommandsButton"
    const val SHARE_BUTTON = "terminalShareButton"
}

// grep-design/mockups/project/ds/grep/tokens.json (dark)
internal val SurfaceColor = Color(0xFF14171C)
internal val SurfaceRaisedColor = Color(0xFF1C2027)
internal val LineColor = Color(0xFF2E343D)
internal val InkColor = Color(0xFFE7E9EC)
internal val InkMutedColor = Color(0xFF99A2AD)
internal val PromptColor = Color(0xFF7FE0A3)
internal val CommandColor = Color(0xFF86C8FF)
internal val NoticeColor = Color(0xFFF2C86B)
internal val DangerColor = Color(0xFFFF8F86)
internal val SelectColor = Color(0xFF1F3A52)

private val MolePalette = mapOf(
    'M' to Color(0xFF4A4460),
    'R' to Color(0xFF6A4228),
    'h' to Color(0xFFF5C9A3),
    'm' to Color(0xFF6C6585),
    'o' to Color(0xFF16120F),
    'q' to Color(0xFF99A2AD),
    'r' to Color(0xFF8A5A3A),
    's' to Color(0xFFF2A0A8),
    'w' to Color(0xFFFBFBF8),
    'y' to Color(0xFFF2C86B),
)

private val MoleIdleRows = listOf(
    "................",
    "................",
    ".....oooooo.....",
    "....ommmmmmo....",
    "...ommmmmmmmo...",
    "...omommmmomo...",
    "..ommomssmommo..",
    "..ommmssssmmmo..",
    "..ohhmmmmmmhho..",
    ".ohhhmmMMmmhhho.",
    ".ommmmMMMMmmmmo.",
    "..ommmmmmmmmmo..",
    ".rrommmmmmmmorr.",
    "rrrRrrrrrrRrrrrr",
    ".rrrrrRrrrrrrrr.",
    "................",
)

/**
 * 모바일 터미널 화면 순수 뷰(시안: M1~M5, 정책: COM-001~010, MOB-002).
 * 결과 행이나 확인 낱말 버튼을 누르면 바로 실행하고, 인자가 필요한 명령 칩은 입력줄에 채운다.
 */
@Composable
fun TerminalView(
    state: TerminalUiState,
    onInputChange: (String) -> Unit,
    onSubmit: (String) -> Unit,
    onPaste: (String) -> Unit,
    onMoreRequested: () -> Unit,
    scrollToBottomTrigger: Int = 0,
    modifier: Modifier = Modifier,
) {
    val listState = rememberLazyListState()
    val focusRequester = remember { FocusRequester() }
    var expandedCommandGrid by rememberSaveable { mutableStateOf(false) }
    var shareGuideDismissed by rememberSaveable { mutableStateOf(false) }
    val context = LocalContext.current

    val focusWithInput: (String) -> Unit = { text ->
        onInputChange(text)
        runCatching { focusRequester.requestFocus() }
    }

    val shareText: (String) -> Unit = { payload ->
        val sendIntent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, payload)
        }
        val chooser = Intent.createChooser(sendIntent, "다른 앱으로 공유")
        runCatching { context.startActivity(chooser) }
    }

    LaunchedEffect(state.blocks.size, scrollToBottomTrigger) {
        if (state.blocks.isNotEmpty()) {
            listState.animateScrollToItem(state.blocks.lastIndex)
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(SurfaceColor)
            .imePadding(),
    ) {
        // MTopBar
        TerminalTopBar(
            windowTitle = state.windowTitle,
            statusText = state.statusText,
            isOffline = state.isOffline,
        )

        // 출력 기록 영역
        LazyColumn(
            state = listState,
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            if (state.blocks.isEmpty()) {
                item(key = "empty_welcome") {
                    WelcomeBlock(
                        shareGuideDismissed = shareGuideDismissed,
                        onDismissShareGuide = { shareGuideDismissed = true },
                        onSubmit = onSubmit,
                        onPrefill = focusWithInput,
                    )
                }
            } else {
                items(state.blocks, key = { it.id }) { block ->
                    TerminalBlockItem(
                        block = block,
                        shareGuideDismissed = shareGuideDismissed,
                        onDismissShareGuide = { shareGuideDismissed = true },
                        onSubmit = onSubmit,
                        onPrefill = focusWithInput,
                        onMoreRequested = onMoreRequested,
                        onShare = shareText,
                    )
                }
            }
        }

        // 선택 줄(MPickBar, MOB-001 규칙 4: 선택 중에는 하단 탭바 대신 이 줄이 보인다)
        if (state.selection.isNotEmpty()) {
            SelectionBar(
                selection = state.selection,
                onHandoff = { onSubmit("넘기기") },
            )
        }

        // 명령 버튼 줄 + 확장 그리드 + 입력줄
        CommandBar(
            input = state.input,
            expanded = expandedCommandGrid,
            focusRequester = focusRequester,
            onToggleExpanded = { expandedCommandGrid = !expandedCommandGrid },
            onInputChange = { next ->
                val trimmed = next.trim()
                val looksLikePastedLink = state.input.isEmpty() &&
                    trimmed.length > 10 &&
                    (trimmed.startsWith("http://") || trimmed.startsWith("https://"))
                if (looksLikePastedLink) {
                    onPaste(trimmed)
                } else {
                    onInputChange(next)
                }
            },
            onSubmit = { raw ->
                val trimmed = raw.trim()
                if (trimmed.isNotEmpty()) {
                    expandedCommandGrid = false
                    onSubmit(trimmed)
                }
            },
            onPrefill = { prefix ->
                expandedCommandGrid = false
                focusWithInput(prefix)
            },
        )
    }
}

@Composable
private fun TerminalTopBar(
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

@Composable
private fun TerminalBlockItem(
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

@Composable
private fun ItemListBlock(
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
private fun MobileItemRow(
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
private fun CommandHintLine(
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

@Composable
private fun HandedOffBlock(
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
private fun HandoffFailedBlock(
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
private fun HandoffConfirmBlock(
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

@Composable
private fun WelcomeBlock(
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
private fun GuideBlock(
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

@Composable
private fun SelectionBar(
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

@Composable
private fun CommandBar(
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

@Composable
private fun MoleMascotIdle(size: Dp, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(size)) {
        val cell = this.size.width / 16f
        MoleIdleRows.forEachIndexed { y, row ->
            row.forEachIndexed { x, ch ->
                val color = MolePalette[ch] ?: return@forEachIndexed
                drawRect(
                    color = color,
                    topLeft = Offset(x * cell, y * cell),
                    size = Size(cell, cell),
                )
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun TerminalViewWelcomePreview() {
    TerminalView(
        state = TerminalUiState(
            windowTitle = "처음",
            statusText = "자료 0 · 선택 0",
            blocks = listOf(TerminalBlockUi(id = "0", prompt = null, failed = false, entries = listOf(TerminalEntryUi.Welcome))),
        ),
        onInputChange = {},
        onSubmit = {},
        onPaste = {},
        onMoreRequested = {},
    )
}
