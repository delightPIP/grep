import ArchiveData
import FeatureArchive
import FeatureArchiveInterface
import FeatureArchiveTesting
import FeatureLoggedInInterface
import FeatureLoggedInTesting
import FeatureSettings
import SettingsData
import FeatureSettingsInterface
import FeatureSettingsTesting
import FeatureTerminal
import FeatureTerminalInterface
import FeatureTerminalTesting
import GrepCore
import GrepCoreTesting
import RIBs
import Testing

@testable import FeatureLoggedIn

@MainActor
private final class TabsDependency: LoggedInDependency, TerminalDependency, ArchiveDependency, SettingsDependency {
    let authService: any AuthService
    let httpTransport: any HTTPTransport
    let clipboard: any ClipboardPort = FakeClipboard()
    let files: any FilePort = FakeFilePort()
    let historyStore: any HistoryStore = FakeHistoryStore()
    let sleeper: any Sleeper = FakeSleeper()

    let archiveRepository: any ArchiveRepository
    let settingsRepository: any SettingsRepository

    init(authService: any AuthService, httpTransport: any HTTPTransport) {
        self.authService = authService
        self.httpTransport = httpTransport
        archiveRepository = ArchiveRepositoryImpl(authService: authService, httpTransport: httpTransport, deviceTime: .system)
        settingsRepository = SettingsRepositoryImpl(authService: authService, httpTransport: httpTransport)
    }
}

/// #168 컨테이너가 터미널의 변화 알림을 보관함·설정에 잇고, 탭의 만료를 부모에 올리는지.
@MainActor
final class LoggedInTabsTests {
    private static let meJSON = #"{"userId":"6f1c0a52-0000-4000-8000-000000000001","authProvider":"google","itemCount":34}"#
    private static let noNoticesJSON = #"{"ended":[]}"#
    private static let itemJSON = #"{"number":35,"kind":"link","title":"자료 35","source":"example.com","#
        + #""status":"ready","blockedReason":null,"listSummary":"요약","summarySource":"ai","#
        + #""partialNote":null,"tags":[],"matchedIn":null,"savedAt":"2026-11-27T10:00:00+09:00"}"#
    private static let emptyPageJSON = #"{"items":[],"nextCursor":null}"#
    private static let connectionsJSON = #"{"mcpUrl":"https://grep.example/mcp","connections":[{"number":1,"client":"Claude","connectedAt":"2026-11-20T10:00:00+09:00","lastReadAt":null}]}"#

    private let auth = FakeAuthService(token: fakeAccessToken(subject: "user-a"))
    private let transport = FakeHTTPTransport()
    private let terminalViews = FakeTerminalViewFactory()
    private let archiveViews = FakeArchiveViewFactory()
    private let settingsViews = FakeSettingsViewFactory()
    private let listener = FakeLoggedInListener()
    private let parent = TestParentRouter()
    private var router: (any ViewableRouting)?

    isolated deinit {
        if let router { parent.detach(router) }
    }

    /// `/me`와 연결 알림까지 받은 화면.
    private func attach() async {
        let dependency = TabsDependency(authService: auth, httpTransport: transport)
        let builder = LoggedInBuilder(
            dependency: dependency,
            terminalBuilder: TerminalBuilder(dependency: dependency, viewFactory: terminalViews),
            archiveBuilder: ArchiveBuilder(dependency: dependency, viewFactory: archiveViews),
            settingsBuilder: SettingsBuilder(dependency: dependency, viewFactory: settingsViews)
        )
        let router = builder.build(listener: listener, pendingInput: nil)
        parent.attach(router)
        self.router = router
        await runCurrent()
        await respond(Self.meJSON)
        await respond(Self.noNoticesJSON)
    }

    private func respond(status: Int = 200, _ json: String) async {
        transport.respond(status: status, json: json)
        await runCurrent()
    }

    private func submit(_ text: String) async {
        terminalViews.views.last?.listener?.handle(.submitted(text))
        await runCurrent()
    }

    /// 보관함을 열고 네 응답(첫 쪽·자동 묶음·묶음·찾아둔 검색)을 준다.
    private func openArchive() async {
        archiveViews.views.last?.listener?.handle(.open)
        await runCurrent()
        await respond(Self.emptyPageJSON)
        await respond(#"{"kinds":[],"sources":[],"periods":[],"tags":[]}"#)
        await respond(#"{"bundles":[]}"#)
        await respond(#"{"searches":[]}"#)
    }

    @Test func 보관함을연적이있을때_터미널에서저장하면_보관함첫쪽을다시받는지() async {
        // given
        await attach()
        await openArchive()
        await submit("담기 https://example.com")

        // when
        await respond(status: 201, #"{"result":"saved","item":\#(Self.itemJSON)}"#)

        // then
        #expect(transport.requests.last?.path == "/items?limit=20")
    }

    @Test func 보관함을연적이없을때_터미널에서저장하면_보관함을받지않는지() async {
        // given
        await attach()
        await submit("담기 https://example.com")

        // when
        await respond(status: 201, #"{"result":"saved","item":\#(Self.itemJSON)}"#)

        // then
        #expect(transport.requests.allSatisfy { !$0.path.hasPrefix("/items?") && !$0.path.hasPrefix("/groups") })
        #expect(archiveViews.views.last?.state == nil)
    }

    @Test func 설정을연적이있을때_터미널에서연결을끊으면_연결을다시받는지() async {
        // given
        await attach()
        settingsViews.views.last?.listener?.handle(.open)
        await runCurrent()
        await respond(Self.meJSON)
        await respond(Self.connectionsJSON)
        await submit("연결 끊기 1")
        await respond(Self.connectionsJSON)
        await submit("끊기")

        // when
        await respond(#"{"result":"ended","client":"Claude"}"#)
        await respond(#"{"mcpUrl":"https://grep.example/mcp","connections":[]}"#)

        // then
        #expect(transport.requests.last?.path == "/connections")
        #expect(settingsViews.views.last?.state?.connections == [])
    }

    @Test func 보관함이세션만료를알리면_치던줄과함께부모에만료를알리는지() async {
        // given
        await attach()
        terminalViews.views.last?.listener?.handle(.inputChanged("찾기 결제"))
        await runCurrent()
        archiveViews.views.last?.listener?.handle(.open)
        await runCurrent()

        // when
        await respond(status: 401, #"{"code":"session_expired"}"#)

        // then
        #expect(listener.expiredInputs == ["찾기 결제"])
    }
}
