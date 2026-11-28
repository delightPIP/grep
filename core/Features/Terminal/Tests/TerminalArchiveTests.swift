import FeatureTerminalInterface
import GrepCore
import GrepCoreTesting
import Testing

@testable import FeatureTerminal

/// #168 보관함 탭 상태(ARC-007, ARC-003 규칙 18, ARC-012).
@MainActor
struct TerminalArchiveTests {
    private typealias Fixture = TerminalFixture

    private let fixture = Fixture()

    private static let firstPage = "/items?limit=20"
    private static let groupsPath = "/groups?tz=Asia%2FSeoul"
    private static let groupsJSON = #"{"kinds":[{"key":"link","count":2}],"sources":[{"key":"direct","count":1}],"#
        + #""periods":[{"key":"today","count":1},{"key":"thisWeek","count":2},{"key":"thisMonth","count":3},"#
        + #"{"key":"earlier","count":0}],"tags":[{"key":"결제","count":2}]}"#
    private static let bundlesJSON = #"{"bundles":[{"name":"결제","count":0,"updatedAt":"2026-11-27T10:00:00+09:00"}]}"#
    private static let searchesJSON = ##"{"searches":[{"query":"#swift","count":3},{"query":"비어 있음","count":0}]}"##

    private static func pageJSON(_ numbers: [Int], nextCursor: String? = nil) -> String {
        let cursor = nextCursor.map { "\"\($0)\"" } ?? "null"
        return #"{"items":[\#(numbers.map { Fixture.json(Fixture.item($0)) }.joined(separator: ","))],"nextCursor":\#(cursor)}"#
    }

    /// 보관함을 열고 네 응답을 차례로 준다.
    private func open(nextCursor: String? = nil) async {
        await fixture.send(.archiveOpen)
        await fixture.respond(json: Self.pageJSON([3, 2], nextCursor: nextCursor))
        await fixture.respond(json: Self.groupsJSON)
        await fixture.respond(json: Self.bundlesJSON)
        await fixture.respond(json: Self.searchesJSON)
    }

    // MARK: 열기

    @Test func 보관함을열때_아직받기전이면_불러오는중이고첫쪽부터묻는지() async {
        // given
        await fixture.attach()

        // when
        await fixture.send(.archiveOpen)

        // then
        #expect(fixture.state.archive == ArchiveState(status: .loading))
        #expect(fixture.transport.requests.last == Fixture.get(Self.firstPage))
    }

    @Test func 보관함을열때_차례로받으면_자료와자동묶음과묶음과찾아둔검색을채우는지() async {
        // given
        await fixture.attach()

        // when
        await open(nextCursor: "c2")

        // then: 0건 찾아둔 검색은 숨기고, 묶음은 0건도 둔다. 날짜 키는 계약 값으로 바꾼다.
        #expect(Array(fixture.transport.requests.suffix(4)) == [
            Fixture.get(Self.firstPage), Fixture.get(Self.groupsPath), Fixture.get("/bundles"),
            Fixture.get("/saved-searches"),
        ])
        #expect(fixture.state.archive == ArchiveState(
            groups: [
                AutoGroupEntry(group: .format, value: "link", count: 2),
                AutoGroupEntry(group: .source, value: "direct", count: 1),
                AutoGroupEntry(group: .date, value: "today", count: 1),
                AutoGroupEntry(group: .date, value: "week", count: 2),
                AutoGroupEntry(group: .date, value: "month", count: 3),
                AutoGroupEntry(group: .tag, value: "결제", count: 2),
            ],
            bundles: [BundleEntry(name: "결제", count: 0)],
            savedSearches: [SavedSearchEntry(query: "#swift", count: 3)],
            filter: .all,
            items: [Fixture.item(3), Fixture.item(2)],
            hasMore: true,
            status: .idle
        ))
    }

    @Test func 보관함을열때_첫쪽을받지못하면_오류로두는지() async {
        // given
        await fixture.attach()
        await fixture.send(.archiveOpen)

        // when
        await fixture.fail(.unreachable)

        // then
        #expect(fixture.state.archive?.status == .error)
        #expect(fixture.state.archive?.items == [])
    }

    @Test func 보관함을열때_세션만료로답하면_만료를알리는지() async {
        // given
        await fixture.attach()
        await fixture.send(.archiveOpen)

        // when
        await fixture.respond(status: 401, json: Fixture.sessionExpiredJSON)

        // then
        #expect(fixture.listener.expiredInputs.count == 1)
    }

    // MARK: 거르기

    @Test(arguments: [
        (ArchiveFilter.auto(group: .format, value: "link"), "/items?kind=link&limit=20"),
        (.auto(group: .date, value: "earlier"), "/items?to=2026-10-31T15%3A00%3A00Z&limit=20"),
        (.bundle(name: "결제"), "/bundles/%EA%B2%B0%EC%A0%9C?limit=20"),
        (.savedSearch(query: "#swift"), "/items/search?tag=swift&limit=20"),
    ])
    func 보관함이열려있을때_거를것을고르면_그조건으로첫쪽을받는지(filter: ArchiveFilter, path: String) async {
        // given
        await fixture.attach()
        await open()

        // when
        await fixture.send(.archiveSelect(filter))

        // then
        #expect(fixture.transport.requests.last == Fixture.get(path))
        #expect(fixture.state.archive?.filter == filter)
        #expect(fixture.state.archive?.status == .loading)
        #expect(fixture.state.archive?.items == [])
    }

    @Test func 묶음을골랐을때_묶음쪽이오면_그자료로바꾸는지() async {
        // given
        await fixture.attach()
        await open()
        await fixture.send(.archiveSelect(.bundle(name: "결제")))

        // when
        await fixture.respond(json: #"{"name":"결제","total":1,"items":[\#(Fixture.json(Fixture.item(7)))],"nextCursor":null}"#)

        // then
        #expect(fixture.state.archive?.items == [Fixture.item(7)])
        #expect(fixture.state.archive?.hasMore == false)
        #expect(fixture.state.archive?.status == .idle)
        #expect(fixture.state.archive?.bundles == [BundleEntry(name: "결제", count: 0)])
    }

    // MARK: 더 보기

    @Test func 다음쪽이있을때_더보기를누르면_커서로받아뒤에붙이는지() async {
        // given
        await fixture.attach()
        await open(nextCursor: "c2")

        // when
        await fixture.send(.archiveMore)
        await fixture.respond(json: Self.pageJSON([1]))

        // then
        #expect(fixture.transport.requests.last == Fixture.get("/items?limit=20&cursor=c2"))
        #expect(fixture.state.archive?.items == [Fixture.item(3), Fixture.item(2), Fixture.item(1)])
        #expect(fixture.state.archive?.hasMore == false)
    }

    @Test func 더보기가실패했을때_다시누르면_보던목록을두고같은커서로다시묻는지() async {
        // given
        await fixture.attach()
        await open(nextCursor: "c2")
        await fixture.send(.archiveMore)
        await fixture.fail(.timedOut)
        let failed = fixture.state.archive

        // when
        await fixture.send(.archiveMore)

        // then
        #expect(failed?.status == .error)
        #expect(failed?.items == [Fixture.item(3), Fixture.item(2)])
        #expect(failed?.hasMore == true)
        #expect(fixture.transport.requests.suffix(2).map(\.path) == ["/items?limit=20&cursor=c2", "/items?limit=20&cursor=c2"])
    }

    @Test func 다음쪽이없을때_더보기를누르면_묻지않는지() async {
        // given
        await fixture.attach()
        await open()
        let count = fixture.transport.requests.count

        // when
        await fixture.send(.archiveMore)

        // then
        #expect(fixture.transport.requests.count == count)
    }

    // MARK: 다시 받기

    @Test func 보관함이열려있을때_자료를저장하면_보던조건으로다시받는지() async {
        // given
        await fixture.attach()
        await open()
        await fixture.submit("담기 https://example.com")

        // when
        await fixture.respond(status: 201, json: #"{"result":"saved","item":\#(Fixture.json(Fixture.item(4)))}"#)

        // then
        #expect(fixture.transport.requests.last == Fixture.get(Self.firstPage))
    }

    @Test func 보관함을연적이없을때_자료를저장하면_보관함을받지않는지() async {
        // given
        await fixture.attach()
        await fixture.submit("담기 https://example.com")

        // when
        await fixture.respond(status: 201, json: #"{"result":"saved","item":\#(Fixture.json(Fixture.item(4)))}"#)

        // then
        #expect(fixture.transport.requests.allSatisfy { !$0.path.hasPrefix("/groups") })
        #expect(fixture.state.archive == nil)
    }
}
