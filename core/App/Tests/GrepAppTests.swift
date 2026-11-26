import FeatureLoggedInInterface
import FeatureLoggedInTesting
import FeatureLoggedOutInterface
import FeatureLoggedOutTesting
import GrepAppRoot
import GrepCore
import GrepCoreTesting
import RIBs
import Testing

@MainActor
final class FakeRootView: RootViewControllable {
    var screen: (any ViewControllable)?
    func showScreen(_ screen: any ViewControllable) { self.screen = screen }
    func hideScreen(_ screen: any ViewControllable) { if self.screen === screen { self.screen = nil } }
}

/// 피처별 가짜 팩토리를 묶어 앱 전체 팩토리로 쓴다.
@MainActor
final class FakeAppViewFactory: GrepAppViewFactory {
    let root = FakeRootView()
    let loggedOut = FakeLoggedOutViewFactory()
    let loggedIn = FakeLoggedInViewFactory()

    func makeRootView() -> FakeRootView { root }
    func makeLoggedOutView() -> any LoggedOutViewContract { loggedOut.makeLoggedOutView() }
    func makeLoggedInView() -> any LoggedInViewContract { loggedIn.makeLoggedInView() }
}

@MainActor
final class FakeHost: ViewHost {
    var shown: FakeRootView?
    func show(_ view: FakeRootView) { shown = view }
    func hide(_ view: FakeRootView) { shown = nil }
}

/// 실제 피처 Impl을 모두 이은 통합 테스트. 로그인 → 터미널 → 로그아웃·만료 흐름을 본다.
@MainActor
final class GrepAppTests {
    private static let meJSON = #"{"userId":"6f1c0a52-0000-4000-8000-000000000001","authProvider":"google","itemCount":34}"#
    private static let sessionExpiredJSON = #"{"code":"session_expired"}"#

    private let factory = FakeAppViewFactory()
    private let host = FakeHost()
    private let auth = FakeAuthService()
    private let transport = FakeHTTPTransport()
    private let app: GrepApp<FakeAppViewFactory>

    init() {
        app = GrepApp(viewFactory: factory, authService: auth, httpTransport: transport)
    }

    isolated deinit {
        app.stop()
    }

    private var loggedOut: FakeLoggedOutView { factory.loggedOut.views.last! }
    private var loggedIn: FakeLoggedInView { factory.loggedIn.views.last! }

    private func start() async {
        app.start(host: host)
        await runCurrent()
    }

    private func signIn(as subject: String = "user-a") async {
        loggedOut.listener?.handle(.signInTapped(.google))
        await runCurrent()
        auth.respond(.success, token: fakeAccessToken(subject: subject))
        await runCurrent()
    }

    /// 로그인하고 `/me` 응답까지 받은 터미널 화면.
    private func startSignedIn() async {
        await start()
        await signIn()
        transport.respond(json: Self.meJSON)
        await runCurrent()
    }

    @Test func 이기기에세션이없을때_앱을시작하면_로그인화면만보이는지() async {
        // given
        auth.token = nil

        // when
        await start()

        // then
        #expect(host.shown === factory.root)
        #expect(factory.root.screen === loggedOut)
        #expect(loggedOut.state == LoggedOutViewState())
        #expect(factory.loggedIn.views.isEmpty)
        #expect(transport.requests.isEmpty)
    }

    @Test func 이기기에세션이남아있을때_앱을시작하면_로그인화면없이터미널이보이는지() async {
        // given
        auth.token = "token-a"

        // when
        await start()

        // then
        #expect(factory.root.screen === loggedIn)
        #expect(factory.loggedOut.views.isEmpty)
    }

    @Test func 로그인화면이떠있을때_로그인에성공하면_터미널로바뀌고자료수를그리는지() async {
        // given
        await start()

        // when
        await signIn()
        transport.respond(json: Self.meJSON)
        await runCurrent()

        // then
        #expect(factory.root.screen === loggedIn)
        #expect(loggedIn.state == LoggedInViewState(itemCount: 34))
        #expect(loggedOut.listener == nil)
    }

    @Test func 터미널에출력이있을때_로그아웃을치면_로그아웃알림과함께로그인화면으로바뀌는지() async {
        // given
        await startSignedIn()
        loggedIn.listener?.handle(.submitted("찻기"))

        // when
        loggedIn.listener?.handle(.submitted("로그아웃"))
        await runCurrent()

        // then
        #expect(factory.root.screen === loggedOut)
        #expect(loggedOut.state == LoggedOutViewState(notice: .signedOut))
        #expect(auth.signOutCount == 1)
    }

    @Test func 로그아웃한뒤일때_다시로그인하면_앞출력과치던줄없이빈터미널이보이는지() async {
        // given
        await startSignedIn()
        loggedIn.listener?.handle(.submitted("찻기"))
        loggedIn.listener?.handle(.inputChanged("찾기 결제"))
        loggedIn.listener?.handle(.submitted("signout"))
        await runCurrent()

        // when
        await signIn()

        // then
        #expect(factory.loggedIn.views.count == 2)
        #expect(loggedIn.state == LoggedInViewState())
    }

    @Test func 입력줄에글을치던중일때_세션이만료되면_만료알림과함께로그인화면으로바뀌는지() async {
        // given
        await start()
        await signIn()
        loggedIn.listener?.handle(.inputChanged("찾기 온보"))

        // when
        transport.respond(status: 401, json: Self.sessionExpiredJSON)
        await runCurrent()

        // then
        #expect(factory.root.screen === loggedOut)
        #expect(loggedOut.state == LoggedOutViewState(notice: .expired))
        // 서버가 거부한 세션을 이 기기에 남기지 않는다(새로 고침해도 다시 만료 화면으로 가도록).
        #expect(auth.signOutCount == 1)
    }

    @Test func 계정A가치던줄을남기고만료됐을때_계정B로로그인하면_그줄을되살리지않는지() async {
        // given
        await start()
        await signIn(as: "user-a")
        loggedIn.listener?.handle(.inputChanged("찾기 온보"))
        transport.respond(status: 401, json: Self.sessionExpiredJSON)
        await runCurrent()

        // when
        await signIn(as: "user-b")

        // then
        #expect(factory.root.screen === loggedIn)
        #expect(loggedIn.state == LoggedInViewState())
    }

    @Test func 치던줄을남기고만료됐을때_다시로그인하면_입력줄에그줄을되살리는지() async {
        // given
        await start()
        await signIn()
        loggedIn.listener?.handle(.inputChanged("찾기 온보"))
        transport.respond(status: 401, json: Self.sessionExpiredJSON)
        await runCurrent()

        // when
        await signIn()

        // then
        #expect(factory.root.screen === loggedIn)
        #expect(loggedIn.state == LoggedInViewState(input: "찾기 온보"))
    }

    @Test func 만료뒤되살린줄이있을때_로그아웃하고다시로그인하면_그줄을다시되살리지않는지() async {
        // given
        await start()
        await signIn()
        loggedIn.listener?.handle(.inputChanged("찾기 온보"))
        transport.respond(status: 401, json: Self.sessionExpiredJSON)
        await runCurrent()
        await signIn()
        loggedIn.listener?.handle(.submitted("로그아웃"))
        await runCurrent()

        // when
        await signIn()

        // then
        #expect(loggedIn.state == LoggedInViewState())
    }

    @Test func 터미널이떠있을때_앱을멈추면_화면을내리고입력을끊는지() async {
        // given
        await startSignedIn()
        let terminal = loggedIn

        // when
        app.stop()

        // then
        #expect(host.shown == nil)
        #expect(terminal.listener == nil)
    }
}
