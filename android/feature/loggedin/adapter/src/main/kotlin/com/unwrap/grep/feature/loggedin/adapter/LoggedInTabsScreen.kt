package com.unwrap.grep.feature.loggedin.adapter

import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.unwrap.grep.core.rememberAttachedHandle
import com.unwrap.grep.feature.loggedin.ui.ArchiveView
import com.unwrap.grep.feature.loggedin.ui.LoggedInTab
import com.unwrap.grep.feature.loggedin.ui.LoggedInTabContainer
import com.unwrap.grep.feature.loggedin.ui.SettingsView
import com.unwrap.grep.swiftbridge.ArchiveLoaderHandle

/** Swift `ArchiveLoaderHandle`을 화면 수명 동안 쥐고 보관함 로더로 감싼다. */
@Composable
fun rememberSwiftArchiveItemLoader(): ArchiveItemLoader {
    val handle = rememberAttachedHandle(
        create = { ArchiveLoaderHandle.init(it) },
        attach = {},
        detach = {},
    )
    return remember(handle) { SwiftArchiveItemLoader(handle) }
}

/**
 * 하단 탭 컨테이너에 터미널·보관함·설정 화면을 엮는다(MOB-001).
 * 보관함 보던 위치와 설정 스크롤은 탭을 옮겨도 남도록 여기서 쥔다(규칙 6).
 */
@Composable
fun LoggedInTabsScreen(
    model: LoggedInTabsModel,
    modifier: Modifier = Modifier,
    terminalContent: @Composable (scrollToBottomTrigger: Int) -> Unit,
) {
    var isSettingsModalPresented by remember { mutableStateOf(false) }
    val archiveListState = rememberLazyListState()
    val settingsScrollState = rememberScrollState()

    LaunchedEffect(model) {
        if (model.selectedTab == LoggedInTab.ARCHIVE) model.loadArchiveIfNeeded()
    }

    LoggedInTabContainer(
        selectedTab = model.selectedTab,
        onSelectTab = model::select,
        isSelecting = model.archivePresentation.pickedCount > 0,
        isModalPresented = isSettingsModalPresented,
        onReselect = model::reselect,
        modifier = modifier,
        terminalContent = { terminalContent(model.terminalScrollToBottomTrigger) },
        archiveContent = {
            ArchiveView(
                presentation = model.archivePresentation,
                onRefresh = model::refreshArchive,
                onLoadMore = model::loadMoreArchive,
                scrollToTopTrigger = model.archiveScrollToTopTrigger,
                onTogglePick = model::togglePick,
                onMovePickedToTerminal = model::moveToTerminalForHandoff,
                onClearPicked = model::clearPicked,
                listState = archiveListState,
            )
        },
        settingsContent = {
            SettingsView(
                presentation = model.settingsPresentation,
                onSignOut = model::requestSignOut,
                resetToRootTrigger = model.settingsResetToRootTrigger,
                onModalVisibilityChange = { isSettingsModalPresented = it },
                scrollState = settingsScrollState,
            )
        },
    )
}
