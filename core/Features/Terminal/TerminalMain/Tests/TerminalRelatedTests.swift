import FeatureTerminalInterface
import TerminalDomain
import GrepCore
import GrepCoreTesting
import Testing

@testable import FeatureTerminal

/// #128 뜻 찾기: 0건이면 서버가 주는 뜻이 가까운 자료(api `SearchPage.related`)를 0건 줄에 함께 넘긴다.
@MainActor
struct TerminalRelatedTests {
    private static let query = SearchQuery(text: "보온병", words: "보온병", tags: [])

    private static func emptySearchJSON(related: [ItemSummary]?) -> String {
        let field = related.map { #","related":["# + $0.map(TerminalFixture.json).joined(separator: ",") + "]" } ?? ""
        return #"{"items":[],"total":0,"nextCursor":null\#(field)}"#
    }

    @Test func 찾기가0건일때_서버가뜻이가까운자료를주면_0건줄에함께넘기는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()
        let related = [TerminalFixture.item(140)]
        let recent = [TerminalFixture.item(200)]

        // when
        await fixture.submit("찾기 보온병")
        await fixture.respond(json: Self.emptySearchJSON(related: related))
        await fixture.respond(json: TerminalFixture.searchJSON(recent, total: 1))

        // then
        #expect(fixture.state.lines.last == .noResults(query: Self.query, recent: recent, related: related))
    }

    @Test func 찾기가0건일때_서버가related를주지않으면_빈목록으로넘기는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("찾기 보온병")
        await fixture.respond(json: Self.emptySearchJSON(related: nil))
        await fixture.respond(json: TerminalFixture.searchJSON([], total: 0))

        // then
        #expect(fixture.state.lines.last == .noResults(query: Self.query, recent: [], related: []))
    }

    @Test func 뜻이가까운자료가처리중일때_상태가바뀌면_0건줄의그자료도고치는지() {
        // given
        let processing = TerminalFixture.item(140, status: .processing, summary: nil)
        let state = TerminalViewState(lines: [.noResults(query: Self.query, recent: [], related: [processing])])

        // when
        let refreshed = state.replacingItems(with: [TerminalFixture.item(140)])

        // then
        #expect(state.processingNumbers(excluding: []) == [140])
        #expect(refreshed.lines == [.noResults(query: Self.query, recent: [], related: [TerminalFixture.item(140)])])
    }

    @Test func 뜻이가까운자료가있는0건줄일때_기록을남기고읽으면_같은줄로되살리는지() {
        // given
        let lines: [TerminalViewState.Line] = [
            .noResults(query: Self.query, recent: [TerminalFixture.item(200)], related: [TerminalFixture.item(140)]),
        ]

        // when
        let restored = TerminalHistory.decode(
            TerminalHistory.encode(TerminalHistory.Snapshot(lines: lines, input: "", selection: []))
        )

        // then
        #expect(restored?.lines == lines)
    }
}
