package com.unwrap.grep.feature.loggedin.adapter

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.unwrap.grep.feature.loggedin.ui.ArchiveItemRow
import com.unwrap.grep.feature.loggedin.ui.ArchivePresentation
import com.unwrap.grep.feature.loggedin.ui.LoggedInTab
import com.unwrap.grep.feature.loggedin.ui.SettingsPresentation

/**
 * 하단 탭 3개(터미널·보관함·설정)의 상태와 보관함 로드·설정 로그아웃을 관리한다(MOB-001). iOS `LoggedInTabsModel`(#91)과 같은 규칙이다.
 * 선택은 터미널 코어가 갖고(MOB-001 규칙 7), 보관함 체크·해제·로그아웃은 터미널 명령으로 보낸다.
 */
class LoggedInTabsModel(
    private val archiveLoader: ArchiveItemLoader,
    private val sendCommand: (String) -> Unit,
    initialTab: LoggedInTab = LoggedInTab.TERMINAL,
    private val pageLimit: Int = DEFAULT_PAGE_LIMIT,
    private val onSessionExpired: () -> Unit = {},
) {
    /** MOB-001 규칙 3: 앱을 열면 늘 터미널 탭에서 시작한다. */
    var selectedTab by mutableStateOf(initialTab)
        private set
    var archivePresentation by mutableStateOf(ArchivePresentation())
        private set
    var settingsPresentation by mutableStateOf(SettingsPresentation())
        private set
    var terminalScrollToBottomTrigger by mutableIntStateOf(0)
        private set
    var archiveScrollToTopTrigger by mutableIntStateOf(0)
        private set
    var settingsResetToRootTrigger by mutableIntStateOf(0)
        private set

    private var rows: List<ArchiveItemRow> = emptyList()
    private var nextCursor: String? = null
    private var hasLoadedArchive = false
    private var itemCount: Int? = null
    private var pickedNumbers: Set<Int> = emptySet()

    fun select(tab: LoggedInTab) {
        selectedTab = tab
        if (tab == LoggedInTab.ARCHIVE) loadArchiveIfNeeded()
    }

    /** MOB-001 규칙 8: 보고 있는 탭을 다시 누르면 각 탭의 시작 위치로 돌아간다. */
    fun reselect(tab: LoggedInTab) {
        when (tab) {
            LoggedInTab.TERMINAL -> terminalScrollToBottomTrigger += 1
            LoggedInTab.ARCHIVE -> archiveScrollToTopTrigger += 1
            LoggedInTab.SETTINGS -> settingsResetToRootTrigger += 1
        }
    }

    /** 터미널 상태(자료 수, 선택)가 바뀌면 보관함 머리 줄과 체크 칸을 맞춘다. */
    fun updateTerminalContext(itemCount: Int?, pickedNumbers: Set<Int>) {
        if (this.itemCount == itemCount && this.pickedNumbers == pickedNumbers) return
        this.itemCount = itemCount
        this.pickedNumbers = pickedNumbers
        rebuildArchive()
    }

    fun loadArchiveIfNeeded() {
        if (!hasLoadedArchive) refreshArchive()
    }

    fun refreshArchive() {
        if (archivePresentation.isLoading) return
        archivePresentation = archivePresentation.copy(isLoading = true, errorMessage = null)
        archiveLoader.loadPage(pageLimit, null) { outcome ->
            archivePresentation = archivePresentation.copy(isLoading = false)
            when (outcome) {
                is ArchivePageOutcome.Page -> {
                    hasLoadedArchive = true
                    rows = outcome.rows
                    nextCursor = outcome.nextCursor
                    rebuildArchive()
                }
                else -> handleFailure(outcome)
            }
        }
    }

    fun loadMoreArchive() {
        val cursor = nextCursor ?: return
        if (archivePresentation.isLoading || archivePresentation.isLoadingMore) return
        archivePresentation = archivePresentation.copy(isLoadingMore = true, errorMessage = null)
        archiveLoader.loadPage(pageLimit, cursor) { outcome ->
            archivePresentation = archivePresentation.copy(isLoadingMore = false)
            when (outcome) {
                is ArchivePageOutcome.Page -> {
                    val existing = rows.map { it.number }.toSet()
                    rows = rows + outcome.rows.filterNot { it.number in existing }
                    nextCursor = outcome.nextCursor
                    rebuildArchive()
                }
                else -> handleFailure(outcome)
            }
        }
    }

    fun togglePick(number: Int) {
        sendCommand(if (number in pickedNumbers) "고르기 빼기 $number" else "고르기 $number")
    }

    fun clearPicked() {
        sendCommand(CLEAR_PICKED_COMMAND)
    }

    /** MOB-001 규칙 7: 보관함에서 고른 자료를 터미널에서 넘긴다. */
    fun moveToTerminalForHandoff() {
        selectedTab = LoggedInTab.TERMINAL
    }

    fun requestSignOut() {
        if (settingsPresentation.isSigningOut) return
        settingsPresentation = settingsPresentation.copy(isSigningOut = true)
        sendCommand(SIGN_OUT_COMMAND)
    }

    private fun handleFailure(outcome: ArchivePageOutcome) {
        when (outcome) {
            is ArchivePageOutcome.Failed -> {
                archivePresentation = archivePresentation.copy(errorMessage = outcome.message)
                rebuildArchive()
            }
            ArchivePageOutcome.SessionExpired -> onSessionExpired()
            ArchivePageOutcome.Cancelled, is ArchivePageOutcome.Page -> Unit
        }
    }

    private fun rebuildArchive() {
        val shown = rows.map { it.copy(isPicked = it.number in pickedNumbers) }
        val pickedSummary = shown.filter { it.isPicked }.joinToString(" · ") { "${it.number} ${it.title}" }
        val count = itemCount
        val statusText = when {
            count != null -> "자료 $count"
            hasLoadedArchive -> if (nextCursor == null) "자료 ${shown.size}" else "자료 ${shown.size}+"
            else -> "자료"
        }
        archivePresentation = archivePresentation.copy(
            statusText = statusText,
            items = shown,
            pickedCount = pickedNumbers.size,
            pickedSummary = pickedSummary.ifEmpty { "${pickedNumbers.size}건 선택됨" },
            hasMore = nextCursor != null,
        )
    }

    companion object {
        const val DEFAULT_PAGE_LIMIT = 20
        const val SIGN_OUT_COMMAND = "로그아웃"
        const val CLEAR_PICKED_COMMAND = "고르기 비우기"
    }
}
