import FeatureTerminalAdapter
import FeatureTerminalInterface
import FeatureTerminalUI
import GrepCore
import Testing

/// 시점을 붙인 `찾기`·`최근` 결과(#115, commands 3절 시점·6절 시점을 붙인 결과, 웹 `listHeader`·`WeekDivider`).
struct TerminalPeriodMapperTests {
    /// 지난달 = 한국 시간 10/1~10/31(반열린 구간 끝은 11/1 0시).
    private static let lastMonth = Period(label: "지난달", from: "2026-09-30T15:00:00Z", to: "2026-10-31T15:00:00Z")
    /// 3주전 = 한국 시간 11/9(월)~11/15(일).
    private static let threeWeeksAgo = Period(label: "3주전", from: "2026-11-08T15:00:00Z", to: "2026-11-15T15:00:00Z")

    private static func item(_ number: Int, savedAt: String) -> ItemSummary {
        ItemSummary(number: number, kind: .text, title: "자료 \(number)", source: nil, status: .ready, tags: [], savedAt: savedAt)
    }

    private static func listLine(_ state: TerminalViewState) -> (header: String?, rows: [TerminalItemRow])? {
        guard case .list(let header, let rows, _) = TerminalStateMapper.map(state).blocks.first?.lines.first else {
            return nil
        }
        return (header, rows)
    }

    @Test func 시점을붙여찾았을때_매핑하면_머리줄에시점과날짜범위를붙이는지() {
        // given
        let state = TerminalViewState(lines: [
            .searchResult(
                query: SearchQuery(text: "결제 지난달", words: "결제", tags: []),
                total: 23,
                items: [Self.item(30, savedAt: "2026-10-28T01:00:00Z"), Self.item(21, savedAt: "2026-10-20T01:00:00Z")],
                hasMore: true,
                period: Self.lastMonth
            ),
        ])

        // when
        let list = Self.listLine(state)

        // then
        #expect(list?.header == "23건 중 2건 · 지난달 (10/1~10/31)")
    }

    @Test func 기간이여러주에걸칠때_매핑하면_주가바뀌는행앞에월요일부터일요일구분선을넣는지() {
        // given
        let state = TerminalViewState(lines: [
            .searchResult(
                query: SearchQuery(text: "결제 지난달", words: "결제", tags: []),
                total: 3,
                items: [
                    Self.item(30, savedAt: "2026-10-28T01:00:00Z"),
                    Self.item(29, savedAt: "2026-10-26T00:30:00Z"),
                    Self.item(21, savedAt: "2026-10-20T01:00:00Z"),
                ],
                hasMore: false,
                period: Self.lastMonth
            ),
        ])

        // when
        let dividers = Self.listLine(state)?.rows.map(\.dividerBefore)

        // then
        #expect(dividers == ["── 10/26~11/1 ──", nil, "── 10/19~10/25 ──"])
    }

    @Test func 기간이한주안일때_매핑하면_구분선을넣지않는지() {
        // given
        let state = TerminalViewState(lines: [
            .recentList(
                items: [Self.item(40, savedAt: "2026-11-14T01:00:00Z"), Self.item(39, savedAt: "2026-11-09T01:00:00Z")],
                hasMore: false,
                period: Self.threeWeeksAgo
            ),
        ])

        // when
        let list = Self.listLine(state)

        // then
        #expect(list?.header == "2건 · 3주전 (11/9~11/15)")
        #expect(list?.rows.allSatisfy { $0.dividerBefore == nil } == true)
    }

    @Test func 시점없는최근일때_매핑하면_머리줄과구분선이없는지() {
        // given
        let state = TerminalViewState(lines: [
            .recentList(items: [Self.item(40, savedAt: "2026-11-14T01:00:00Z")], hasMore: false),
        ])

        // when
        let list = Self.listLine(state)

        // then
        #expect(list?.header == nil)
        #expect(list?.rows.first?.dividerBefore == nil)
    }

    @Test func 시점을붙여0건일때_매핑하면_시점이름과기간없이다시찾는칩을보이는지() {
        // given
        let state = TerminalViewState(lines: [
            .noResults(
                query: SearchQuery(text: "결제 #sdk 지난달", words: "결제", tags: ["sdk"]),
                recent: [],
                period: Self.lastMonth
            ),
        ])

        // when
        let lines = TerminalStateMapper.map(state).blocks.first?.lines

        // then
        #expect(lines == [
            .status(tone: .info, boldPrefix: nil, body: #"0건: "결제 #sdk" (지난달)"#),
            .commandHint(prefix: "→ 기간 없이: ", command: "찾기 결제 #sdk", suffix: ""),
        ])
    }
}
