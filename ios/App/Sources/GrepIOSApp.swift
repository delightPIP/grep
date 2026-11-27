import FeatureLoggedOutAdapter
import FeatureLoggedOutInterface
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

    func makeRootView() -> RootScreen { RootScreen() }
    func makeLoggedOutView() -> any LoggedOutViewContract { loggedOut.makeLoggedOutView() }
    // shortcut: 1단계 뼈대용 자리표시 화면, 2단계에서 Features/Terminal 어댑터로 교체.
    func makeTerminalView() -> any TerminalViewContract { TerminalPlaceholderScreen() }
}

/// 1단계 뼈대용 터미널 자리표시 화면.
@MainActor
private final class TerminalPlaceholderScreen: TerminalViewContract, SwiftUIRenderable {
    weak var listener: (any TerminalPresentableListener)?
    private let model = PlaceholderModel()

    func render(_ state: TerminalViewState) {
        model.itemCount = state.itemCount
    }

    func makeView() -> AnyView {
        AnyView(TerminalPlaceholderView(model: model) { [weak self] in
            self?.listener?.handle(.submitted("로그아웃"))
        })
    }
}

@MainActor @Observable
private final class PlaceholderModel {
    var itemCount: Int?
}

private struct TerminalPlaceholderView: View {
    let model: PlaceholderModel
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("그렙 — 터미널 준비 중")
                .font(.system(.title3, design: .monospaced).bold())
            if let count = model.itemCount {
                Text("자료 \(count)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Button("로그아웃", action: onSignOut)
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
        }
        .padding(24)
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
