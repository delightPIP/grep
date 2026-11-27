package com.unwrap.grep.feature.terminal.adapter

import com.unwrap.grep.feature.terminal.ui.TerminalEntryUi
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TerminalStateDecoderTest {
    @Test
    fun 고르기와5건초과확인JSON이있을때_디코드하면_선택수와낱말버튼이생성되는지() {
        // given
        val json = """
            {
              "input": "",
              "isOffline": false,
              "itemCount": 23,
              "processingCount": 0,
              "selection": [{"number": 131, "title": "웹훅 정책"}],
              "lines": [
                {"kind": "prompt", "text": "고르기 131"},
                {"kind": "picked", "refs": [{"number": 131, "title": "웹훅 정책"}]},
                {"kind": "prompt", "text": "넘기기"},
                {"kind": "handoffConfirm", "total": 23}
              ]
            }
        """.trimIndent()

        // when
        val state = decodeTerminalState(json)

        // then
        assertEquals("넘기기", state.windowTitle)
        assertEquals("자료 23 · 선택 1", state.statusText)
        assertEquals(2, state.blocks.size)
        val confirm = state.blocks[1].entries.single() as TerminalEntryUi.HandoffConfirm
        assertEquals("23건: 바로 복사 안 함 (5건 초과)", confirm.warningLine)
        assertEquals(listOf("앞10", "전부", "취소"), confirm.choices.map { it.command })
    }

    @Test
    fun 넘기기완료와도움말JSON이있을때_디코드하면_복사요약과13줄목록이나오는지() {
        // given
        val json = """
            {
              "input": "",
              "isOffline": false,
              "itemCount": 14,
              "processingCount": 1,
              "selection": [],
              "lines": [
                {"kind": "prompt", "text": "넘기기"},
                {"kind": "handedOff", "handoff": {
                  "items": [{"number": 131, "title": "웹훅 정책"}],
                  "charCount": 1248,
                  "missingSummaryCount": 1,
                  "text": "미리보기 본문"
                }},
                {"kind": "prompt", "text": "도움말"},
                {"kind": "guide"}
              ]
            }
        """.trimIndent()

        // when
        val state = decodeTerminalState(json)

        // then
        val handedOff = state.blocks[0].entries.single() as TerminalEntryUi.HandedOff
        assertEquals("복사됨  1건 · 1,248자 (제목·출처·저장 시각·요약)", handedOff.summaryLine)
        assertEquals(1, handedOff.missingSummaryCount)
        val guide = state.blocks[1].entries.single() as TerminalEntryUi.Guide
        assertEquals(13, guide.rows.size)
    }

    @Test
    fun 없는명령JSON이있을때_디코드하면_실패블록으로표시되는지() {
        // given
        val json = """
            {
              "input": "",
              "isOffline": false,
              "itemCount": 0,
              "processingCount": 0,
              "selection": [],
              "lines": [
                {"kind": "prompt", "text": "없는거"},
                {"kind": "unknownCommand", "text": "없는거"}
              ]
            }
        """.trimIndent()

        // when
        val state = decodeTerminalState(json)

        // then
        assertTrue(state.blocks.single().failed)
        val line = state.blocks.single().entries.single() as TerminalEntryUi.TextLine
        assertEquals("없는 명령:", line.emphasis)
        assertEquals(" 없는거", line.tail)
    }
}
