import FeatureTerminalAdapter
import FeatureTerminalInterface
import FeatureTerminalUI
import GrepCore
import Testing

/// `고치기` 편집 칸과 결과 줄(#100, ARC-002 규칙 2, ARC-004 규칙 1, 시안 20 Edit).
struct TerminalReviseMapperTests {
    private static func item(summary: String?, source: SummarySource?) -> ItemSummary {
        ItemSummary(
            number: 25,
            kind: .file,
            title: "겨울 음료 트렌드 보고서.pdf",
            source: "PDF",
            status: .ready,
            listSummary: summary,
            summarySource: source,
            tags: ["음료", "할인"],
            savedAt: "2026-11-20T01:00:00Z"
        )
    }

    @Test func 고치기편집중일때_매핑하면_번호와지금값으로편집칸을여는지() {
        // given
        let state = TerminalViewState(
            lines: [.prompt("고치기 25")],
            revising: Revising(number: 25, title: "겨울 음료 트렌드 보고서.pdf", summary: "겨울 음료 수요 정리")
        )

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.revising == TerminalRevisePresentation(
            number: 25,
            title: "겨울 음료 트렌드 보고서.pdf",
            summary: "겨울 음료 수요 정리"
        ))
    }

    @Test func 편집중이아닐때_매핑하면_편집칸이없는지() {
        // given
        let state = TerminalViewState(lines: [.prompt("고치기 25"), .cancelled])

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.revising == nil)
    }

    @Test func 요약을직접고쳤을때_매핑하면_고침줄과직접고침이름표를붙이는지() {
        // given
        let state = TerminalViewState(lines: [
            .revised(Self.item(summary: "겨울 음료 수요와 텀블러 할인 반응 정리.", source: .user)),
        ])

        // when
        let lines = TerminalStateMapper.map(state).blocks.first?.lines

        // then
        #expect(lines == [
            .status(tone: .ok, boldPrefix: "고침", body: "  25번  겨울 음료 트렌드 보고서.pdf"),
            .plain(text: "요약 (직접 고침)  겨울 음료 수요와 텀블러 할인 반응 정리.", dim: true),
        ])
    }

    @Test func 제목만고쳤을때_매핑하면_자동요약은다시보이지않는지() {
        // given
        let state = TerminalViewState(lines: [
            .revised(Self.item(summary: "자동 요약", source: .ai)),
        ])

        // when
        let lines = TerminalStateMapper.map(state).blocks.first?.lines

        // then
        #expect(lines == [
            .status(tone: .ok, boldPrefix: "고침", body: "  25번  겨울 음료 트렌드 보고서.pdf"),
        ])
    }

    @Test func 태그를지웠을때_매핑하면_지운태그와번호를보이는지() {
        // given
        let state = TerminalViewState(lines: [
            .prompt("고치기 25 -#할인 -#음료"),
            .tagsRemoved(item: Self.item(summary: nil, source: nil), tags: ["할인", "음료"]),
        ])

        // when
        let lines = TerminalStateMapper.map(state).blocks.first?.lines

        // then
        #expect(lines?.last == .status(tone: .ok, boldPrefix: "태그 지움", body: " #할인 #음료 (25번)"))
    }
}
