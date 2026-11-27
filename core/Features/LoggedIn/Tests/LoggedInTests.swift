#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FeatureLoggedInInterface
import FeatureLoggedInTesting
import FeatureTerminal
import FeatureTerminalInterface
import FeatureTerminalTesting
import GrepCore
import GrepCoreTesting
import RIBs
import Testing

@testable import FeatureLoggedIn

@MainActor
private final class Dependency: LoggedInDependency, TerminalDependency {
    let authService: any AuthService
    let httpTransport: any HTTPTransport
    let clipboard: any ClipboardPort = FakeClipboard()
    let files: any FilePort
    let historyStore: any HistoryStore = FakeHistoryStore()
    let sleeper: any Sleeper = FakeSleeper()
    init(authService: any AuthService, httpTransport: any HTTPTransport, files: any FilePort) {
        self.authService = authService
        self.httpTransport = httpTransport
        self.files = files
    }
}

/// LoggedIn 컨테이너 테스트(ACC-001 규칙 6·7, COM-009 규칙 2). 자식으로 실제 Terminal을 붙여, 컨테이너가 넘긴 값이 화면에 닿는지까지 본다.
@MainActor
final class LoggedInTests {
    private static let meJSON = #"{"userId":"6f1c0a52-0000-4000-8000-000000000001","authProvider":"google","itemCount":34}"#

    private static let tokenA = fakeAccessToken(subject: "user-a")
    private static let noNoticesJSON = #"{"ended":[]}"#
    private let auth = FakeAuthService(token: LoggedInTests.tokenA)
    private let transport = FakeHTTPTransport()
    private let files = FakeFilePort()
    private let views = FakeTerminalViewFactory()
    private let listener = FakeLoggedInListener()
    private let parent = TestParentRouter()
    private var router: (any ViewableRouting)?

    isolated deinit {
        if let router { parent.detach(router) }
    }

    private var view: FakeTerminalView { views.views.last! }

    private func attach(pendingInput: PendingInput? = nil) async {
        let dependency = Dependency(authService: auth, httpTransport: transport, files: files)
        let builder = LoggedInBuilder(
            dependency: dependency,
            terminalBuilder: TerminalBuilder(dependency: dependency, viewFactory: views)
        )
        let router = builder.build(listener: listener, pendingInput: pendingInput)
        parent.attach(router)
        self.router = router
        await runCurrent()
    }

    /// `/me` 응답까지 받은 터미널 화면.
    private func attachLoaded() async {
        await attach()
        transport.respond(json: Self.meJSON)
        await runCurrent()
        transport.respond(json: Self.noNoticesJSON)
        await runCurrent()
    }

    private func send(_ action: TerminalViewAction) async {
        view.listener?.handle(action)
        await runCurrent()
    }

    // MARK: 화면 진입과 /me

    @Test func 되살릴줄없이만들었을때_화면에붙으면_빈터미널을그리고토큰을붙여me를요청하는지() async {
        // given
        let expectedRequest = HTTPRequest(method: .get, path: "/me", headers: ["Authorization": "Bearer \(Self.tokenA)"])

        // when
        await attach()

        // then
        #expect(view.states == [TerminalViewState()])
        #expect(transport.requests == [expectedRequest])
    }

    @Test func 같은계정의되살릴줄과함께만들었을때_화면에붙으면_입력줄에그줄을그리는지() async {
        // given
        let restored = PendingInput(text: "찾기 결제", subject: "user-a")

        // when
        await attach(pendingInput: restored)

        // then
        #expect(view.state == TerminalViewState(input: "찾기 결제"))
    }

    @Test func 다른계정의되살릴줄과함께만들었을때_화면에붙으면_입력줄을비워두는지() async {
        // given
        let restored = PendingInput(text: "찾기 결제", subject: "user-b")

        // when
        await attach(pendingInput: restored)

        // then
        #expect(view.state == TerminalViewState())
    }

    @Test func me를기다릴때_서버가자료수를주면_상태줄에그수를그리는지() async {
        // given
        await attach()

        // when
        transport.respond(json: Self.meJSON)
        await runCurrent()

        // then
        #expect(view.state == TerminalViewState(itemCount: 34))
        #expect(listener.expiredInputs.isEmpty)
    }

    @Test func 접근토큰을받지못할때_화면에붙으면_요청없이만료를알리는지() async {
        // given
        auth.token = nil

        // when
        let restored = PendingInput(text: "찾기 결제", subject: "user-a")
        await attach(pendingInput: restored)

        // then
        #expect(transport.requests.isEmpty)
        #expect(listener.expiredPending == [restored])
    }

    @Test func 입력줄에글을치던중일때_서버가세션만료로답하면_치던줄과함께만료를알리는지() async {
        // given
        await attach()
        await send(.inputChanged("찾기 온보"))

        // when
        transport.respond(status: 401, json: #"{"code":"session_expired"}"#)
        await runCurrent()

        // then
        #expect(listener.expiredPending == [PendingInput(text: "찾기 온보", subject: "user-a")])
    }

    @Test func me를기다릴때_서버가세션만료가아닌401로답하면_만료로보지않는지() async {
        // given
        await attach()

        // when
        transport.respond(status: 401, json: #"{"code":"unauthorized"}"#)
        await runCurrent()

        // then
        #expect(listener.expiredInputs.isEmpty)
        #expect(view.state?.itemCount == nil)
    }

    @Test(arguments: [HTTPTransportError.unreachable, .timedOut])
    func me를기다릴때_응답을받지못하면_자료수없이두고네트워크오류일때만연결끊김을두는지(error: HTTPTransportError) async {
        // given: 네트워크 오류일 때만 상태줄에 `연결 끊김`을 둔다(COM-010 규칙 3)
        let expected = error == .unreachable
            ? [TerminalViewState(), TerminalViewState(isOffline: true)]
            : [TerminalViewState()]
        await attach()

        // when
        transport.respond(.failure(error))
        await runCurrent()

        // then
        #expect(view.states == expected)
        #expect(listener.expiredInputs.isEmpty)
    }

    @Test func me를기다릴때_본문이계약과다르면_자료수없이터미널을그대로두는지() async {
        // given
        await attach()

        // when
        transport.respond(json: #"{"itemCount":"many"}"#)
        await runCurrent()

        // then
        #expect(view.states == [TerminalViewState()])
    }

    @Test(arguments: ["로그아웃", "signout", "  로그아웃 "])
    func 터미널이떠있을때_로그아웃명령을치면_세션을끝내고부모에게알리는지(command: String) async {
        // given
        await attachLoaded()

        // when
        await send(.submitted(command))

        // then
        #expect(auth.signOutCount == 1)
        #expect(listener.signOutCount == 1)
    }

    @Test func me를기다리는중에로그아웃을쳤을때_서버가세션만료로답하면_만료가아니라로그아웃으로알리는지() async {
        // given
        await attach()
        await send(.submitted("로그아웃"))

        // when
        transport.respond(status: 401, json: #"{"code":"session_expired"}"#)
        await runCurrent()

        // then
        #expect(listener.signOutCount == 1)
        #expect(listener.expiredInputs.isEmpty)
    }

    // MARK: 생명주기

    @Test func me를기다릴때_화면이떼어지면_입력을끊고늦은응답을그리지않는지() async {
        // given
        await attach()
        let rendersBefore = view.states.count

        // when
        parent.detach(router!)
        router = nil
        transport.respond(json: Self.meJSON)
        await runCurrent()

        // then
        #expect(view.listener == nil)
        #expect(view.states.count == rendersBefore)
        #expect(listener.expiredInputs.isEmpty)
    }
    // MARK: 터미널이 올린 일

    @Test func 터미널이명령을기다릴때_서버가세션만료로답하면_친줄과계정을묶어만료를알리는지() async {
        // given
        await attachLoaded()
        await send(.submitted("최근"))

        // when
        transport.respond(status: 401, json: #"{"code":"session_expired"}"#)
        await runCurrent()

        // then
        #expect(listener.expiredPending == [PendingInput(text: "최근", subject: "user-a")])
    }

    @Test func 로그아웃을한번쳤을때_또치면_세션을한번만끝내는지() async {
        // given
        await attachLoaded()
        await send(.submitted("로그아웃"))

        // when
        await send(.submitted("로그아웃"))

        // then
        #expect(auth.signOutCount == 1)
        #expect(listener.signOutCount == 1)
    }

    // MARK: AI 도구 연결(#124, ACC-002)

    @Test func 자료수를받았을때_끊긴연결알림이있으면_터미널에연결끊김줄을찍는지() async {
        // given
        await attach()
        transport.respond(json: Self.meJSON)
        await runCurrent()

        // when
        transport.respond(json: #"{"ended":[{"client":"Claude","reason":"expired"}]}"#)
        await runCurrent()

        // then
        #expect(transport.requests.last?.method == .post)
        #expect(transport.requests.last?.path == "/connections/notices")
        #expect(view.state?.lines.last == .connectionEnded(client: "Claude", reason: .expired))
    }

    @Test func 로그아웃모든기기를확인했을때_연결을모두끊은뒤에전역로그아웃하는지() async {
        // given
        await attachLoaded()
        await send(.submitted("로그아웃 모든기기"))
        transport.respond(json: #"{"mcpUrl":"https://grep.example/mcp","connections":[]}"#)
        await runCurrent()

        // when
        await send(.submitted("로그아웃"))
        let signOutsBeforeRevoke = auth.signOutCount
        transport.respond(json: #"{"count":0}"#)
        await runCurrent()

        // then
        #expect(transport.requests.last?.path == "/connections/revoke-all")
        #expect(signOutsBeforeRevoke == 0)
        #expect(auth.signOutCount == 1)
    }
}
