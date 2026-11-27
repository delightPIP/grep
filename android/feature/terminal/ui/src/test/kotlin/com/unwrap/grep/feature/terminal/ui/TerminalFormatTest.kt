package com.unwrap.grep.feature.terminal.ui

import org.junit.Assert.assertEquals
import org.junit.Test

class TerminalFormatTest {
    @Test
    fun 자료수와선택과처리중과오프라인이있을때_상태줄을만들면_정책순서대로합쳐지는지() {
        // given
        val itemCount = 23
        val selectionCount = 2
        val processingCount = 1
        val isOffline = true

        // when
        val result = TerminalFormat.statusText(itemCount, selectionCount, processingCount, isOffline)

        // then
        assertEquals("자료 23 · 선택 2 · 요약 생성 중 1 · 연결 끊김", result)
    }

    @Test
    fun 자료수가없고정상상태일때_상태줄을만들면_기본문구만나오는지() {
        // given
        val itemCount: Int? = null

        // when
        val result = TerminalFormat.statusText(itemCount, 0, 0, false)

        // then
        assertEquals("자료 · 선택 0", result)
    }

    @Test
    fun UTC시각문자열이있을때_저장시각을포맷하면_한국시간으로변환되는지() {
        // given
        val utc = "2026-11-27T05:12:00Z"

        // when
        val formatted = TerminalFormat.formatSavedAt(utc)

        // then
        assertEquals("2026-11-27 14:12", formatted)
    }

    @Test
    fun 파일크기가20MB를넘을때_메가바이트를포맷하면_정수와소수한자리로표시되는지() {
        // given
        val exact = 24 * 1024 * 1024
        val fractional = (21.5 * 1024 * 1024).toInt()

        // when
        val exactText = TerminalFormat.formatMegabytes(exact)
        val fractionalText = TerminalFormat.formatMegabytes(fractional)

        // then
        assertEquals("24MB", exactText)
        assertEquals("21.5MB", fractionalText)
    }
}
