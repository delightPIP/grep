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

@testable import FeatureTerminal

/// 터미널을 가짜 포트로 붙여 두는 테스트 받침. 응답 시점은 테스트가 정한다.
@MainActor
final class TerminalFixture: TerminalDependency {
    static let subject = "user-a"
    static let token = fakeAccessToken(subject: subject)
    static let authorization = ["Authorization": "Bearer \(token)"]
    static let sessionExpiredJSON = #"{"code":"session_expired"}"#

    let auth = FakeAuthService(token: TerminalFixture.token)
    let transport = FakeHTTPTransport()
    let fakeClipboard = FakeClipboard()
    let fakeHistory: FakeHistoryStore
    let fakeSleeper = FakeSleeper()
    let views = FakeTerminalViewFactory()
    let listener = FakeTerminalListener()
    private let parent = TestParentRouter()
    private var router: (any ViewableRouting)?
    private(set) var handle: (any TerminalHandle)?

    var authService: any AuthService { auth }
    var httpTransport: any HTTPTransport { transport }
    var clipboard: any ClipboardPort { fakeClipboard }
    let fakeFiles = FakeFilePort()
    var files: any FilePort { fakeFiles }
    var historyStore: any HistoryStore { fakeHistory }
    var sleeper: any Sleeper { fakeSleeper }

    init(history: HistoryRecord? = nil) {
        fakeHistory = FakeHistoryStore(record: history)
    }

    isolated deinit {
        if let router { parent.detach(router) }
    }

    var view: FakeTerminalView { views.views.last! }
    var state: TerminalViewState { view.state! }

    /// 터미널 화면을 붙인다. `itemCount`가 있으면 부모가 자료 수를 넘긴 것으로 본다.
    func attach(itemCount: Int? = 34) async {
        let build = attachWithoutRunning()
        await runCurrent()
        if let itemCount {
            build.handle.showItemCount(itemCount)
            await runCurrent()
        }
    }

    /// 붙이기만 하고 띄운 Task는 돌리지 않는다. 기록을 되살리기 전의 입력을 만든다.
    @discardableResult
    func attachWithoutRunning() -> TerminalBuild {
        let build = TerminalBuilder(dependency: self, viewFactory: views).build(listener: listener)
        parent.attach(build.router)
        router = build.router
        handle = build.handle
        return build
    }

    /// 화면을 뗀다. 다시 `attach`하면 새 터미널이 붙는다(다시 열기).
    func detach() async {
        if let router { parent.detach(router) }
        router = nil
        handle = nil
        await runCurrent()
    }

    func send(_ action: TerminalViewAction) async {
        view.listener?.handle(action)
        await runCurrent()
    }

    func submit(_ text: String) async {
        await send(.submitted(text))
    }

    func respond(status: Int = 200, json: String) async {
        transport.respond(status: status, json: json)
        await runCurrent()
    }

    func fail(_ error: HTTPTransportError) async {
        transport.respond(.failure(error))
        await runCurrent()
    }

    /// `고르기 <번호…>`를 치고 서버가 모두 있다고 답하게 한다.
    func pick(_ numbers: [Int]) async {
        await submit("고르기 " + numbers.map(String.init).joined(separator: " "))
        await respond(json: Self.lookupJSON(numbers.map { Self.item($0) }))
    }

    static func item(_ number: Int, status: ItemStatus = .ready, summary: String? = "요약") -> ItemSummary {
        ItemSummary(
            number: number, kind: .link, title: "자료 \(number)", source: "example.com", status: status,
            listSummary: summary, summarySource: summary == nil ? nil : .ai, tags: [],
            savedAt: "2026-11-27T10:00:00+09:00"
        )
    }

    /// `item(_:)`과 같은 자료를 가리킨다(링크, `example.com`).
    static func ref(_ number: Int) -> ItemRef {
        ItemRef(number: number, title: "자료 \(number)", kind: .link, source: "example.com")
    }

    static func json(_ item: ItemSummary) -> String {
        let summary = item.listSummary.map { "\"\($0)\"" } ?? "null"
        let summarySource = item.summarySource.map { "\"\($0.rawValue)\"" } ?? "null"
        let source = item.source.map { "\"\($0)\"" } ?? "null"
        return #"{"number":\#(item.number),"kind":"\#(item.kind.rawValue)","title":"\#(item.title)","source":\#(source),"#
            + #""status":"\#(item.status.rawValue)","blockedReason":null,"listSummary":\#(summary),"#
            + #""summarySource":\#(summarySource),"partialNote":null,"tags":[],"matchedIn":null,"#
            + #""savedAt":"2026-11-27T10:00:00+09:00"}"#
    }

    static func lookupJSON(_ items: [ItemSummary], missing: [Int] = []) -> String {
        let numbers = missing.map(String.init).joined(separator: ",")
        return #"{"items":[\#(items.map(json).joined(separator: ","))],"missing":[\#(numbers)]}"#
    }

    static func searchJSON(_ items: [ItemSummary], total: Int, nextCursor: String? = nil) -> String {
        let cursor = nextCursor.map { "\"\($0)\"" } ?? "null"
        return #"{"items":[\#(items.map(json).joined(separator: ","))],"total":\#(total),"nextCursor":\#(cursor)}"#
    }

    static func get(_ path: String) -> HTTPRequest {
        HTTPRequest(method: .get, path: path, headers: authorization)
    }

    static func handoffRequest(_ numbers: [Int]) -> HTTPRequest {
        HTTPRequest(
            method: .post, path: "/handoff",
            headers: authorization.merging(["Content-Type": "application/json"]) { own, _ in own },
            body: #"{"numbers":[\#(numbers.map(String.init).joined(separator: ","))]}"#
        )
    }

    /// 넘길 글. 글자 수는 서버가 센 값이라 일부러 글의 길이와 다르게 둔다.
    static func handoff(_ numbers: [Int], missingSummaryCount: Int = 0) -> HandoffResult {
        HandoffResult(
            items: numbers.map(ref), charCount: 442, missingSummaryCount: missingSummaryCount,
            text: "<그렙_자료 건수=\"\(numbers.count)\">\n제목: 자료\n</그렙_자료>"
        )
    }

    static func handoffJSON(_ result: HandoffResult) -> String {
        let items = result.items.map { #"{"number":\#($0.number),"title":"\#($0.title)"}"# }.joined(separator: ",")
        let text = result.text.replacing("\"", with: "\\\"").replacing("\n", with: "\\n")
        return #"{"text":"\#(text)","charCount":\#(result.charCount),"items":[\#(items)],"#
            + #""missingSummaryCount":\#(result.missingSummaryCount)}"#
    }
}
