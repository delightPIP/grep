package com.unwrap.grep.feature.loggedin.adapter

import com.unwrap.grep.feature.loggedin.ui.ArchiveItemRow
import org.junit.Assert.assertEquals
import org.junit.Test

class ArchivePageDecoderTest {
    @Test
    fun 쪽결과JSON일때_읽으면_행과다음커서를돌려주는지() {
        // given
        val json = """
            {"type":"page","nextCursor":"n","items":[
              {"number":5,"title":"제목","meta":"a.com · 2026-11-26 14:03","summary":null,
               "summaryIsWarning":false,"tags":["t1","t2"]}
            ]}
        """.trimIndent()

        // when
        val outcome = decodeArchivePage(json)

        // then
        val expected = ArchivePageOutcome.Page(
            rows = listOf(
                ArchiveItemRow(
                    number = 5,
                    title = "제목",
                    meta = "a.com · 2026-11-26 14:03",
                    summary = null,
                    summaryIsWarning = false,
                    tags = listOf("t1", "t2"),
                ),
            ),
            nextCursor = "n",
        )
        assertEquals(expected, outcome)
    }

    @Test
    fun 마지막쪽일때_읽으면_다음커서가없는지() {
        // given & when
        val outcome = decodeArchivePage("""{"type":"page","items":[]}""")

        // then
        assertEquals(ArchivePageOutcome.Page(emptyList(), null), outcome)
    }

    @Test
    fun 실패와만료와취소JSON일때_읽으면_각결과로바꾸는지() {
        // given & when & then
        assertEquals(ArchivePageOutcome.Failed("응답 없음"), decodeArchivePage("""{"type":"failed","message":"응답 없음"}"""))
        assertEquals(ArchivePageOutcome.SessionExpired, decodeArchivePage("""{"type":"sessionExpired"}"""))
        assertEquals(ArchivePageOutcome.Cancelled, decodeArchivePage("""{"type":"cancelled"}"""))
    }

    @Test
    fun 깨진JSON일때_읽으면_서버오류로보는지() {
        // given & when & then
        assertEquals(ArchivePageOutcome.Failed("서버 오류"), decodeArchivePage("not json"))
    }
}
