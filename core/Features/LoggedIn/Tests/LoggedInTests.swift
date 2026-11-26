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

    private let auth = FakeAuthService(token: "token-a")
    private let transport = FakeHTTPTransport()
    private let views = FakeLoggedInViewFactory()
    private let listener = FakeLoggedInListener()
    private let parent = TestParentRouter()
    private var router: (any ViewableRouting)?

    isolated deinit {
        if let router { parent.detach(router) }
    }

    private var view: FakeLoggedInView { views.views.last! }

    private func attach(restoredInput: String = "") async {
        let dependency = Dependency(authService: auth, httpTransport: transport)
        let builder = LoggedInBuilder(dependency: dependency, viewFactory: views)
        let router = builder.build(listener: listener, restoredInput: restoredInput)
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

    @Test func 되살릴_줄없이_만들었을때_화면에_붙으면_빈_터미널을_그리고_토큰을_붙여_me를_요청하는지() async {
        // given
        let expectedRequest = HTTPRequest(method: .get, path: "/me", headers: ["Authorization": "Bearer token-a"])

        // when
        await attach()

        // then
        #expect(view.states == [LoggedInViewState()])
        #expect(transport.requests == [expectedRequest])
    }

    @Test func 되살릴_줄과_함께_만들었을때_화면에_붙으면_입력줄에_그_줄을_그리는지() async {
        // given
        let restored = "찾기 결제"

        // when
        await attach(restoredInput: restored)

        // then
        #expect(view.state == LoggedInViewState(input: restored))
    }

    @Test func me를_기다릴때_서버가_자료수를_주면_상태줄에_그_수를_그리는지() async {
        // given
        await attach()

        // when
        transport.respond(json: Self.meJSON)
        await runCurrent()

        // then
        #expect(view.state == LoggedInViewState(itemCount: 34))
        #expect(listener.expiredInputs.isEmpty)
    }

    @Test func 접근토큰을_받지못할때_화면에_붙으면_요청없이_만료를_알리는지() async {
        // given
        auth.token = nil

        // when
        await attach(restoredInput: "찾기 결제")

        // then
        #expect(transport.requests.isEmpty)
        #expect(listener.expiredInputs == ["찾기 결제"])
    }

    @Test func 입력줄에_글을_치던중일때_서버가_세션만료로_답하면_치던_줄과_함께_만료를_알리는지() async {
        // given
        await attach()
        await send(.inputChanged("찾기 온보"))

        // when
        transport.respond(status: 401, json: #"{"code":"session_expired"}"#)
        await runCurrent()

        // then
        #expect(listener.expiredInputs == ["찾기 온보"])
    }

    @Test func me를_기다릴때_서버가_세션만료가_아닌_401로_답하면_만료로_보지않는지() async {
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
    func me를_기다릴때_응답을_받지못하면_자료수없이_터미널을_그대로_두는지(error: HTTPTransportError) async {
        // given
        await attach()

        // when
        transport.respond(.failure(error))
        await runCurrent()

        // then
        #expect(view.states == [LoggedInViewState()])
        #expect(listener.expiredInputs.isEmpty)
    }

    @Test func me를_기다릴때_본문이_계약과_다르면_자료수없이_터미널을_그대로_두는지() async {
        // given
        await attach()

        // when
        transport.respond(json: #"{"itemCount":"many"}"#)
        await runCurrent()

        // then
        #expect(view.states == [LoggedInViewState()])
    }

    // MARK: 입력

    @Test func 터미널이_떠있을때_입력줄이_바뀌면_바뀐_줄을_그리는지() async {
        // given
        await attachLoaded()

        // when
        await send(.inputChanged("찾"))

        // then
        #expect(view.state == LoggedInViewState(itemCount: 34, input: "찾"))
    }

    @Test(arguments: ["로그아웃", "signout", "  로그아웃 "])
    func 터미널이_떠있을때_로그아웃명령을_치면_세션을_끝내고_부모에게_알리는지(command: String) async {
        // given
        await attachLoaded()

        // when
        await send(.submitted(command))

        // then
        #expect(auth.signOutCount == 1)
        #expect(listener.signOutCount == 1)
    }

    @Test func 터미널이_떠있을때_logout을_치면_로그아웃하지않고_없는명령으로_그리는지() async {
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

    @Test func 터미널이_떠있을때_인자가_붙은_없는명령을_치면_첫_낱말을_명령이름으로_그리는지() async {
        // given
        await attachLoaded()

        // when
        await send(.submitted("찻기 결제"))

        // then
        #expect(view.state?.lines == [.prompt("찻기 결제"), .unknownCommand("찻기")])
    }

    @Test func 없는명령을_한번_쳤을때_다시_없는명령을_치면_앞_출력뒤에_이어서_그리는지() async {
        // given
        await attachLoaded()
        await send(.submitted("찻기"))

        // when
        await send(.submitted("최근"))

        // then
        #expect(view.state?.lines == [.prompt("찻기"), .unknownCommand("찻기"), .prompt("최근"), .unknownCommand("최근")])
    }

    @Test func 터미널이_떠있을때_빈_줄에서_엔터를_치면_아무것도_그리지않는지() async {
        // given
        await attachLoaded()
        let rendersBefore = view.states.count

        // when
        await send(.submitted("   "))

        // then
        #expect(view.states.count == rendersBefore)
    }

    @Test func me를_기다리는중에_로그아웃을_쳤을때_서버가_세션만료로_답하면_만료가_아니라_로그아웃으로_알리는지() async {
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

    @Test func me를_기다릴때_화면이_떼어지면_입력을_끊고_늦은_응답을_그리지않는지() async {
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
