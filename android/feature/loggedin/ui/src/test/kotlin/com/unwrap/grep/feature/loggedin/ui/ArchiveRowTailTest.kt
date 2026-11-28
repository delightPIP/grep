package com.unwrap.grep.feature.loggedin.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ArchiveRowTailTest {
    private fun row(
        meta: String = "a.com · 2026-11-26 14:03",
        summary: String? = null,
        summaryIsWarning: Boolean = false,
        tags: List<String> = emptyList(),
    ) = ArchiveItemRow(
        number = 1,
        title = "제목",
        meta = meta,
        summary = summary,
        summaryIsWarning = summaryIsWarning,
        tags = tags,
    )

    @Test
    fun 경고요약과태그가함께있을때_꼬리를만들면_경고요약을먼저보이는지() {
        // given
        val target = row(summary = "! 본문 못 가져옴 → 고치기 1", summaryIsWarning = true, tags = listOf("결제"))

        // when
        val tail = archiveRowTail(target)

        // then
        assertEquals(ArchiveRowTail(" · ! 본문 못 가져옴 → 고치기 1", isWarning = true), tail)
    }

    @Test
    fun 요약생성중일때_꼬리를만들면_요약생성중문구만보이는지() {
        // given
        val target = row(summary = "· 요약 생성 중", tags = listOf("결제"))

        // when
        val tail = archiveRowTail(target)

        // then
        assertEquals(ArchiveRowTail(" · 요약 생성 중", isWarning = false), tail)
    }

    @Test
    fun 일반요약과태그가있을때_꼬리를만들면_태그를샵붙여보이는지() {
        // given
        val target = row(summary = "보통 요약", tags = listOf("결제", "sdk"))

        // when
        val tail = archiveRowTail(target)

        // then
        assertEquals(ArchiveRowTail(" · #결제 #sdk", isWarning = false), tail)
    }

    @Test
    fun 메타가없고경고요약일때_꼬리를만들면_구분점없이시작하는지() {
        // given
        val target = row(meta = "", summary = "! 요약 못 만듦  제목·출처만 넘김", summaryIsWarning = true)

        // when
        val tail = archiveRowTail(target)

        // then
        assertEquals("! 요약 못 만듦  제목·출처만 넘김", tail?.text)
    }

    @Test
    fun 요약도태그도없을때_꼬리를만들면_없는지() {
        // given & when & then
        assertNull(archiveRowTail(row()))
    }
}
