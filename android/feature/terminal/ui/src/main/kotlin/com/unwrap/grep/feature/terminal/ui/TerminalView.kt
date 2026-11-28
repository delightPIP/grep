package com.unwrap.grep.feature.terminal.ui

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp

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
