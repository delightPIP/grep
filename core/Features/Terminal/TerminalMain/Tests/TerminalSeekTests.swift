#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FeatureTerminalInterface
import TerminalDomain
import FeatureTerminalTesting
import GrepCore
import GrepCoreTesting
import RIBs
import Testing

@testable import FeatureTerminal

@MainActor
private final class Dependency: TerminalDependency {
    let authService: any AuthService
    let httpTransport: any HTTPTransport
    let clipboard: any ClipboardPort = FakeClipboard()
    let files: any FilePort = FakeFilePort()
    let historyStore: any HistoryStore = FakeHistoryStore()
    let sleeper: any Sleeper
    init(authService: any AuthService, httpTransport: any HTTPTransport, sleeper: any Sleeper) {
        self.authService = authService
        self.httpTransport = httpTransport
        self.sleeper = sleeper
    }
}

/// #61: `찾기`(검색어·`#태그`), 0건 뒤 최근 3건, 찾기 결과 더 보기(commands 3절, ARC-002 규칙 5~8).
@MainActor
final class TerminalSeekTests {
    private static let sessionExpiredJSON = #"{"code":"session_expired"}"#
    private static let token = fakeAccessToken(subject: "user-a")
    private static let authorization = ["Authorization": "Bearer \(token)"]

    private let auth = FakeAuthService(token: TerminalSeekTests.token)
    private let transport = FakeHTTPTransport()
    private let sleeper = FakeSleeper()
    private let views = FakeTerminalViewFactory()
    private let listener = FakeTerminalListener()
    private let parent = TestParentRouter()
    private var router: (any ViewableRouting)?

    isolated deinit {
        if let router { parent.detach(router) }
    }

    private var view: FakeTerminalView { views.views.last! }
    private var state: TerminalViewState { view.state! }

    /// 부모가 자료 수(34)를 넘긴 터미널 화면.
    private func attachLoaded() async {
        let dependency = Dependency(authService: auth, httpTransport: transport, sleeper: sleeper)
        let build = TerminalBuilder(dependency: dependency, viewFactory: views).build(listener: listener)
        parent.attach(build.router)
        router = build.router
        await runCurrent()
        build.handle.showItemCount(34)
        await runCurrent()
    }

    private func send(_ action: TerminalViewAction) async {
        view.listener?.handle(action)
        await runCurrent()
    }

    private func respond(status: Int = 200, json: String) async {
        transport.respond(status: status, json: json)
        await runCurrent()
    }

    private func fail(_ error: HTTPTransportError) async {
        transport.respond(.failure(error))
        await runCurrent()
    }

    private static func item(_ number: Int, status: ItemStatus = .ready, summary: String? = "요약") -> ItemSummary {
        ItemSummary(
            number: number, kind: .link, title: "자료 \(number)", source: "example.com", status: status,
            listSummary: summary, summarySource: summary == nil ? nil : .ai, tags: [],
            savedAt: "2026-11-27T10:00:00+09:00"
        )
    }

    private static func json(_ item: ItemSummary) -> String {
        let summary = item.listSummary.map { "\"\($0)\"" } ?? "null"
        let summarySource = item.summarySource.map { "\"\($0.rawValue)\"" } ?? "null"
        return #"{"number":\#(item.number),"kind":"link","title":"\#(item.title)","source":"example.com","#
            + #""status":"\#(item.status.rawValue)","blockedReason":null,"listSummary":\#(summary),"#
            + #""summarySource":\#(summarySource),"partialNote":null,"tags":[],"matchedIn":null,"#
            + #""savedAt":"2026-11-27T10:00:00+09:00"}"#
    }

    private static func pageJSON(_ items: [ItemSummary], nextCursor: String? = nil) -> String {
        let cursor = nextCursor.map { "\"\($0)\"" } ?? "null"
        return #"{"items":[\#(items.map(json).joined(separator: ","))],"nextCursor":\#(cursor)}"#
    }

    private static func lookupJSON(_ items: [ItemSummary], missing: [Int] = []) -> String {
        let numbers = missing.map(String.init).joined(separator: ",")
        return #"{"items":[\#(items.map(json).joined(separator: ","))],"missing":[\#(numbers)]}"#
    }

    private static func get(_ path: String) -> HTTPRequest {
        HTTPRequest(method: .get, path: path, headers: authorization)
    }

    private static func searchJSON(_ items: [ItemSummary], total: Int, nextCursor: String? = nil) -> String {
        let cursor = nextCursor.map { "\"\($0)\"" } ?? "null"
        return #"{"items":[\#(items.map(json).joined(separator: ","))],"total":\#(total),"nextCursor":\#(cursor)}"#
    }

    private static func query(_ text: String, words: String, tags: [String] = []) -> SearchQuery {
        SearchQuery(text: text, words: words, tags: tags)
    }

    // MARK: 찾기 요청

    @Test(arguments: [
        ("찾기 tumbler", "/items/search?q=tumbler&limit=10"),
        ("seek pay widget", "/items/search?q=pay%20widget&limit=10"),
        ("찾기 결제", "/items/search?q=%EA%B2%B0%EC%A0%9C&limit=10"),
        ("찾기 #pay", "/items/search?tag=pay&limit=10"),
        ("찾기 #pay widget #ui", "/items/search?q=widget&tag=pay&tag=ui&limit=10"),
    ])
    func 터미널화면일때_찾기를치면_검색어와태그를나눠10건을요청하는지(typed: String, path: String) async {
        // given
        await attachLoaded()

        // when
        await send(.submitted(typed))

        // then
        #expect(state.lines == [.prompt(typed)])
        #expect(state.input == "")
        #expect(transport.requests.last == Self.get(path))
    }

    @Test(arguments: ["찾기", "seek", "찾기   "])
    func 터미널화면일때_찾기만치면_요청없이빠진인자줄을그리는지(typed: String) async {
        // given
        await attachLoaded()

        // when
        await send(.submitted(typed))

        // then
        #expect(state.lines == [.prompt(typed), .missingArgument(.seek)])
        #expect(transport.requests.isEmpty)
    }

    @Test(arguments: ["찾기 #", "찾기 결제 #"])
    func 터미널화면일때_태그이름없이샵만치면_요청없이태그없음줄을그리는지(typed: String) async {
        // given
        await attachLoaded()

        // when
        await send(.submitted(typed))

        // then
        #expect(state.lines == [.prompt(typed), .missingTag])
        #expect(transport.requests.isEmpty)
    }

    // MARK: 찾기 결과

    @Test func 찾기를기다릴때_결과가오면_전체건수와함께결과줄을찍는지() async {
        // given
        let items = [Self.item(34), Self.item(33)]
        await attachLoaded()
        await send(.submitted("찾기 #pay widget"))

        // when
        await respond(json: Self.searchJSON(items, total: 23, nextCursor: "33"))

        // then
        #expect(state.lines == [
            .prompt("찾기 #pay widget"),
            .searchResult(query: Self.query("#pay widget", words: "widget", tags: ["pay"]), total: 23, items: items, hasMore: true),
        ])
    }

    @Test func 찾기를기다릴때_0건이오면_최근3건을요청하는지() async {
        // given
        await attachLoaded()
        await send(.submitted("찾기 tumbler"))

        // when
        await respond(json: Self.searchJSON([], total: 0))

        // then
        #expect(state.lines == [.prompt("찾기 tumbler")])
        #expect(transport.requests.last == Self.get("/items?limit=3"))
    }

    @Test func 찾기가0건이라최근을기다릴때_최근자료가오면_0건줄과최근자료를찍는지() async {
        // given
        let recent = [Self.item(34), Self.item(33), Self.item(32)]
        await attachLoaded()
        await send(.submitted("찾기 tumbler"))
        await respond(json: Self.searchJSON([], total: 0))

        // when
        await respond(json: Self.pageJSON(recent, nextCursor: "32"))

        // then
        #expect(state.lines == [
            .prompt("찾기 tumbler"),
            .noResults(query: Self.query("tumbler", words: "tumbler"), recent: recent),
        ])
    }

    @Test func 찾기가0건이라최근을기다릴때_최근을받지못하면_최근자료없이0건줄을찍는지() async {
        // given
        await attachLoaded()
        await send(.submitted("찾기 tumbler"))
        await respond(json: Self.searchJSON([], total: 0))

        // when
        await fail(.timedOut)

        // then
        #expect(state.lines == [
            .prompt("찾기 tumbler"),
            .noResults(query: Self.query("tumbler", words: "tumbler"), recent: []),
        ])
    }

    @Test(arguments: [
        (Result<HTTPResponse, HTTPTransportError>.failure(.unreachable), CommandFailure.disconnected),
        (.failure(.timedOut), .timedOut),
        (.success(HTTPResponse(status: 500, body: [])), .serverError),
        (.success(HTTPResponse(status: 200, body: Array("{}".utf8))), .serverError),
    ])
    func 찾기를기다릴때_서버에닿지못하면_명령실패와다시칠명령을찍는지(
        response: Result<HTTPResponse, HTTPTransportError>, reason: CommandFailure
    ) async {
        // given
        await attachLoaded()
        await send(.submitted("찾기 tumbler"))

        // when
        transport.respond(response)
        await runCurrent()

        // then
        #expect(state.lines == [.prompt("찾기 tumbler"), .commandFailed(command: .seek, reason: reason, retry: "찾기 tumbler")])
    }

    @Test func 찾기를기다릴때_세션이만료됐다고오면_친줄을들려만료를알리는지() async {
        // given
        await attachLoaded()
        await send(.submitted("찾기 tumbler"))

        // when
        await respond(status: 401, json: Self.sessionExpiredJSON)

        // then
        #expect(listener.expiredInputs == ["찾기 tumbler"])
    }

    // MARK: 찾기 결과 더 보기

    @Test func 더보기있는찾기결과일때_더보기를누르면_같은조건과받아둔커서로다음쪽을요청하는지() async {
        // given
        await attachLoaded()
        await send(.submitted("찾기 #pay widget"))
        await respond(json: Self.searchJSON([Self.item(34), Self.item(33)], total: 3, nextCursor: "33"))

        // when
        await send(.moreRequested)

        // then
        #expect(transport.requests.last == Self.get("/items/search?q=widget&tag=pay&limit=10&cursor=33"))
    }

    @Test func 찾기다음쪽을기다릴때_마지막쪽이오면_같은결과줄에이어붙이고더보기를빼는지() async {
        // given
        let first = [Self.item(34), Self.item(33)]
        let query = Self.query("tumbler", words: "tumbler")
        await attachLoaded()
        await send(.submitted("찾기 tumbler"))
        await respond(json: Self.searchJSON(first, total: 3, nextCursor: "33"))
        await send(.moreRequested)

        // when
        await respond(json: Self.searchJSON([Self.item(32)], total: 3))

        // then
        #expect(state.lines == [
            .prompt("찾기 tumbler"),
            .searchResult(query: query, total: 3, items: first + [Self.item(32)], hasMore: false),
        ])
    }

    @Test func 찾기다음쪽을기다릴때_서버에닿지못하면_결과는두고찾기실패를찍는지() async {
        // given
        let first = [Self.item(34), Self.item(33)]
        let query = Self.query("tumbler", words: "tumbler")
        await attachLoaded()
        await send(.submitted("찾기 tumbler"))
        await respond(json: Self.searchJSON(first, total: 3, nextCursor: "33"))
        await send(.moreRequested)

        // when
        await fail(.timedOut)

        // then
        #expect(state.lines == [
            .prompt("찾기 tumbler"),
            .searchResult(query: query, total: 3, items: first, hasMore: true),
            .commandFailed(command: .seek, reason: .timedOut, retry: "찾기 tumbler"),
        ])
    }

    @Test func 더보기있는최근목록이있을때_찾기결과가오면_앞목록의더보기를빼고찾기결과에만두는지() async {
        // given
        let recent = [Self.item(34), Self.item(33)]
        await attachLoaded()
        await send(.submitted("최근 2"))
        await respond(json: Self.pageJSON(recent, nextCursor: "33"))
        await send(.submitted("찾기 tumbler"))

        // when
        await respond(json: Self.searchJSON([Self.item(34)], total: 2, nextCursor: "34"))
        await send(.moreRequested)

        // then
        #expect(state.lines == [
            .prompt("최근 2"),
            .recentList(items: recent, hasMore: false),
            .prompt("찾기 tumbler"),
            .searchResult(query: Self.query("tumbler", words: "tumbler"), total: 2, items: [Self.item(34)], hasMore: true),
        ])
        #expect(transport.requests.last == Self.get("/items/search?q=tumbler&limit=10&cursor=34"))
    }

    @Test func 더보기있는찾기결과가있을때_최근목록이오면_찾기결과의더보기를빼는지() async {
        // given
        let found = [Self.item(34)]
        await attachLoaded()
        await send(.submitted("찾기 tumbler"))
        await respond(json: Self.searchJSON(found, total: 2, nextCursor: "34"))
        await send(.submitted("최근"))

        // when
        await respond(json: Self.pageJSON([Self.item(34)]))

        // then
        #expect(state.lines == [
            .prompt("찾기 tumbler"),
            .searchResult(query: Self.query("tumbler", words: "tumbler"), total: 2, items: found, hasMore: false),
            .prompt("최근"),
            .recentList(items: [Self.item(34)], hasMore: false),
        ])
    }

    // MARK: 찾기 결과의 처리 중 자료(ARC-005 규칙 10)

    @Test func 찾기결과에처리중자료가있을때_처리가끝나면_결과줄의자료를그자리에서바꾸는지() async {
        // given
        let waiting = Self.item(34, status: .processing, summary: nil)
        let done = Self.item(34, status: .ready, summary: "끝난 요약")
        let query = Self.query("tumbler", words: "tumbler")
        await attachLoaded()
        await send(.submitted("찾기 tumbler"))
        await respond(json: Self.searchJSON([waiting], total: 1))
        await sleeper.advance(by: .seconds(2))

        // when
        await respond(json: Self.lookupJSON([done]))

        // then
        #expect(transport.requests.last == Self.get("/items/status?numbers=34"))
        #expect(state.lines == [.prompt("찾기 tumbler"), .searchResult(query: query, total: 1, items: [done], hasMore: false)])
        #expect(state.processingCount == 0)
    }
}
