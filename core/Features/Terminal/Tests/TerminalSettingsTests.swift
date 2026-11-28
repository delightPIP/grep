import FeatureTerminalInterface
import GrepCore
import GrepCoreTesting
import Testing

@testable import FeatureTerminal

/// #168 설정 탭 상태: 계정(`/me`에 있는 값만)과 AI 도구 연결(ACC-002).
@MainActor
struct TerminalSettingsTests {
    private typealias Fixture = TerminalFixture

    private let fixture = Fixture()

    private static let meJSON = #"{"userId":"6f1c2a52-6a8b-4a44-9a39-7c1f7e1d2b3a","authProvider":"github","itemCount":34}"#
    private static let listJSON = #"{"mcpUrl":"https://grep.example/mcp","connections":["#
        + #"{"number":1,"client":"Claude","connectedAt":"2026-11-20T10:00:00+09:00","lastReadAt":null}]}"#
    private static let claude = ConnectionEntry(
        number: 1, client: "Claude", connectedAt: "2026-11-20T10:00:00+09:00", lastReadAt: nil
    )

    @Test func 설정을열때_계정과연결을차례로받으면_둘다채우는지() async {
        // given
        await fixture.attach()

        // when
        await fixture.send(.settingsOpen)
        await fixture.respond(json: Self.meJSON)
        await fixture.respond(json: Self.listJSON)

        // then
        #expect(fixture.transport.requests.suffix(2).map(\.path) == ["/me", "/connections"])
        #expect(fixture.state.settings == SettingsState(
            account: SettingsAccount(authProvider: .github, itemCount: 34), connections: [Self.claude]
        ))
    }

    @Test func 설정을열때_아직받기전이면_빈설정을두는지() async {
        // given
        await fixture.attach()

        // when
        await fixture.send(.settingsOpen)

        // then
        #expect(fixture.state.settings == SettingsState())
    }

    @Test func 계정을받지못했을때_연결은받으면_계정없이연결만채우는지() async {
        // given
        await fixture.attach()
        await fixture.send(.settingsOpen)

        // when
        await fixture.fail(.unreachable)
        await fixture.respond(json: Self.listJSON)

        // then
        #expect(fixture.state.settings == SettingsState(account: nil, connections: [Self.claude]))
    }

    @Test func 설정을열때_세션만료로답하면_만료를알리고연결을묻지않는지() async {
        // given
        await fixture.attach()
        await fixture.send(.settingsOpen)

        // when
        await fixture.respond(status: 401, json: Fixture.sessionExpiredJSON)

        // then
        #expect(fixture.listener.expiredInputs.count == 1)
        #expect(fixture.transport.requests.last?.path == "/me")
    }

    @Test func 설정을연적이있을때_연결을끊으면_연결을다시받는지() async {
        // given
        await fixture.attach()
        await fixture.send(.settingsOpen)
        await fixture.respond(json: Self.meJSON)
        await fixture.respond(json: Self.listJSON)
        await fixture.submit("연결 끊기 1")
        await fixture.respond(json: Self.listJSON)
        await fixture.submit("끊기")

        // when
        await fixture.respond(json: #"{"result":"ended","client":"Claude"}"#)
        await fixture.respond(json: #"{"mcpUrl":"https://grep.example/mcp","connections":[]}"#)

        // then
        #expect(fixture.transport.requests.last?.path == "/connections")
        #expect(fixture.state.settings?.connections == [])
        #expect(fixture.state.settings?.account == SettingsAccount(authProvider: .github, itemCount: 34))
    }
}
