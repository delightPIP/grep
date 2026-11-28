package com.unwrap.grep.feature.terminal.adapter

import com.unwrap.grep.feature.terminal.ui.TerminalEntryUi
import com.unwrap.grep.feature.terminal.ui.TerminalEntryUi.ChipLine
import com.unwrap.grep.feature.terminal.ui.TerminalEntryUi.TextLine
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TerminalFeatureLineDecoderTest {
    private val item = """
        {"number":7,"kind":"link","title":"결제 가이드","source":"a.com","status":"ready",
         "listSummary":"고친 요약","summarySource":"user","tags":["결제"],"savedAt":"2026-11-26T05:03:00Z"}
    """.trimIndent()

    private fun entries(lineJson: String, picked: Set<Int> = emptySet()): List<TerminalEntryUi> {
        val decoded = decodeFeatureLine(JSONObject(lineJson), picked)
        return requireNotNull(decoded) { "그리지 않은 줄: $lineJson" }
    }

    private fun texts(list: List<TerminalEntryUi>) = list.filterIsInstance<TextLine>().map { it.emphasis }

    @Test
    fun 인코더가내보내는피처줄종류일때_디코드하면_모두그려지는지() {
        // given
        val kinds = listOf(
            "dropConfirm", "dropped", "revived", "binList", "binEmptyConfirm", "binEmptied", "revised", "tagsRemoved",
            "samplesSaved", "unpicked", "pickCleared", "signOutEverywhereConfirm", "bundleList", "bundleAdded",
            "bundleView", "bundleNotFound", "bundleUnpicked", "notInBundle", "bundleDeleteConfirm", "bundleDeleted",
            "bundleNameInvalid", "folderHint", "itemDetail", "oneNumberOnly", "searchSaved", "savedSearchList",
            "savedSearchPeriod", "savedSearchTooLong", "savedSearchDeleteConfirm", "savedSearchDeleted",
            "savedSearchNotFound", "connectionList", "disconnectConfirm", "disconnected", "connectionNotFound",
            "connectionEnded", "importPrompt", "importProgress", "importFinished", "importSuggest",
        )

        // when
        val missing = kinds.filter { decodeFeatureLine(JSONObject("""{"kind":"$it"}"""), emptySet()) == null }

        // then
        assertEquals(40, kinds.size)
        assertEquals(emptyList<String>(), missing)
    }

    @Test
    fun 여러건버리기확인줄일때_디코드하면_경고와실행낱말칩이나오는지() {
        // given & when
        val result = entries("""{"kind":"dropConfirm","total":3}""")

        // then
        assertEquals(listOf("버리기? 3건 (휴지통으로)"), texts(result))
        val chipLine = result[1] as ChipLine
        assertEquals("→ 실행: ", chipLine.prefix)
        assertEquals(listOf("버리기"), chipLine.chips.map { it.command })
        assertTrue(chipLine.chips.single().submitsImmediately)
        assertEquals(" 다시 입력 · 취소: 그 외 입력", chipLine.suffix)
    }

    @Test
    fun 버린줄일때_디코드하면_되살리기번호를모두적는지() {
        // given & when
        val result = entries("""{"kind":"dropped","refs":[{"number":3,"title":"a"},{"number":9,"title":"b"}]}""")

        // then
        assertEquals(listOf("휴지통 2건 (30일 뒤 삭제, 되살리기 3 9)"), texts(result))
    }

    @Test
    fun 휴지통목록일때_디코드하면_남은날을메타에쓰고비어있으면안내만하는지() {
        // given
        val list = """{"kind":"binList","total":3,"hasMore":true,"trash":[{"item":$item,"daysLeft":29}]}"""

        // when
        val result = entries(list)
        val empty = entries("""{"kind":"binList","total":0,"trash":[]}""")

        // then
        val itemList = result[0] as TerminalEntryUi.ItemList
        assertEquals("3건 중 1건", itemList.header)
        assertEquals("a.com · 29일 남음", itemList.items.single().meta)
        assertNull(itemList.items.single().summary)
        assertTrue(itemList.hasMore)
        val footer = result[1] as ChipLine
        assertEquals(listOf("되살리기 ", "휴지통 비우기"), footer.chips.map { it.command })
        assertFalse(footer.chips[0].submitsImmediately)
        assertEquals(listOf("휴지통 비어 있음"), texts(empty))
    }

    @Test
    fun 직접고친요약이있을때_고침줄을디코드하면_요약줄을흐리게덧붙이는지() {
        // given & when
        val result = entries("""{"kind":"revised","item":$item}""")

        // then
        assertEquals(listOf("고침 7번  결제 가이드"), texts(result))
        val plain = result[1] as TerminalEntryUi.PlainLine
        assertEquals("요약 (직접 고침)  고친 요약", plain.text)
        assertTrue(plain.dim)
    }

    @Test
    fun 모든기기로그아웃확인일때_연결수에따라_연결칸을넣거나빼는지() {
        // given & when
        val withConnections = entries("""{"kind":"signOutEverywhereConfirm","count":2}""")
        val unknown = entries("""{"kind":"signOutEverywhereConfirm","count":null}""")

        // then
        assertEquals("로그아웃? 모든 기기 · AI 도구 연결 2개 (다른 기기는 최대 1시간 뒤)", texts(withConnections).single())
        assertEquals("로그아웃? 모든 기기 (다른 기기는 최대 1시간 뒤)", texts(unknown).single())
    }

    @Test
    fun 묶음목록일때_디코드하면_이름칩과건수를쓰고없으면할일을안내하는지() {
        // given & when
        val list = entries("""{"kind":"bundleList","entries":[{"name":"발표","count":3}]}""")
        val empty = entries("""{"kind":"bundleList","entries":[]}""")

        // then
        assertEquals("1개 묶음", (list[0] as TerminalEntryUi.PlainLine).text)
        val row = list[1] as ChipLine
        assertEquals("묶음 발표", row.chips.single().command)
        assertEquals("발표", row.chips.single().label)
        assertEquals("  3건", row.suffix)
        assertEquals(listOf("묶음 0개"), texts(empty))
        assertEquals(listOf("고르기 ", "묶음 "), empty.filterIsInstance<ChipLine>().map { it.chips.single().command })
    }

    @Test
    fun 묶음보기일때_디코드하면_머리줄에이름과건수를쓰는지() {
        // given & when
        val result = entries("""{"kind":"bundleView","name":"발표","total":5,"hasMore":true,"items":[$item]}""", setOf(7))

        // then
        val list = result.single() as TerminalEntryUi.ItemList
        assertEquals("묶음 발표  5건 중 1건", list.header)
        assertTrue(list.items.single().isPicked)
    }

    @Test
    fun 자세히보기일때_디코드하면_출처링크와요약이름표와태그묶음칩과동작칩이나오는지() {
        // given
        val detail = """
            {"kind":"itemDetail","detail":{"item":$item,"url":"https://a.com/x","handoffSummary":"넘길 요약",
             "allTags":["결제"],"bundles":[],"bodyLength":1234,"body":"본문","bodyFromImage":true,
             "originalUrl":null,"previewUrl":null}}
        """.trimIndent()

        // when
        val entry = entries(detail).single() as TerminalEntryUi.ItemDetail

        // then
        val rows = entry.rows.associateBy { it.label }
        assertEquals("a.com", rows.getValue("출처").value)
        assertEquals("https://a.com/x", rows.getValue("출처").linkUrl)
        assertEquals("2026-11-26 14:03", rows.getValue("저장").value)
        assertEquals("넘길 요약", rows.getValue("요약 (직접 고침)").value)
        assertEquals(listOf("찾기 #결제"), rows.getValue("태그 (AI 추정)").chips.map { it.command })
        assertEquals("없음", rows.getValue("묶음").value)
        assertEquals("(이미지에서 읽음) 1,234자", entry.bodyHead)
        assertFalse(entry.bodyExpandedInitially)
        assertEquals(listOf("고르기 7", "묶음 ", "고치기 7", "버리기 7"), entry.actions.map { it.command })
    }

    @Test
    fun 본문못가져온파일자료일때_자세히보기를디코드하면_상태와본문없음이유가나오는지() {
        // given
        val blocked = """
            {"kind":"itemDetail","detail":{"item":{"number":3,"kind":"file","title":"a.pdf","source":"pdf",
             "status":"blocked","blockedReason":"encrypted","tags":[],"savedAt":"2026-11-26T05:03:00Z"},
             "url":null,"handoffSummary":null,"allTags":[],"bundles":[],"bodyLength":null,"body":null,
             "bodyFromImage":false,"originalUrl":"https://files/x","previewUrl":null}}
        """.trimIndent()

        // when
        val entry = entries(blocked).single() as TerminalEntryUi.ItemDetail

        // then
        val rows = entry.rows.associateBy { it.label }
        assertEquals("직접 넣음 · PDF", rows.getValue("출처").value)
        assertEquals("! 본문 못 가져옴: 암호 걸린 PDF", rows.getValue("상태").value)
        assertNull(entry.bodyHead)
        assertEquals("암호 걸린 PDF", entry.noBodyReason)
        assertEquals("https://files/x", entry.originalUrl)
    }

    @Test
    fun 찾아두기와연결목록일때_디코드하면_정책문구와한국날짜를쓰는지() {
        // given & when
        val saved = entries("""{"kind":"searchSaved","text":"결제","total":0,"already":false}""")
        val connections = entries(
            """{"kind":"connectionList","text":"https://g/mcp","connections":[
                {"number":1,"client":"Claude","connectedAt":"2026-11-19T16:00:00Z","lastReadAt":"2026-11-21T00:00:00Z"}]}""",
        )

        // then
        assertEquals(listOf("찾아둠: 결제  0건", "맞는 자료가 저장되면 모임"), texts(saved))
        val plain = connections.filterIsInstance<TerminalEntryUi.PlainLine>().map { it.text }
        assertTrue(plain.contains("1  Claude  연결 11/20  읽음 11/21"))
    }

    @Test
    fun 가져오기가끝나고한도를넘었을때_디코드하면_실패주소와다시가져오기칩이나오는지() {
        // given & when
        val result = entries(
            """{"kind":"importFinished","importResult":{"saved":8,"skipped":1,"failed":1,"overLimit":5,"failedUrls":["https://x"]}}""",
        )

        // then
        assertEquals(listOf("저장 8건 · 건너뜀 1건 (이미 저장됨) · 실패 1건"), texts(result))
        assertEquals("  실패: https://x", (result[1] as TerminalEntryUi.PlainLine).text)
        val over = result[2] as ChipLine
        assertEquals("200건 넘어 안 가져옴 5건  → 나눠서 다시: ", over.prefix)
        assertEquals("가져오기", over.chips.single().command)
    }

    @Test
    fun 고르기빼기와열기를번호없이쳤을때_디코드하면_명령별예시가나오는지() {
        // given
        val unpick = """{"kind":"missingArgument","command":"pick","sub":"unpick"}"""
        val peek = """{"kind":"missingArgument","command":"peek"}"""

        // when
        val state = decodeTerminalState("""{"lines":[$unpick,$peek]}""")

        // then
        val lines = state.blocks.single().entries.map { (it as TextLine).emphasis }
        assertEquals(listOf("번호 없음  예: 고르기 빼기 131", "번호 없음  예: 열기 131"), lines)
    }
}
