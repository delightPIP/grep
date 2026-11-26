import FeatureLoggedInInterface
import FeatureLoggedInTesting
import GrepCore
import GrepCoreTesting
import RIBs
import Testing

@testable import FeatureLoggedIn

@MainActor
private final class Dependency: LoggedInDependency {
    let authService: any AuthService
    let httpTransport: any HTTPTransport
    init(authService: any AuthService, httpTransport: any HTTPTransport) {
        self.authService = authService
        self.httpTransport = httpTransport
    }
}

/// LoggedIn 피처 단독 테스트(ACC-001 규칙 6·7, COM-009 규칙 2). 부모와 다른 피처 없이 돈다.
@MainActor
final class LoggedInTests {
    private static let meJSON = #"{"userId":"6f1c0a52-0000-4000-8000-000000000001","authProvider":"google","itemCount":34}"#

    private static let tokenA = fakeAccessToken(subject: "user-a")
    private let auth = FakeAuthService(token: LoggedInTests.tokenA)
    private let transport = FakeHTTPTransport()
    private let views = FakeLoggedInViewFactory()
    private let listener = FakeLoggedInListener()
    private let parent = TestParentRouter()
    private var router: (any ViewableRouting)?

    isolated deinit {
        if let router { parent.detach(router) }
    }

    private var view: FakeLoggedInView { views.views.last! }

    private func attach(pendingInput: PendingInput? = nil) async {
        let dependency = Dependency(authService: auth, httpTransport: transport)
        let builder = LoggedInBuilder(dependency: dependency, viewFactory: views)
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
    }

    private func send(_ action: LoggedInViewAction) async {
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
        #expect(view.states == [LoggedInViewState()])
        #expect(transport.requests == [expectedRequest])
    }

    @Test func 같은계정의되살릴줄과함께만들었을때_화면에붙으면_입력줄에그줄을그리는지() async {
        // given
        let restored = PendingInput(text: "찾기 결제", subject: "user-a")

        // when
        await attach(pendingInput: restored)

        // then
        #expect(view.state == LoggedInViewState(input: "찾기 결제"))
    }

    @Test func 다른계정의되살릴줄과함께만들었을때_화면에붙으면_입력줄을비워두는지() async {
        // given
        let restored = PendingInput(text: "찾기 결제", subject: "user-b")

        // when
        await attach(pendingInput: restored)

        // then
        #expect(view.state == LoggedInViewState())
    }

    @Test func me를기다릴때_서버가자료수를주면_상태줄에그수를그리는지() async {
        // given
        await attach()

        // when
        transport.respond(json: Self.meJSON)
        await runCurrent()

        // then
        #expect(view.state == LoggedInViewState(itemCount: 34))
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
    func me를기다릴때_응답을받지못하면_자료수없이터미널을그대로두는지(error: HTTPTransportError) async {
        // given
        await attach()

        // when
        transport.respond(.failure(error))
        await runCurrent()

        // then
        #expect(view.states == [LoggedInViewState()])
        #expect(listener.expiredInputs.isEmpty)
    }

    @Test func me를기다릴때_본문이계약과다르면_자료수없이터미널을그대로두는지() async {
        // given
        await attach()

        // when
        transport.respond(json: #"{"itemCount":"many"}"#)
        await runCurrent()

        // then
        #expect(view.states == [LoggedInViewState()])
    }

    // MARK: 입력

    @Test func 터미널이떠있을때_입력줄이바뀌면_바뀐줄을그리는지() async {
        // given
        await attachLoaded()

        // when
        await send(.inputChanged("찾"))

        // then
        #expect(view.state == LoggedInViewState(itemCount: 34, input: "찾"))
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

    @Test func 터미널이떠있을때_logout을치면_로그아웃하지않고없는명령으로그리는지() async {
        // given
        await attachLoaded()
        await send(.inputChanged("logout"))

        // when
        await send(.submitted("logout"))

        // then
        #expect(auth.signOutCount == 0)
        #expect(listener.signOutCount == 0)
        #expect(view.state == LoggedInViewState(itemCount: 34, lines: [.prompt("logout"), .unknownCommand("logout")], input: ""))
    }

    @Test func 터미널이떠있을때_인자가붙은없는명령을치면_첫낱말을명령이름으로그리는지() async {
        // given
        await attachLoaded()

        // when
        await send(.submitted("찻기 결제"))

        // then
        #expect(view.state?.lines == [.prompt("찻기 결제"), .unknownCommand("찻기")])
    }

    @Test func 없는명령을한번쳤을때_다시없는명령을치면_앞출력뒤에이어서그리는지() async {
        // given
        await attachLoaded()
        await send(.submitted("찻기"))

        // when
        await send(.submitted("최근"))

        // then
        #expect(view.state?.lines == [.prompt("찻기"), .unknownCommand("찻기"), .prompt("최근"), .unknownCommand("최근")])
    }

    @Test func 터미널이떠있을때_빈줄에서엔터를치면_아무것도그리지않는지() async {
        // given
        await attachLoaded()
        let rendersBefore = view.states.count

        // when
        await send(.submitted("   "))

        // then
        #expect(view.states.count == rendersBefore)
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
}
