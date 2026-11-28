package com.unwrap.grep.feature.terminal.adapter

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
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

/** 터미널 밖(보관함·설정 탭)에서 터미널에 명령을 보내는 통로. `TerminalScreen`이 붙어 있는 동안만 보낸다. */
class TerminalCommandSender {
    internal var submit: ((String) -> Unit)? = null

    fun send(command: String) {
        submit?.invoke(command)
    }
}

/** 화면 핸들에 어댑터를 붙이고, 상태와 콜백을 순수 뷰(`:feature:terminal:ui`)에 넘긴다. */
@Composable
fun TerminalScreen(
    screenId: Long,
    scrollToBottomTrigger: Int = 0,
    onSelectionCountChanged: (Int) -> Unit = {},
    onContextChanged: (itemCount: Int?, pickedNumbers: Set<Int>) -> Unit = { _, _ -> },
    commandSender: TerminalCommandSender? = null,
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
    LaunchedEffect(state.itemCount, state.selection) {
        onContextChanged(state.itemCount, state.selection.map { it.number }.toSet())
    }
    DisposableEffect(commandSender, handle) {
        commandSender?.submit = { handle.submitCommand(it) }
        onDispose { commandSender?.submit = null }
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
