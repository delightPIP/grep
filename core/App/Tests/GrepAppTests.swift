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

    private func signIn() async {
        loggedOut.listener?.handle(.signInTapped(.google))
        await runCurrent()
        auth.respond(.success)
        await runCurrent()
    }

    /// 로그인하고 `/me` 응답까지 받은 터미널 화면.
    private func startSignedIn() async {
        await start()
        await signIn()
        transport.respond(json: Self.meJSON)
        await runCurrent()
    }

    @Test func 이_기기에_세션이_없을때_앱을_시작하면_로그인화면만_보이는지() async {
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

    @Test func 이_기기에_세션이_남아있을때_앱을_시작하면_로그인화면없이_터미널이_보이는지() async {
        // given
        auth.token = "token-a"

        // when
        await start()

        // then
        #expect(factory.root.screen === loggedIn)
        #expect(factory.loggedOut.views.isEmpty)
    }

    @Test func 로그인화면이_떠있을때_로그인에_성공하면_터미널로_바뀌고_자료수를_그리는지() async {
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

    @Test func 터미널에_출력이_있을때_로그아웃을_치면_로그아웃알림과_함께_로그인화면으로_바뀌는지() async {
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

    @Test func 로그아웃한_뒤일때_다시_로그인하면_앞_출력과_치던_줄없이_빈_터미널이_보이는지() async {
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

    @Test func 입력줄에_글을_치던중일때_세션이_만료되면_만료알림과_함께_로그인화면으로_바뀌는지() async {
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
        #expect(auth.signOutCount == 0)
    }

    @Test func 치던_줄을_남기고_만료됐을때_다시_로그인하면_입력줄에_그_줄을_되살리는지() async {
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

    @Test func 만료뒤_되살린_줄이_있을때_로그아웃하고_다시_로그인하면_그_줄을_다시_되살리지않는지() async {
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

    @Test func 터미널이_떠있을때_앱을_멈추면_화면을_내리고_입력을_끊는지() async {
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
