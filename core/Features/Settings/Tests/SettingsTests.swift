import FeatureSettingsInterface
import FeatureSettingsTesting
import GrepCore
import GrepCoreTesting
import RIBs
import Testing

@testable import FeatureSettings

/// 설정을 가짜 전송으로 붙여 두는 받침. 응답 시점은 테스트가 정한다.
@MainActor
private final class SettingsFixture: SettingsDependency {
    let auth = FakeAuthService(token: fakeAccessToken(subject: "user-a"))
    let transport = FakeHTTPTransport()
    let views = FakeSettingsViewFactory()
    let listener = FakeSettingsListener()
    private let parent = TestParentRouter()
    private var router: (any ViewableRouting)?
    private(set) var handle: (any SettingsHandle)?

    var authService: any AuthService { auth }
    var httpTransport: any HTTPTransport { transport }

    isolated deinit {
        if let router { parent.detach(router) }
    }

    var view: FakeSettingsView { views.views.last! }
    var state: SettingsState? { view.state }

    func attach() async {
        let build = SettingsBuilder(dependency: self, viewFactory: views).build(listener: listener)
        parent.attach(build.router)
        router = build.router
        handle = build.handle
        await runCurrent()
    }

    func send(_ action: SettingsViewAction) async {
        view.listener?.handle(action)
        await runCurrent()
    }

    func respond(status: Int = 200, json: String) async {
        transport.respond(status: status, json: json)
        await runCurrent()
    }

    func fail(_ error: HTTPTransportError) async {
        transport.respond(.failure(error))
        await runCurrent()
    }
}

/// #168 설정 탭 상태: 계정(`/me`에 있는 값만)과 AI 도구 연결(ACC-002).
@MainActor
struct SettingsTests {
    private let fixture = SettingsFixture()

    private static let meJSON = #"{"userId":"6f1c2a52-6a8b-4a44-9a39-7c1f7e1d2b3a","authProvider":"github","itemCount":34}"#
    private static let listJSON = #"{"mcpUrl":"https://grep.example/mcp","connections":["#
        + #"{"number":1,"client":"Claude","connectedAt":"2026-11-20T10:00:00+09:00","lastReadAt":null}]}"#
    private static let emptyListJSON = #"{"mcpUrl":"https://grep.example/mcp","connections":[]}"#
    private static let claude = ConnectionEntry(
        number: 1, client: "Claude", connectedAt: "2026-11-20T10:00:00+09:00", lastReadAt: nil
    )

    private func open() async {
        await fixture.send(.open)
        await fixture.respond(json: Self.meJSON)
        await fixture.respond(json: Self.listJSON)
    }

    @Test func 설정을열때_계정과연결을차례로받으면_둘다채우는지() async {
        // given
        await fixture.attach()

        // when
        await open()

        // then
        #expect(fixture.transport.requests.map(\.path) == ["/me", "/connections"])
        #expect(fixture.state == SettingsState(
            account: SettingsAccount(authProvider: .github, itemCount: 34), connections: [Self.claude]
        ))
    }

    @Test func 설정을열때_아직받기전이면_빈설정을두는지() async {
        // given
        await fixture.attach()

        // when
        await fixture.send(.open)

        // then
        #expect(fixture.state == SettingsState())
    }

    @Test func 계정을받지못했을때_연결은받으면_계정없이연결만채우는지() async {
        // given
        await fixture.attach()
        await fixture.send(.open)

        // when
        await fixture.fail(.unreachable)
        await fixture.respond(json: Self.listJSON)

        // then
        #expect(fixture.state == SettingsState(account: nil, connections: [Self.claude]))
    }

    @Test func 설정을열때_세션만료로답하면_만료를알리고연결을묻지않는지() async {
        // given
        await fixture.attach()
        await fixture.send(.open)

        // when
        await fixture.respond(status: 401, json: #"{"code":"session_expired"}"#)

        // then
        #expect(fixture.listener.expiredCount == 1)
        #expect(fixture.transport.requests.map(\.path) == ["/me"])
    }

    @Test func 설정을연적이있을때_연결이바뀌었다고하면_연결만다시받는지() async {
        // given
        await fixture.attach()
        await open()

        // when
        fixture.handle?.refreshConnectionsIfOpened()
        await runCurrent()
        await fixture.respond(json: Self.emptyListJSON)

        // then
        #expect(fixture.transport.requests.last?.path == "/connections")
        #expect(fixture.state == SettingsState(
            account: SettingsAccount(authProvider: .github, itemCount: 34), connections: []
        ))
    }

    @Test func 설정을연적이없을때_연결이바뀌었다고하면_받지않는지() async {
        // given
        await fixture.attach()

        // when
        fixture.handle?.refreshConnectionsIfOpened()
        await runCurrent()

        // then
        #expect(fixture.transport.requests.isEmpty)
    }
}
