import FeatureTerminalAdapter
import FeatureTerminalInterface
import FeatureTerminalUI
import GrepCore
import Testing

/// 샘플 8건 안내와 완료 줄(#103, ARC-010 규칙 1·4·6, 시안 15 Sample ①).
struct TerminalSamplesMapperTests {
    private static func sample(_ number: Int) -> ItemSummary {
        ItemSummary(
            number: number,
            kind: .link,
            title: "샘플 \(number)",
            source: "가상 기사",
            status: .ready,
            tags: [],
            savedAt: "2026-11-27T01:00:00Z"
        )
    }

    @Test func 자료가0건일때_매핑하면_샘플안내를보이는지() {
        // given
        let state = TerminalViewState(itemCount: 0, lines: [.welcome])

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.offersSamples)
    }

    @Test func 자료가있거나건수를모를때_매핑하면_샘플안내를숨기는지() {
        // given
        let withItems = TerminalViewState(itemCount: 8, lines: [.welcome])
        let unknown = TerminalViewState(itemCount: nil, lines: [])

        // when
        let presentations = [withItems, unknown].map(TerminalStateMapper.map)

        // then
        #expect(presentations.allSatisfy { !$0.offersSamples })
    }

    @Test func 샘플을저장했을때_매핑하면_번호범위와치우는법과목록을보이는지() {
        // given
        let items = (1...8).reversed().map(Self.sample)
        let state = TerminalViewState(
            itemCount: 8,
            lines: [.samplesSaved(firstNumber: 1, lastNumber: 8, items: items)]
        )

        // when
        let lines = TerminalStateMapper.map(state).blocks.first?.lines

        // then
        #expect(lines?.count == 3)
        #expect(lines?[0] == .status(tone: .ok, boldPrefix: "샘플 8건 저장 (1-8번)", body: ""))
        #expect(lines?[1] == .commandHint(prefix: "· 치우려면: ", command: "버리기 1-8", suffix: ""))
        guard case .list(let header, let rows, let hasMore) = lines?[2] else {
            Issue.record("Expected list line")
            return
        }
        #expect(header == nil)
        #expect(rows.map(\.number) == [8, 7, 6, 5, 4, 3, 2, 1])
        #expect(!hasMore)
    }

    @Test func 지운번호뒤에샘플을받았을때_매핑하면_받은범위를그대로쓰는지() {
        // given
        let state = TerminalViewState(lines: [
            .samplesSaved(firstNumber: 41, lastNumber: 48, items: []),
        ])

        // when
        let lines = TerminalStateMapper.map(state).blocks.first?.lines

        // then
        #expect(lines == [
            .status(tone: .ok, boldPrefix: "샘플 8건 저장 (41-48번)", body: ""),
            .commandHint(prefix: "· 치우려면: ", command: "버리기 41-48", suffix: ""),
        ])
    }
}
