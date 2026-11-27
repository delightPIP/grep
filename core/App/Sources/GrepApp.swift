import FeatureLoggedIn
import FeatureLoggedInInterface
import FeatureLoggedOut
import FeatureLoggedOutInterface
import GrepCore
import RIBs

/// 조립 모듈. 피처 Impl을 아는 곳은 여기 하나다.

/// 루트 뷰 계약. 자식 RIB 화면 하나를 보여 준다. 플랫폼이 구현한다.
@MainActor
public protocol RootViewControllable: ViewControllable {
    func showScreen(_ screen: any ViewControllable)
    func hideScreen(_ screen: any ViewControllable)
}

/// 플랫폼이 구현하는 앱 전체 뷰 팩토리. 피처별 팩토리를 모두 따른다.
/// 루트 뷰만 연관 타입이다. `LaunchRouter`·`ViewHost`가 구체 뷰 타입을 요구한다.
@MainActor
public protocol GrepAppViewFactory: LoggedOutViewFactory, LoggedInViewFactory {
    associatedtype RootView: RootViewControllable
    func makeRootView() -> RootView
}

/// 플랫폼 진입점. `start`/`stop`으로 트리를 시작하고 끝낸다.
@MainActor
public final class GrepApp<Factory: GrepAppViewFactory> {
    private let router: RootRouter<Factory.RootView>

    public init(viewFactory: Factory, authService: any AuthService, httpTransport: any HTTPTransport) {
        let component = RootComponent(authService: authService, httpTransport: httpTransport)
        router = RootRouter(
            interactor: RootInteractor(authService: authService),
            viewController: viewFactory.makeRootView(),
            loggedOutBuilder: LoggedOutBuilder(dependency: component, viewFactory: viewFactory),
            loggedInBuilder: LoggedInBuilder(dependency: component, viewFactory: viewFactory)
        )
    }

    public func start(host: some ViewHost<Factory.RootView>) {
        router.launch(from: host)
    }

    public func stop() { router.shutdown() }
}

/// 피처 Dependency를 모두 채운다.
final class RootComponent: EmptyComponent, LoggedOutDependency, LoggedInDependency {
    let authService: any AuthService
    let httpTransport: any HTTPTransport

    init(authService: any AuthService, httpTransport: any HTTPTransport) {
        self.authService = authService
        self.httpTransport = httpTransport
        super.init()
    }
}

@MainActor
protocol RootRouting: AnyObject {
    func routeToLoggedOut(notice: LoggedOutViewState.Notice?)
    func routeAwayFromLoggedOut()
    func routeToLoggedIn(pendingInput: PendingInput?)
    func routeAwayFromLoggedIn()
}

/// 로그인 여부에 따라 로그인 화면과 터미널 화면 중 하나를 붙인다(ACC-001 규칙 1).
final class RootInteractor: Interactor, LoggedOutListener, LoggedInListener {
    weak var router: (any RootRouting)?
    private let authService: any AuthService
    /// 로그인 만료 때 입력줄에 치던 줄과 그 계정. 같은 계정으로 다시 로그인하면 되살린다(ACC-001 규칙 7).
    private var pendingInput: PendingInput?

    init(authService: any AuthService) {
        self.authService = authService
        super.init()
    }

    /// 이 기기에 세션이 남아 있으면 로그인 화면을 건너뛴다(COM-009 규칙 1).
    override func didBecomeActive() {
        startTask { [weak self] in
            guard let self else { return }
            let hasSession = await authService.accessToken() != nil
            guard !Task.isCancelled else { return }
            if hasSession {
                router?.routeToLoggedIn(pendingInput: nil)
            } else {
                router?.routeToLoggedOut(notice: nil)
            }
        }
    }

    func didSignIn() {
        let restored = pendingInput
        pendingInput = nil
        router?.routeAwayFromLoggedOut()
        router?.routeToLoggedIn(pendingInput: restored)
    }

    /// 터미널 화면을 떼면 출력과 치던 줄이 함께 사라진다(COM-009 규칙 2).
    func didSignOut() {
        pendingInput = nil
        router?.routeAwayFromLoggedIn()
        router?.routeToLoggedOut(notice: .signedOut)
    }

    /// 서버가 거부한 세션을 이 기기에서도 지운다. 남겨 두면 새로 고침할 때 터미널이 잠깐 떴다가 다시 만료로 간다.
    /// 지운 뒤에 로그인 화면을 붙여, 새 로그인이 늦게 끝난 로그아웃에 지워지지 않게 한다.
    func didExpire(pendingInput: PendingInput?) {
        self.pendingInput = pendingInput
        router?.routeAwayFromLoggedIn()
        startTask { [weak self] in
            guard let self else { return }
            await authService.signOut()
            guard !Task.isCancelled else { return }
            router?.routeToLoggedOut(notice: .expired)
        }
    }
}

final class RootRouter<RootView: RootViewControllable>: LaunchRouter<RootInteractor, RootView>, RootRouting {
    private let loggedOutBuilder: any LoggedOutBuildable
    private let loggedInBuilder: any LoggedInBuildable
    private var loggedOut: (any ViewableRouting)?
    private var loggedIn: (any ViewableRouting)?

    init(
        interactor: RootInteractor,
        viewController: RootView,
        loggedOutBuilder: any LoggedOutBuildable,
        loggedInBuilder: any LoggedInBuildable
    ) {
        self.loggedOutBuilder = loggedOutBuilder
        self.loggedInBuilder = loggedInBuilder
        super.init(interactor: interactor, viewController: viewController)
        interactor.router = self
    }

    func routeToLoggedOut(notice: LoggedOutViewState.Notice?) {
        guard loggedOut == nil else { return }
        let child = loggedOutBuilder.build(listener: interactor, notice: notice)
        attachChild(child)
        viewController.showScreen(child.viewControllable)
        loggedOut = child
    }

    func routeAwayFromLoggedOut() {
        guard let child = loggedOut else { return }
        detachChild(child)
        viewController.hideScreen(child.viewControllable)
        loggedOut = nil
    }

    func routeToLoggedIn(pendingInput: PendingInput?) {
        guard loggedIn == nil else { return }
        let child = loggedInBuilder.build(listener: interactor, pendingInput: pendingInput)
        attachChild(child)
        viewController.showScreen(child.viewControllable)
        loggedIn = child
    }

    func routeAwayFromLoggedIn() {
        guard let child = loggedIn else { return }
        detachChild(child)
        viewController.hideScreen(child.viewControllable)
        loggedIn = nil
    }
}
