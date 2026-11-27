import FeatureLoggedOutAndroid
import FeatureLoggedOutInterface
import FeatureTerminalAndroid
import FeatureTerminalInterface
import GrepAndroidSupport
import GrepAppRoot
import GrepCore
import RIBs
import RIBsAndroid

extension HostRootScreen: RootViewControllable {}

/// 피처별 Android 뷰 팩토리를 모아 `GrepAppViewFactory`를 채운다.
@MainActor
final class AndroidAppViewFactory: GrepAppViewFactory {
    private let context: ScreenContext
    private let loggedOut: LoggedOutAndroidViewFactory
    private let terminal: TerminalAndroidViewFactory

    init(context: ScreenContext) {
        self.context = context
        loggedOut = LoggedOutAndroidViewFactory(context: context)
        terminal = TerminalAndroidViewFactory(context: context)
    }

    func makeRootView() -> HostRootScreen { HostRootScreen(context: context) }
    func makeLoggedOutView() -> any LoggedOutViewContract { loggedOut.makeLoggedOutView() }
    func makeTerminalView() -> any TerminalViewContract { terminal.makeTerminalView() }
}

/// 전체 앱. `GrepAppRoot`의 `GrepApp`을 Android 렌더러에 붙인다.
@MainActor
public final class GrepAppController: RibController {
    private let stack: RenderStack
    private let app: GrepApp<AndroidAppViewFactory>

    public init(platform: PlatformServices, sink: @escaping (String) -> Void) {
        stack = RenderStack(sink: sink)
        app = GrepApp(
            viewFactory: AndroidAppViewFactory(context: stack.context),
            platform: platform
        )
    }

    public func start() {
        app.start(host: stack.host)
    }

    public func screen<Screen: AndroidScreen>(id: Int64, as type: Screen.Type) -> Screen? {
        stack.registry.screen(id: id, as: type)
    }

    public func stop() { app.stop() }
    public var encodedTree: String { stack.renderer.encodedTree }
}
