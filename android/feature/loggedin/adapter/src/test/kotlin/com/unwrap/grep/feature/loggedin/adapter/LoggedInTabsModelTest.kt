package com.unwrap.grep.feature.loggedin.adapter

import com.unwrap.grep.feature.loggedin.ui.ArchiveItemRow
import com.unwrap.grep.feature.loggedin.ui.LoggedInTab
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

private class FakeArchiveLoader : ArchiveItemLoader {
    val requests = mutableListOf<Pair<Int, String?>>()
    private val pending = ArrayDeque<(ArchivePageOutcome) -> Unit>()

    override fun loadPage(limit: Int, cursor: String?, onResult: (ArchivePageOutcome) -> Unit) {
        requests += limit to cursor
        pending.addLast(onResult)
    }

    fun respond(outcome: ArchivePageOutcome) {
        pending.removeFirst().invoke(outcome)
    }
}

private fun row(number: Int) = ArchiveItemRow(
    number = number,
    title = "자료 $number",
    meta = "a.com",
    summary = null,
    summaryIsWarning = false,
    tags = emptyList(),
)

class LoggedInTabsModelTest {
    private val loader = FakeArchiveLoader()
    private val commands = mutableListOf<String>()
    private var expiredCount = 0
    private val model = LoggedInTabsModel(
        archiveLoader = loader,
        sendCommand = { commands += it },
        pageLimit = 2,
        onSessionExpired = { expiredCount += 1 },
    )

    @Test
    fun 모델을만들었을때_시작탭을확인하면_터미널인지() {
        // given & when & then
        assertEquals(LoggedInTab.TERMINAL, model.selectedTab)
        assertTrue(loader.requests.isEmpty())
    }

    @Test
    fun 보관함탭을처음열때_목록을받으면_행과머리줄과더보기를채우는지() {
        // given
        model.select(LoggedInTab.ARCHIVE)
        assertTrue(model.archivePresentation.isLoading)

        // when
        loader.respond(ArchivePageOutcome.Page(listOf(row(9), row(8)), nextCursor = "c1"))

        // then
        val presentation = model.archivePresentation
        assertEquals(listOf(2 to null), loader.requests)
        assertFalse(presentation.isLoading)
        assertEquals(listOf(9, 8), presentation.items.map { it.number })
        assertEquals("자료 2+", presentation.statusText)
        assertTrue(presentation.hasMore)
    }

    @Test
    fun 이미불러온뒤_보관함탭을다시열면_다시부르지않는지() {
        // given
        model.select(LoggedInTab.ARCHIVE)
        loader.respond(ArchivePageOutcome.Page(listOf(row(1)), nextCursor = null))
        model.select(LoggedInTab.SETTINGS)

        // when
        model.select(LoggedInTab.ARCHIVE)

        // then
        assertEquals(1, loader.requests.size)
    }

    @Test
    fun 더보기를누를때_겹친번호가오면_중복없이뒤에붙이는지() {
        // given
        model.select(LoggedInTab.ARCHIVE)
        loader.respond(ArchivePageOutcome.Page(listOf(row(9), row(8)), nextCursor = "c1"))

        // when
        model.loadMoreArchive()
        loader.respond(ArchivePageOutcome.Page(listOf(row(8), row(7)), nextCursor = null))

        // then
        assertEquals(2 to "c1", loader.requests.last())
        assertEquals(listOf(9, 8, 7), model.archivePresentation.items.map { it.number })
        assertFalse(model.archivePresentation.hasMore)
        assertEquals("자료 3", model.archivePresentation.statusText)
    }

    @Test
    fun 터미널이자료수를알때_보관함머리줄을만들면_터미널자료수를쓰는지() {
        // given
        model.updateTerminalContext(itemCount = 25, pickedNumbers = emptySet())

        // when
        model.select(LoggedInTab.ARCHIVE)
        loader.respond(ArchivePageOutcome.Page(listOf(row(1)), nextCursor = "c1"))

        // then
        assertEquals("자료 25", model.archivePresentation.statusText)
    }

    @Test
    fun 불러오기가실패할때_보관함을그리면_오류문구가남고다시시도하면지우는지() {
        // given
        model.select(LoggedInTab.ARCHIVE)

        // when
        loader.respond(ArchivePageOutcome.Failed("연결 끊김"))

        // then
        assertEquals("연결 끊김", model.archivePresentation.errorMessage)

        // when
        model.refreshArchive()

        // then
        assertNull(model.archivePresentation.errorMessage)
        assertTrue(model.archivePresentation.isLoading)
    }

    @Test
    fun 세션이만료됐을때_목록을받으면_만료를알리는지() {
        // given
        model.select(LoggedInTab.ARCHIVE)

        // when
        loader.respond(ArchivePageOutcome.SessionExpired)

        // then
        assertEquals(1, expiredCount)
    }

    @Test
    fun 터미널선택이바뀔때_보관함을그리면_고른행과요약과개수를맞추는지() {
        // given
        model.select(LoggedInTab.ARCHIVE)
        loader.respond(ArchivePageOutcome.Page(listOf(row(9), row(8)), nextCursor = null))

        // when
        model.updateTerminalContext(itemCount = 2, pickedNumbers = setOf(8))

        // then
        val presentation = model.archivePresentation
        assertEquals(listOf(false, true), presentation.items.map { it.isPicked })
        assertEquals(1, presentation.pickedCount)
        assertEquals("8 자료 8", presentation.pickedSummary)
    }

    @Test
    fun 체크칸을누를때_고르기명령을보내고이미고른자료면_빼기명령을보내는지() {
        // given
        model.updateTerminalContext(itemCount = null, pickedNumbers = setOf(8))

        // when
        model.togglePick(9)
        model.togglePick(8)
        model.clearPicked()

        // then
        assertEquals(listOf("고르기 9", "고르기 빼기 8", "고르기 비우기"), commands)
    }

    @Test
    fun 로그아웃을두번누를때_요청하면_명령을한번만보내는지() {
        // given & when
        model.requestSignOut()
        model.requestSignOut()

        // then
        assertEquals(listOf("로그아웃"), commands)
        assertTrue(model.settingsPresentation.isSigningOut)
    }

    @Test
    fun 탭을다시누를때_각탭트리거를올리고넘기기는터미널로옮기는지() {
        // given
        model.select(LoggedInTab.SETTINGS)

        // when
        model.reselect(LoggedInTab.TERMINAL)
        model.reselect(LoggedInTab.ARCHIVE)
        model.reselect(LoggedInTab.SETTINGS)
        model.moveToTerminalForHandoff()

        // then
        assertEquals(1, model.terminalScrollToBottomTrigger)
        assertEquals(1, model.archiveScrollToTopTrigger)
        assertEquals(1, model.settingsResetToRootTrigger)
        assertEquals(LoggedInTab.TERMINAL, model.selectedTab)
    }
}
