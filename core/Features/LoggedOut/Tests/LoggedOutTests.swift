import FeatureLoggedOutInterface
import FeatureLoggedOutTesting
import GrepCore
import GrepCoreTesting
import RIBs
import Testing

@testable import FeatureLoggedOut

@MainActor
private final class Dependency: LoggedOutDependency {
    let authService: any AuthService
    init(authService: any AuthService) { self.authService = authService }
}

/// LoggedOut 피처 단독 테스트(ACC-001 규칙 8·9). 부모와 다른 피처 없이 돈다.
@MainActor
final class LoggedOutTests {
    private let auth = FakeAuthService()
    private let views = FakeLoggedOutViewFactory()
    private let listener = FakeLoggedOutListener()
    private let parent = TestParentRouter()
    private var router: (any ViewableRouting)?

    isolated deinit {
        if let router { parent.detach(router) }
    }

    private var view: FakeLoggedOutView { views.views.last! }

    private func attach(notice: LoggedOutViewState.Notice? = nil) {
        let builder = LoggedOutBuilder(dependency: Dependency(authService: auth), viewFactory: views)
        let router = builder.build(listener: listener, notice: notice)
        parent.attach(router)
        self.router = router
    }

    private func tap(_ provider: AuthProvider) async {
        view.listener?.handle(.signInTapped(provider))
        await runCurrent()
    }

    @Test func 알림없이만들었을때_화면에붙으면_알림없는대기상태를그리는지() {
        // given
        let expected = [LoggedOutViewState()]

        // when
        attach()

        // then
        #expect(view.states == expected)
    }

    @Test func 만료알림으로만들었을때_화면에붙으면_만료알림을그리는지() {
        // given
        let expected = [LoggedOutViewState(notice: .expired)]

        // when
        attach(notice: .expired)

        // then
        #expect(view.states == expected)
    }

    @Test func 알림이떠있을때_로그인버튼을누르면_알림을지우고로그인창을여는지() async {
        // given
        attach(notice: .signedOut)

        // when
        await tap(.github)

        // then
        #expect(auth.signInRequests == [.github])
        #expect(view.state == LoggedOutViewState(notice: nil, isSigningIn: true))
    }

    @Test func 로그인창이열려있을때_버튼을다시누르면_창을하나더띄우지않는지() async {
        // given
        attach()
        await tap(.google)

        // when
        await tap(.github)

        // then
        #expect(auth.signInRequests == [.google])
    }

    @Test func 로그인창이열려있을때_로그인에성공하면_부모에게한번알리는지() async {
        // given
        attach()
        await tap(.google)

        // when
        auth.respond(.success)
        await runCurrent()

        // then
        #expect(listener.signInCount == 1)
        #expect(view.state == LoggedOutViewState())
    }

    @Test func 로그인창이열려있을때_사용자가창을닫으면_취소알림과대기상태를한번에그리는지() async {
        // given
        attach()
        await tap(.google)
        let rendersBeforeResponse = view.states.count

        // when
        auth.respond(.cancelled)
        await runCurrent()

        // then
        #expect(view.states.count == rendersBeforeResponse + 1)
        #expect(view.state == LoggedOutViewState(notice: .cancelled, isSigningIn: false))
        #expect(listener.signInCount == 0)
    }

    @Test(arguments: [SignInFailureReason.disconnected, .timedOut, .denied])
    func 로그인창이열려있을때_외부로그인이실패하면_이유와함께실패알림을그리는지(reason: SignInFailureReason) async {
        // given
        attach()
        await tap(.google)

        // when
        auth.respond(.failed(reason))
        await runCurrent()

        // then
        #expect(view.state == LoggedOutViewState(notice: .failed(reason), isSigningIn: false))
        #expect(listener.signInCount == 0)
    }

    @Test func 로그인에실패했을때_버튼을다시누르면_로그인창을다시여는지() async {
        // given
        attach()
        await tap(.google)
        auth.respond(.failed(.timedOut))
        await runCurrent()

        // when
        await tap(.google)

        // then
        #expect(auth.signInRequests == [.google, .google])
    }

    @Test func 로그인창이열려있을때_화면이떼어진뒤로그인에성공하면_부모에게알리지않고그리지도않는지() async {
        // given
        attach()
        await tap(.google)
        let rendersBeforeDetach = view.states.count

        // when
        parent.detach(router!)
        router = nil
        auth.respond(.success)
        await runCurrent()

        // then
        #expect(view.listener == nil)
        #expect(listener.signInCount == 0)
        #expect(view.states.count == rendersBeforeDetach)
    }
}
