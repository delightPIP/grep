import FeatureLoggedInAdapter
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
    private let terminal: TerminalScreenFactory

    init(authService: any AuthService, httpTransport: any HTTPTransport) {
        self.terminal = TerminalScreenFactory { terminalView, context in
            AnyView(
                LoggedInTabWrapper(
                    authService: authService,
                    httpTransport: httpTransport,
                    context: context,
                    terminalView: terminalView
                )
            )
        }
    }

    func makeRootView() -> RootScreen { RootScreen() }
    func makeLoggedOutView() -> any LoggedOutViewContract { loggedOut.makeLoggedOutView() }
    func makeTerminalView() -> any TerminalViewContract { terminal.makeTerminalView() }
}

/// 터미널 화면을 하단 탭 컨테이너(MOB-001)로 감싸고 보관함·설정 탭을 연결한다.
private struct LoggedInTabWrapper: View {
    let context: TerminalHostContext
    let terminalView: AnyView
    @State private var model: LoggedInTabsModel
    @State private var trashModel: TrashScreenModel

    init(
        authService: any AuthService,
        httpTransport: any HTTPTransport,
        context: TerminalHostContext,
        terminalView: AnyView
    ) {
        self.context = context
        self.terminalView = terminalView
        let loader = HTTPArchiveItemLoader(authService: authService, httpTransport: httpTransport)
        let sendCommand = context.sendCommand
        self._model = State(
            initialValue: LoggedInTabsModel(
                archiveLoader: loader,
                onSignOut: { sendCommand("로그아웃") },
                // 설정 시트에서 이미 확인했으므로 코어 확인(`로그아웃 모든기기`)에 실행 낱말로 바로 답한다(COM-007).
                onSignOutEverywhere: {
                    sendCommand("로그아웃 모든기기")
                    sendCommand("로그아웃")
                },
                onPickItem: { number in sendCommand("고르기 \(number)") },
                // 보관함의 빼기·해제도 터미널 선택을 바꾸는 명령으로 기록한다(commands 3절 고르기).
                onUnpickItem: { number in sendCommand("고르기 빼기 \(number)") },
                onClearPicked: { sendCommand("고르기 비우기") }
            )
        )
        self._trashModel = State(
            initialValue: TrashScreenModel(client: HTTPTrashClient(authService: authService, httpTransport: httpTransport))
        )
    }

    var body: some View {
        LoggedInTabsView(
            model: model,
            trashModel: trashModel,
            hidesTabBar: context.isKeyboardVisible.wrappedValue || !context.pickedNumbers.isEmpty
        ) {
            terminalView
        }
        .onAppear {
            model.updateTerminalContext(itemCount: context.itemCount, pickedNumbers: context.pickedNumbers)
        }
        .onChange(of: context.itemCount) { _, newValue in
            model.updateTerminalContext(itemCount: newValue, pickedNumbers: context.pickedNumbers)
        }
        .onChange(of: context.pickedNumbers) { _, newValue in
            model.updateTerminalContext(itemCount: context.itemCount, pickedNumbers: newValue)
        }
        .onChange(of: model.terminalScrollToBottomTrigger) { _, newValue in
            context.scrollToBottomTrigger.wrappedValue = newValue
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
        let authService = AppLauncher.resolveAuthService()
        let httpTransport = URLSessionHTTPTransport(baseURL: baseURL)
        let platform = PlatformServices(
            authService: authService,
            httpTransport: httpTransport,
            clipboard: PasteboardClipboardPort(),
            files: URLSessionFilePort(),
            historyStore: UserDefaultsHistoryStore()
        )
        let viewFactory = AppViewFactory(authService: authService, httpTransport: httpTransport)
        self.app = GrepApp(viewFactory: viewFactory, platform: platform)
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
