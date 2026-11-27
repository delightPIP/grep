#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FeatureTerminalInterface
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

/// #60: `최근`, 더 보기, 처리 중 자료 폴링(ARC-005 규칙 10), 연결 끊김과 다시 연결(COM-010).
@MainActor
final class TerminalBrowseTests {
    private static let sessionExpiredJSON = #"{"code":"session_expired"}"#
    private static let token = fakeAccessToken(subject: "user-a")
    private static let authorization = ["Authorization": "Bearer \(token)"]

    private let auth = FakeAuthService(token: TerminalBrowseTests.token)
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

    // MARK: 최근

    @Test func 터미널화면일때_최근을치면_친줄을찍고입력줄을비우고10건을요청하는지() async {
        // given
        await attachLoaded()

        // when
        await send(.submitted("최근"))

        // then
        #expect(state.lines == [.prompt("최근")])
        #expect(state.input == "")
        #expect(transport.requests.last == Self.get("/items?limit=10"))
    }

    @Test(arguments: [("최근 20", 20), ("recent 3", 3), ("최근 80", 50)])
    func 터미널화면일때_개수를붙여최근을치면_그개수를50건까지요청하는지(typed: String, limit: Int) async {
        // given
        await attachLoaded()

        // when
        await send(.submitted(typed))

        // then
        #expect(transport.requests.last == Self.get("/items?limit=\(limit)"))
    }

    @Test func 최근을기다릴때_다음쪽이없는목록이오면_더보기없는목록줄을찍는지() async {
        // given
        let items = [Self.item(34), Self.item(33)]
        await attachLoaded()
        await send(.submitted("최근"))

        // when
        await respond(json: Self.pageJSON(items))

        // then
        #expect(state.lines == [.prompt("최근"), .recentList(items: items, hasMore: false)])
    }

    @Test func 최근을기다릴때_다음쪽이있는목록이오면_더보기있는목록줄을찍는지() async {
        // given
        let items = [Self.item(34), Self.item(33)]
        await attachLoaded()
        await send(.submitted("최근 2"))

        // when
        await respond(json: Self.pageJSON(items, nextCursor: "33"))

        // then
        #expect(state.lines.last == .recentList(items: items, hasMore: true))
    }

    @Test(arguments: [
        (Result<HTTPResponse, HTTPTransportError>.failure(.unreachable), CommandFailure.disconnected),
        (.failure(.timedOut), .timedOut),
        (.success(HTTPResponse(status: 500, body: [])), .serverError),
        (.success(HTTPResponse(status: 200, body: Array("{}".utf8))), .serverError),
    ])
    func 최근을기다릴때_서버에닿지못하면_명령실패와다시칠명령을찍는지(
        response: Result<HTTPResponse, HTTPTransportError>, reason: CommandFailure
    ) async {
        // given
        await attachLoaded()
        await send(.submitted("최근 20"))

        // when
        transport.respond(response)
        await runCurrent()

        // then
        #expect(state.lines == [.prompt("최근 20"), .commandFailed(command: .recent, reason: reason, retry: "최근 20")])
    }

    @Test func 최근을기다릴때_세션이만료됐다고오면_친줄을들려만료를알리는지() async {
        // given
        await attachLoaded()
        await send(.submitted("최근"))

        // when
        await respond(status: 401, json: Self.sessionExpiredJSON)

        // then
        #expect(listener.expiredInputs == ["최근"])
    }

    // MARK: 더 보기

    @Test func 더보기있는목록일때_더보기를누르면_받아둔커서와같은개수로다음쪽을요청하는지() async {
        // given
        await attachLoaded()
        await send(.submitted("최근 2"))
        await respond(json: Self.pageJSON([Self.item(34), Self.item(33)], nextCursor: "33"))

        // when
        await send(.moreRequested)

        // then
        #expect(transport.requests.last == Self.get("/items?limit=2&cursor=33"))
    }

    @Test func 다음쪽을기다릴때_마지막쪽이오면_같은목록줄에이어붙이고더보기를빼는지() async {
        // given
        let first = [Self.item(34), Self.item(33)]
        let second = [Self.item(32)]
        await attachLoaded()
        await send(.submitted("최근 2"))
        await respond(json: Self.pageJSON(first, nextCursor: "33"))
        await send(.moreRequested)

        // when
        await respond(json: Self.pageJSON(second))

        // then
        #expect(state.lines == [.prompt("최근 2"), .recentList(items: first + second, hasMore: false)])
    }

    @Test func 다음쪽을기다릴때_더보기를또누르면_요청을한번만보내는지() async {
        // given
        await attachLoaded()
        await send(.submitted("최근 2"))
        await respond(json: Self.pageJSON([Self.item(34), Self.item(33)], nextCursor: "33"))
        await send(.moreRequested)
        let requestCount = transport.requests.count

        // when
        await send(.moreRequested)

        // then
        #expect(transport.requests.count == requestCount)
    }

    @Test func 더보기없는목록일때_더보기를누르면_아무것도요청하지않는지() async {
        // given
        await attachLoaded()
        await send(.submitted("최근"))
        await respond(json: Self.pageJSON([Self.item(34)]))
        let requestCount = transport.requests.count

        // when
        await send(.moreRequested)

        // then
        #expect(transport.requests.count == requestCount)
    }

    @Test func 다음쪽을기다릴때_서버에닿지못하면_목록은두고명령실패를찍는지() async {
        // given
        let first = [Self.item(34), Self.item(33)]
        await attachLoaded()
        await send(.submitted("최근 2"))
        await respond(json: Self.pageJSON(first, nextCursor: "33"))
        await send(.moreRequested)

        // when
        await fail(.timedOut)

        // then
        #expect(state.lines == [
            .prompt("최근 2"),
            .recentList(items: first, hasMore: true),
            .commandFailed(command: .recent, reason: .timedOut, retry: "최근 2"),
        ])
    }

    @Test func 더보기있는목록이있을때_최근을다시쳐새목록이오면_앞목록의더보기를빼는지() async {
        // given
        let first = [Self.item(34), Self.item(33)]
        await attachLoaded()
        await send(.submitted("최근 2"))
        await respond(json: Self.pageJSON(first, nextCursor: "33"))
        await send(.submitted("최근 1"))

        // when
        await respond(json: Self.pageJSON([Self.item(34)], nextCursor: "34"))

        // then
        #expect(state.lines == [
            .prompt("최근 2"),
            .recentList(items: first, hasMore: false),
            .prompt("최근 1"),
            .recentList(items: [Self.item(34)], hasMore: true),
        ])
    }

    @Test func 앞목록의다음쪽을기다릴때_새목록의더보기를누르면_새목록의다음쪽을요청하는지() async {
        // given
        await attachLoaded()
        await send(.submitted("최근 2"))
        await respond(json: Self.pageJSON([Self.item(34), Self.item(33)], nextCursor: "33"))
        await send(.moreRequested)
        await send(.submitted("최근 1"))
        transport.respondToLatest(json: Self.pageJSON([Self.item(34)], nextCursor: "34"))
        await runCurrent()

        // when
        await send(.moreRequested)

        // then
        #expect(transport.requests.last == Self.get("/items?limit=1&cursor=34"))
    }

    @Test func 최근을다시쳐새목록이왔을때_앞목록의다음쪽이늦게오면_그쪽을버리는지() async {
        // given
        let first = [Self.item(34), Self.item(33)]
        await attachLoaded()
        await send(.submitted("최근 2"))
        await respond(json: Self.pageJSON(first, nextCursor: "33"))
        await send(.moreRequested)
        await send(.submitted("최근 1"))
        transport.respondToLatest(json: Self.pageJSON([Self.item(34)], nextCursor: "34"))
        await runCurrent()

        // when
        await respond(json: Self.pageJSON([Self.item(32)]))

        // then
        #expect(state.lines == [
            .prompt("최근 2"),
            .recentList(items: first, hasMore: false),
            .prompt("최근 1"),
            .recentList(items: [Self.item(34)], hasMore: true),
        ])
    }

    @Test func 더보기있는목록일때_토큰을못받은채더보기를누르면_만료를알리는지() async {
        // given
        await attachLoaded()
        await send(.submitted("최근 2"))
        await respond(json: Self.pageJSON([Self.item(34), Self.item(33)], nextCursor: "33"))
        auth.token = nil

        // when
        await send(.moreRequested)

        // then
        #expect(listener.expiredInputs.count == 1)
    }

    // MARK: 처리 중 자료 폴링(ARC-005 규칙 10)

    @Test func 목록에처리중자료가있을때_목록을그리면_상태줄에처리중건수를세는지() async {
        // given
        let items = [Self.item(34, status: .received, summary: nil), Self.item(33, status: .processing, summary: nil), Self.item(32)]
        await attachLoaded()
        await send(.submitted("최근"))

        // when
        await respond(json: Self.pageJSON(items))

        // then
        #expect(state.processingCount == 2)
    }

    @Test func 목록에처리중자료가있을때_2초가지나면_그번호들의상태를묻는지() async {
        // given
        let items = [Self.item(34, status: .received, summary: nil), Self.item(33, status: .processing, summary: nil), Self.item(32)]
        await attachLoaded()
        await send(.submitted("최근"))
        await respond(json: Self.pageJSON(items))
        let requestCount = transport.requests.count

        // when
        await sleeper.advance(by: .seconds(1))
        let countBeforeTwoSeconds = transport.requests.count
        await sleeper.advance(by: .seconds(1))

        // then
        #expect(countBeforeTwoSeconds == requestCount)
        #expect(transport.requests.last == Self.get("/items/status?numbers=34,33"))
    }

    @Test func 상태를기다릴때_처리가끝난자료가오면_그자리의자료를바꾸고처리중건수를줄이는지() async {
        // given
        let waiting = Self.item(34, status: .received, summary: nil)
        let done = Self.item(34, status: .ready, summary: "끝난 요약")
        await attachLoaded()
        await send(.submitted("최근"))
        await respond(json: Self.pageJSON([waiting, Self.item(33)]))
        await sleeper.advance(by: .seconds(2))

        // when
        await respond(json: Self.lookupJSON([done]))

        // then
        #expect(state.lines == [.prompt("최근"), .recentList(items: [done, Self.item(33)], hasMore: false)])
        #expect(state.processingCount == 0)
    }

    @Test func 저장한줄과목록에같은자료가있을때_처리가끝나면_두줄을모두바꾸는지() async {
        // given
        let waiting = Self.item(35, status: .received, summary: nil)
        let done = Self.item(35, status: .ready, summary: "끝난 요약")
        await attachLoaded()
        await send(.pasted("https://example.com/a"))
        await respond(status: 201, json: #"{"result":"saved","item":\#(Self.json(waiting))}"#)
        await send(.submitted("최근"))
        await respond(json: Self.pageJSON([waiting]))
        await sleeper.advance(by: .seconds(2))

        // when
        await respond(json: Self.lookupJSON([done]))

        // then
        #expect(state.lines == [
            .prompt("담기 https://example.com/a"), .saved(done),
            .prompt("최근"), .recentList(items: [done], hasMore: false),
        ])
        #expect(state.processingCount == 0)
    }

    @Test func 처리중자료가남았을때_2초가또지나면_남은번호만다시묻는지() async {
        // given
        let first = Self.item(34, status: .received, summary: nil)
        let second = Self.item(33, status: .processing, summary: nil)
        await attachLoaded()
        await send(.submitted("최근"))
        await respond(json: Self.pageJSON([first, second]))
        await sleeper.advance(by: .seconds(2))
        await respond(json: Self.lookupJSON([Self.item(34), second]))

        // when
        await sleeper.advance(by: .seconds(2))

        // then
        #expect(transport.requests.last == Self.get("/items/status?numbers=33"))
    }

    @Test func 처리중자료가모두끝났을때_2초가또지나도_상태를더묻지않는지() async {
        // given
        await attachLoaded()
        await send(.submitted("최근"))
        await respond(json: Self.pageJSON([Self.item(34, status: .received, summary: nil)]))
        await sleeper.advance(by: .seconds(2))
        await respond(json: Self.lookupJSON([Self.item(34)]))
        let requestCount = transport.requests.count

        // when
        await sleeper.advance(by: .seconds(10))

        // then
        #expect(transport.requests.count == requestCount)
    }

    @Test func 상태를기다릴때_없는번호라고오면_그자료는더묻지않고처리중건수에서빼는지() async {
        // given
        await attachLoaded()
        await send(.submitted("최근"))
        await respond(json: Self.pageJSON([Self.item(34, status: .received, summary: nil)]))
        await sleeper.advance(by: .seconds(2))
        await respond(json: Self.lookupJSON([], missing: [34]))
        let requestCount = transport.requests.count

        // when
        await sleeper.advance(by: .seconds(10))

        // then
        #expect(state.processingCount == 0)
        #expect(transport.requests.count == requestCount)
    }

    @Test func 상태를기다릴때_응답이없으면_줄을찍지않고2초뒤다시묻는지() async {
        // given
        await attachLoaded()
        await send(.submitted("최근"))
        await respond(json: Self.pageJSON([Self.item(34, status: .received, summary: nil)]))
        await sleeper.advance(by: .seconds(2))
        let lines = state.lines
        let requestCount = transport.requests.count

        // when
        await fail(.timedOut)
        await sleeper.advance(by: .seconds(2))

        // then
        #expect(state.lines == lines)
        #expect(transport.requests.count == requestCount + 1)
        #expect(transport.requests.last == Self.get("/items/status?numbers=34"))
    }

    @Test func 처리중자료를폴링할때_화면이떨어지면_상태를더묻지않는지() async {
        // given
        await attachLoaded()
        await send(.submitted("최근"))
        await respond(json: Self.pageJSON([Self.item(34, status: .received, summary: nil)]))
        let requestCount = transport.requests.count

        // when
        parent.detach(router!)
        router = nil
        await sleeper.advance(by: .seconds(10))

        // then
        #expect(transport.requests.count == requestCount)
    }

    @Test func 저장한자료가처리중일때_2초가지나면_목록없이도그번호의상태를묻는지() async {
        // given
        let waiting = Self.item(35, status: .received, summary: nil)
        await attachLoaded()
        await send(.pasted("https://example.com/a"))
        await respond(status: 201, json: #"{"result":"saved","item":\#(Self.json(waiting))}"#)

        // when
        await sleeper.advance(by: .seconds(2))

        // then
        #expect(transport.requests.last == Self.get("/items/status?numbers=35"))
    }

    @Test func 상태를기다릴때_세션이만료됐다고오면_만료를알리고더묻지않는지() async {
        // given
        await attachLoaded()
        await send(.submitted("최근"))
        await respond(json: Self.pageJSON([Self.item(34, status: .received, summary: nil)]))
        await sleeper.advance(by: .seconds(2))
        await respond(status: 401, json: Self.sessionExpiredJSON)
        let requestCount = transport.requests.count

        // when
        await sleeper.advance(by: .seconds(2))
        await sleeper.advance(by: .seconds(2))

        // then
        #expect(listener.expiredInputs.count == 1)
        #expect(transport.requests.count == requestCount)
    }

    @Test func 상태를기다릴때_인증이거절되면_같은요청을되풀이하지않는지() async {
        // given: 세션 만료가 아닌 401(api/openapi.yaml `unauthorized`)
        await attachLoaded()
        await send(.submitted("최근"))
        await respond(json: Self.pageJSON([Self.item(34, status: .received, summary: nil)]))
        await sleeper.advance(by: .seconds(2))
        await respond(status: 401, json: #"{"code":"unauthorized"}"#)
        let requestCount = transport.requests.count

        // when
        await sleeper.advance(by: .seconds(2))
        await sleeper.advance(by: .seconds(2))

        // then
        #expect(transport.requests.count == requestCount)
        #expect(listener.expiredInputs.isEmpty)
    }

    @Test func 연결이끊겨폴링을쉬었을때_다시연결되고2초가지나면_상태를다시묻는지() async {
        // given
        await attachLoaded()
        await send(.submitted("최근"))
        await respond(json: Self.pageJSON([Self.item(34, status: .received, summary: nil)]))
        await send(.submitted("최근"))
        await fail(.unreachable)
        await sleeper.advance(by: .seconds(5))
        await respond(json: #"{"status":"ok"}"#)

        // when
        await sleeper.advance(by: .seconds(2))

        // then
        #expect(transport.requests.last == Self.get("/items/status?numbers=34"))
    }

    // MARK: 연결 끊김과 다시 연결(COM-010)

    @Test func 명령을기다릴때_네트워크오류가나면_상태줄에연결끊김을두는지() async {
        // given
        await attachLoaded()
        await send(.submitted("최근"))

        // when
        await fail(.unreachable)

        // then
        #expect(state.isOffline)
    }

    @Test(arguments: [
        Result<HTTPResponse, HTTPTransportError>.failure(.timedOut),
        .success(HTTPResponse(status: 500, body: [])),
    ])
    func 명령을기다릴때_응답없음이나서버오류면_연결끊김을두지않는지(response: Result<HTTPResponse, HTTPTransportError>) async {
        // given
        await attachLoaded()
        await send(.submitted("최근"))

        // when
        transport.respond(response)
        await runCurrent()

        // then
        #expect(!state.isOffline)
    }

    @Test func 연결이끊겼을때_5초가지나면_토큰없이health를묻는지() async {
        // given
        await attachLoaded()
        await send(.submitted("최근"))
        await fail(.unreachable)
        let requestCount = transport.requests.count

        // when
        await sleeper.advance(by: .seconds(4))
        let countBeforeFiveSeconds = transport.requests.count
        await sleeper.advance(by: .seconds(1))

        // then
        #expect(countBeforeFiveSeconds == requestCount)
        #expect(transport.requests.last == HTTPRequest(method: .get, path: "/health"))
    }

    @Test func health를기다릴때_서버가답하면_연결됨을한줄찍고연결끊김을빼는지() async {
        // given
        await attachLoaded()
        await send(.submitted("최근"))
        await fail(.unreachable)
        await sleeper.advance(by: .seconds(5))

        // when
        await respond(json: #"{"status":"ok"}"#)

        // then
        #expect(!state.isOffline)
        #expect(state.lines == [
            .prompt("최근"),
            .commandFailed(command: .recent, reason: .disconnected, retry: "최근"),
            .reconnected,
        ])
    }

    @Test func health를기다릴때_또닿지못하면_5초뒤다시묻는지() async {
        // given
        await attachLoaded()
        await send(.submitted("최근"))
        await fail(.unreachable)
        await sleeper.advance(by: .seconds(5))
        await fail(.unreachable)
        let requestCount = transport.requests.count

        // when
        await sleeper.advance(by: .seconds(5))

        // then
        #expect(state.isOffline)
        #expect(transport.requests.count == requestCount + 1)
        #expect(transport.requests.last == HTTPRequest(method: .get, path: "/health"))
    }

    @Test func 다시연결됐을때_시간이더지나도_health를더묻지않고끊긴동안친명령을다시하지않는지() async {
        // given
        await attachLoaded()
        await send(.submitted("최근"))
        await fail(.unreachable)
        await sleeper.advance(by: .seconds(5))
        await respond(json: #"{"status":"ok"}"#)
        let requestCount = transport.requests.count

        // when
        await sleeper.advance(by: .seconds(30))

        // then
        #expect(transport.requests.count == requestCount)
    }

    @Test func 연결이끊겼을때_사용자가친명령이서버에닿으면_연결됨을찍고결과를그리는지() async {
        // given
        await attachLoaded()
        await send(.submitted("최근"))
        await fail(.unreachable)
        await send(.submitted("최근"))

        // when
        await respond(json: Self.pageJSON([Self.item(34)]))

        // then
        #expect(!state.isOffline)
        #expect(Array(state.lines.suffix(3)) == [
            .prompt("최근"), .reconnected, .recentList(items: [Self.item(34)], hasMore: false),
        ])
    }

    @Test func 연결이끊긴채처리중자료가있을때_2초가지나면_상태를묻지않는지() async {
        // given
        await attachLoaded()
        await send(.submitted("최근"))
        await respond(json: Self.pageJSON([Self.item(34, status: .received, summary: nil)]))
        await send(.submitted("최근"))
        await fail(.unreachable)
        let requestCount = transport.requests.count

        // when
        await sleeper.advance(by: .seconds(2))

        // then
        #expect(transport.requests.count == requestCount)
    }
}
