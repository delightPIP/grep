import FeatureTerminalInterface
import FeatureTerminalWeb
import FeatureLoggedOutInterface
import FeatureLoggedOutWeb
import GrepAppRoot
import GrepWebSupport
import JavaScriptKit
import RIBsWeb

extension RootScreen: RootViewControllable {}

/// 전체 앱의 뷰 팩토리. 피처별 웹 뷰 팩토리를 모은다.
@MainActor
final class WebViewFactory: GrepAppViewFactory {
    private let loggedOut: LoggedOutWebViewFactory
    private let loggedIn: TerminalWebViewFactory

    init(loggedOut: LoggedOutWebViewFactory, loggedIn: TerminalWebViewFactory) {
        self.loggedOut = loggedOut
        self.loggedIn = loggedIn
    }

    func makeRootView() -> RootScreen { RootScreen() }
    func makeLoggedOutView() -> any LoggedOutViewContract { loggedOut.makeLoggedOutView() }
    func makeTerminalView() -> any TerminalViewContract { loggedIn.makeTerminalView() }
}

/// 공유 코어의 `GrepApp`을 시작하고 루트 화면을 `#app`에 붙인다. JS가 `startGrepApp`으로 부른다.
@MainActor
enum GrepWebApp {
    private static let appContainerID = "app"
    private static var app: GrepApp<WebViewFactory>?
    private static var renderer: SlotRenderer?

    static func start(viewFactory: WebViewFactory, platform: PlatformServices) {
        precondition(app == nil, "startGrepApp called twice")
        guard let container = JSObject.global.document.getElementById(appContainerID).object else {
            preconditionFailure("index.html should have #\(appContainerID)")
        }
        let host = WebViewHost<RootScreen>()
        renderer = SlotRenderer(slot: host.slot, container: container)
        let app = GrepApp(viewFactory: viewFactory, platform: platform)
        app.start(host: host)
        self.app = app
    }
}
