import FeatureTerminalInterface
import TerminalDomain
import GrepCore
import GrepCoreTesting
import Testing

@testable import FeatureTerminal

/// #134 찾아두기(ARC-012).
@MainActor
struct TerminalGatherTests {
    private static func searchJSON(_ items: [ItemSummary], total: Int, isSavedSearch: Bool? = nil) -> String {
        let saved = isSavedSearch.map { #","isSavedSearch":\#($0)"# } ?? ""
        return #"{"items":["# + items.map(TerminalFixture.json).joined(separator: ",")
            + #"],"total":\#(total),"nextCursor":null\#(saved)}"#
    }

    @Test func 검색어를찾아둘때_새로저장되면_찾아둠줄과결과목록을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()
        let item = TerminalFixture.item(140)

        // when
        await fixture.submit("찾아두기  텀블러   캠페인 ")
        await fixture.respond(status: 201, json: #"{"query":"텀블러 캠페인","count":1}"#)
        await fixture.respond(json: Self.searchJSON([item], total: 1, isSavedSearch: true))

        // then
        let save = fixture.transport.requests.dropLast().last
        #expect(save?.method == .put)
        #expect(save?.path == "/saved-searches")
        #expect(save?.body == #"{"query":"텀블러 캠페인"}"#)
        #expect(fixture.transport.requests.last?.path == "/items/search?q=%ED%85%80%EB%B8%94%EB%9F%AC%20%EC%BA%A0%ED%8E%98%EC%9D%B8&limit=10")
        #expect(Array(fixture.state.lines.suffix(2)) == [
            .searchSaved(query: "텀블러 캠페인", total: 1, already: false),
            .searchResult(
                query: SearchQuery(text: "텀블러 캠페인", words: "텀블러 캠페인", tags: []),
                total: 1, items: [item], hasMore: false, isSavedSearch: true
            ),
        ])
    }

    @Test func 이미찾아둔검색어일때_찾아두면_이미있음으로찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("찾아두기 #캠페인")
        await fixture.respond(status: 200, json: ##"{"query":"#캠페인","count":0}"##)
        await fixture.respond(json: Self.searchJSON([], total: 0, isSavedSearch: true))

        // then
        #expect(fixture.state.lines.last == .searchSaved(query: "#캠페인", total: 0, already: true))
    }

    @Test func 마지막낱말이시점일때_찾아두면_요청없이시점거부와제안을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("찾아두기 텀블러 지난주")

        // then
        #expect(fixture.transport.requests.isEmpty)
        #expect(fixture.state.lines.last == .savedSearchPeriod(period: "지난주", suggestion: "찾아두기 텀블러"))
    }

    @Test func 시점을따옴표로감쌌을때_찾아두면_저장을요청하는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit(#"찾아두기 "지난달""#)

        // then
        #expect(fixture.transport.requests.last?.body == #"{"query":"\"지난달\""}"#)
    }

    @Test func 검색어가40자를넘을때_찾아두면_요청없이너무긺줄을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("찾아두기 " + String(repeating: "가", count: 41))

        // then
        #expect(fixture.transport.requests.isEmpty)
        #expect(fixture.state.lines.last == .savedSearchTooLong)
    }

    @Test func 찾아두기만쳤을때_서버가목록을주면_찾아둔목록줄을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("gather")
        await fixture.respond(json: #"{"searches":[{"query":"텀블러","count":4},{"query":"겨울","count":0}]}"#)

        // then
        #expect(fixture.transport.requests.last?.method == .get)
        #expect(fixture.transport.requests.last?.path == "/saved-searches")
        #expect(fixture.state.lines.last == .savedSearchList([
            SavedSearchEntry(query: "텀블러", count: 4), SavedSearchEntry(query: "겨울", count: 0),
        ]))
    }

    @Test func 찾아둔것을지울때_지우기를다시치면_지우는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("찾아두기 텀블러 캠페인 지우기")
        let asked = fixture.state.lines.last == .savedSearchDeleteConfirm(query: "텀블러 캠페인")
        let requestsBeforeConfirm = fixture.transport.requests.count
        await fixture.submit("지우기")
        await fixture.respond(status: 204, json: "")

        // then
        #expect(asked)
        #expect(requestsBeforeConfirm == 0)
        #expect(fixture.transport.requests.last?.method == .delete)
        #expect(fixture.transport.requests.last?.path == "/saved-searches?query=%ED%85%80%EB%B8%94%EB%9F%AC%20%EC%BA%A0%ED%8E%98%EC%9D%B8")
        #expect(fixture.state.lines.last == .savedSearchDeleted(query: "텀블러 캠페인"))
    }

    @Test func 없는찾아둔것을지울때_서버가404로답하면_찾아둔것없음줄을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()
        await fixture.submit("찾아두기 텀블러 지우기")

        // when
        await fixture.submit("지우기")
        await fixture.respond(status: 404, json: #"{"code":"not_found"}"#)

        // then
        #expect(fixture.state.lines.last == .savedSearchNotFound(query: "텀블러"))
    }

    @Test func 이어쓰기일때_찾아두고결과가5건이하면_바로넘기는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("찾아두기 텀블러 | 넘기기")
        await fixture.respond(status: 201, json: #"{"query":"텀블러","count":1}"#)
        await fixture.respond(json: Self.searchJSON([TerminalFixture.item(140)], total: 1, isSavedSearch: true))
        await fixture.respond(json: #"{"text":"글","charCount":1,"items":[{"number":140,"title":"자료 140"}],"missingSummaryCount":0}"#)

        // then
        #expect(fixture.transport.requests.filter { $0.path != "/events" }.last?.path == "/handoff")
        #expect(fixture.fakeClipboard.copied.last == "글")
        #expect(fixture.state.lines.contains(.searchSaved(query: "텀블러", total: 1, already: false)))
    }

    @Test func 찾기결과에찾아둔여부가오면_결과줄에그대로넘기는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()
        let item = TerminalFixture.item(140)

        // when
        await fixture.submit("찾기 텀블러")
        await fixture.respond(json: Self.searchJSON([item], total: 1, isSavedSearch: false))

        // then
        #expect(fixture.state.lines.last == .searchResult(
            query: SearchQuery(text: "텀블러", words: "텀블러", tags: []),
            total: 1, items: [item], hasMore: false, isSavedSearch: false
        ))
    }

    @Test func 찾아두기줄이있을때_기록을남기고읽으면_같은줄로되살리는지() {
        // given
        let lines: [TerminalViewState.Line] = [
            .searchSaved(query: "텀블러", total: 4, already: true),
            .searchResult(
                query: SearchQuery(text: "텀블러", words: "텀블러", tags: []),
                total: 1, items: [TerminalFixture.item(140)], hasMore: false, isSavedSearch: true
            ),
            .savedSearchList([SavedSearchEntry(query: "텀블러", count: 4)]),
            .savedSearchPeriod(period: "지난주", suggestion: "찾아두기 텀블러"),
            .savedSearchTooLong,
            .savedSearchDeleteConfirm(query: "텀블러"),
            .savedSearchDeleted(query: "텀블러"),
            .savedSearchNotFound(query: "텀블러"),
        ]

        // when
        let restored = TerminalHistory.decode(
            TerminalHistory.encode(TerminalHistory.Snapshot(lines: lines, input: "", selection: []))
        )

        // then
        #expect(restored?.lines == lines)
    }
}
