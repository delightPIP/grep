import FeatureLoggedInUI
import FeatureLoggedOutAdapter
import FeatureLoggedOutInterface
import FeatureTerminalAdapter
import FeatureTerminalInterface
import Foundation
import GrepAppRoot
import GrepCore
import GrepPlatform
import Observation
import RIBs
import RIBsSwiftUI
import SwiftUI

@main
struct GrepIOSApp: App {
    @State private var launcher = AppLauncher()

    var body: some Scene {
        WindowGroup {
            RIBSlotView(slot: launcher.host.slot)
                .onAppear { launcher.start() }
        }
    }
}

/// 루트 RIB의 뷰. 자식 RIB 화면(로그인 또는 터미널) 하나를 보여 준다.
@MainActor
final class RootScreen: RootViewControllable, SwiftUIRenderable {
    private let slot = RIBScreenSlot()

    func showScreen(_ screen: any ViewControllable) { slot.show(screen) }
    func hideScreen(_ screen: any ViewControllable) { slot.hide(screen) }

    func makeView() -> AnyView {
        AnyView(
            RIBSlotView(slot: slot)
                .animation(.default, value: slot.current.map(ObjectIdentifier.init))
        )
    }
}

/// 피처 어댑터 모듈의 팩토리를 모아 `GrepAppViewFactory`를 채운다.
@MainActor
final class AppViewFactory: GrepAppViewFactory {
    private let loggedOut = LoggedOutScreenFactory()
    private let terminal = TerminalScreenFactory { terminalView, isKeyboardVisible in
        AnyView(LoggedInTabWrapper(isKeyboardVisible: isKeyboardVisible, terminalView: terminalView))
    }

    func makeRootView() -> RootScreen { RootScreen() }
    func makeLoggedOutView() -> any LoggedOutViewContract { loggedOut.makeLoggedOutView() }
    func makeTerminalView() -> any TerminalViewContract { terminal.makeTerminalView() }
}

/// 터미널 화면을 하단 탭 컨테이너(MOB-001)로 감싼다.
private struct LoggedInTabWrapper: View {
    @Binding var isKeyboardVisible: Bool
    let terminalView: AnyView
    @State private var selectedTab: LoggedInTab = .terminal

    var body: some View {
        LoggedInTabContainerView(
            selectedTab: $selectedTab,
            hidesTabBar: isKeyboardVisible
        ) {
            terminalView
        }
    }
}

@MainActor
final class AppLauncher {
    let host = SwiftUIViewHost<RootScreen>()
    private let app: GrepApp<AppViewFactory>
    private var isStarted = false

    init() {
        let baseURL = AppLauncher.resolveBaseURL()
        let platform = PlatformServices(
            authService: AppLauncher.resolveAuthService(),
            httpTransport: URLSessionHTTPTransport(baseURL: baseURL),
            clipboard: PasteboardClipboardPort(),
            files: URLSessionFilePort(),
            historyStore: UserDefaultsHistoryStore()
        )
        self.app = GrepApp(viewFactory: AppViewFactory(), platform: platform)
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        app.start(host: host)
    }

    private static func resolveBaseURL() -> URL {
        if let raw = UserDefaults.standard.string(forKey: "grepBaseURL"),
           let url = URL(string: raw),
           ["http", "https"].contains(url.scheme?.lowercased())
        {
            return url
        }
        if let raw = Bundle.main.object(forInfoDictionaryKey: "GREP_API_BASE_URL") as? String,
           let url = URL(string: raw),
           ["http", "https"].contains(url.scheme?.lowercased())
        {
            return url
        }
        return URL(string: "http://localhost:8080")!
    }

    private static func resolveAuthService() -> any AuthService {
        let urlString = UserDefaults.standard.string(forKey: "supabaseURL")
            ?? (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String)
        let key = UserDefaults.standard.string(forKey: "supabasePublishableKey")
            ?? (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String)
        if let urlString, let url = URL(string: urlString), let key, !key.isEmpty {
            return WebAuthService(configuration: .init(supabaseURL: url, publishableKey: key))
        }
        return UnconfiguredAuthService()
    }
}
