import FeatureTerminalAdapter
import FeatureTerminalInterface
import FeatureTerminalUI
import GrepCore
import Testing

/// 터미널 머리 아래 `· 자료 N건`(COM-009 규칙 5, 웹 `TerminalIntro`).
struct TerminalIntroMapperTests {
    @Test func 자료가있는계정일때_매핑하면_지금건수를보이는지() {
        // given
        let state = TerminalViewState(itemCount: 34, lines: [])

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.itemCountLine == "자료 34건")
    }

    @Test func 자료가천건이상일때_매핑하면_천단위쉼표를붙이는지() {
        // given
        let state = TerminalViewState(itemCount: 1234, lines: [])

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.itemCountLine == "자료 1,234건")
    }

    @Test func 자료가0건일때_매핑하면_0건을보이는지() {
        // given
        let state = TerminalViewState(itemCount: 0, lines: [.welcome])

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.itemCountLine == "자료 0건")
    }

    @Test func 건수를아직받지못했을때_매핑하면_건수줄을빼는지() {
        // given
        let state = TerminalViewState(itemCount: nil, lines: [])

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.itemCountLine == nil)
    }
}
