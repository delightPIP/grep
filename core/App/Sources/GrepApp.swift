import FeatureArchive
import FeatureArchiveInterface
import FeatureLoggedIn
import FeatureLoggedInInterface
import FeatureLoggedOut
import FeatureLoggedOutInterface
import FeatureSettings
import FeatureSettingsInterface
import FeatureTerminal
import FeatureTerminalInterface
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
public protocol GrepAppViewFactory: LoggedOutViewFactory, TerminalViewFactory, ArchiveViewFactory, SettingsViewFactory {
    associatedtype RootView: RootViewControllable
    func makeRootView() -> RootView
}

/// 보관함·설정 화면을 아직 core 상태로 그리지 않는 플랫폼은 빈 뷰를 쓴다.
public extension GrepAppViewFactory {
    func makeArchiveView() -> any ArchiveViewContract { HeadlessArchiveView() }
    func makeSettingsView() -> any SettingsViewContract { HeadlessSettingsView() }
}

/// 플랫폼 진입점. `start`/`stop`으로 트리를 시작하고 끝낸다.
@MainActor
public final class GrepApp<Factory: GrepAppViewFactory> {
    private let router: RootRouter<Factory.RootView>

    public init(viewFactory: Factory, platform: PlatformServices) {
        let authService = platform.authService
        let component = RootComponent(platform: platform)
        router = RootRouter(
            interactor: RootInteractor(authService: authService),
            viewController: viewFactory.makeRootView(),
            loggedOutBuilder: LoggedOutBuilder(dependency: component, viewFactory: viewFactory),
            loggedInBuilder: LoggedInBuilder(
                dependency: component,
                terminalBuilder: TerminalBuilder(dependency: component, viewFactory: viewFactory),
                archiveBuilder: ArchiveBuilder(dependency: component, viewFactory: viewFactory),
                settingsBuilder: SettingsBuilder(dependency: component, viewFactory: viewFactory)
            )
        )
    }

    public func start(host: some ViewHost<Factory.RootView>) {
        router.launch(from: host)
    }

    public func stop() { router.shutdown() }
}
