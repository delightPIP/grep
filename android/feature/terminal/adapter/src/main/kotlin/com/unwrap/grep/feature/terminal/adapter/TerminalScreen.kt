package com.unwrap.grep.feature.terminal.adapter

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.unwrap.grep.core.rememberAttachedHandle
import com.unwrap.grep.feature.terminal.ui.TerminalUiState
import com.unwrap.grep.feature.terminal.ui.TerminalView
import com.unwrap.grep.swiftbridge.TerminalScreenHandle
import com.unwrap.grep.swiftbridge.TerminalViewBridge

/** Swift `TerminalAndroidViewFactory.kind`와 같은 문자열. */
const val TERMINAL_KIND = "terminal"

private class TerminalAdapter : TerminalViewBridge {
    var uiState: TerminalUiState by mutableStateOf(TerminalUiState())
        private set

    override fun render(stateJson: String) {
        uiState = decodeTerminalState(stateJson)
    }
}

/** 화면 핸들에 어댑터를 붙이고, 상태와 콜백을 순수 뷰(`:feature:terminal:ui`)에 넘긴다. */
@Composable
fun TerminalScreen(
    screenId: Long,
    scrollToBottomTrigger: Int = 0,
    onSelectionCountChanged: (Int) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val adapter = remember { TerminalAdapter() }
    val handle = rememberAttachedHandle(
        create = { TerminalScreenHandle.init(screenId, it) },
        attach = { it.attach(adapter) },
        detach = { it.detach() },
    )
    val state = adapter.uiState

    LaunchedEffect(state.selection.size) {
        onSelectionCountChanged(state.selection.size)
    }

    TerminalView(
        state = state,
        onInputChange = { handle.inputChanged(it) },
        onSubmit = { handle.submitCommand(it) },
        onPaste = { handle.pasteText(it) },
        onMoreRequested = { handle.requestMore() },
        scrollToBottomTrigger = scrollToBottomTrigger,
        modifier = modifier,
    )
}
