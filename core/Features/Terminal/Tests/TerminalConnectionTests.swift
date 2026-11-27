import FeatureTerminalInterface
import GrepCore
import GrepCoreTesting
import Testing

@testable import FeatureTerminal

/// #124 AI 도구 연결(ACC-002).
@MainActor
struct TerminalConnectionTests {
    private static let listJSON = #"{"mcpUrl":"https://grep.example/mcp","connections":["#
        + #"{"number":1,"client":"Claude","connectedAt":"2026-11-20T10:00:00+09:00","lastReadAt":null},"#
        + #"{"number":2,"client":"Cursor","connectedAt":"2026-11-21T10:00:00+09:00","lastReadAt":"2026-11-27T09:00:00+09:00"}]}"#

    @Test func 연결을쳤을때_서버가목록을주면_연결목록줄을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("연결")
        await fixture.respond(json: Self.listJSON)

        // then
        #expect(fixture.transport.requests.last?.path == "/connections")
        #expect(fixture.state.lines.last == .connectionList(mcpUrl: "https://grep.example/mcp", connections: [
            ConnectionEntry(number: 1, client: "Claude", connectedAt: "2026-11-20T10:00:00+09:00", lastReadAt: nil),
            ConnectionEntry(
                number: 2, client: "Cursor", connectedAt: "2026-11-21T10:00:00+09:00",
                lastReadAt: "2026-11-27T09:00:00+09:00"
            ),
        ]))
    }

    @Test func 연결을끊을때_끊기를다시치면_그연결을끊는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("연결 끊기 2")
        await fixture.respond(json: Self.listJSON)
        let asked = fixture.state.lines.last == .disconnectConfirm(number: 2, client: "Cursor")
        await fixture.submit("끊기")
        await fixture.respond(json: #"{"result":"ended","client":"Cursor"}"#)

        // then
        #expect(asked)
        #expect(fixture.transport.requests.last?.method == .delete)
        #expect(fixture.transport.requests.last?.path == "/connections/2")
        #expect(fixture.state.lines.last == .disconnected(client: "Cursor", already: false))
    }

    @Test func 이미끊긴연결일때_끊으면_이미끊김으로찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()
        await fixture.submit("plug 끊기 1")
        await fixture.respond(json: Self.listJSON)

        // when
        await fixture.submit("끊기")
        await fixture.respond(json: #"{"result":"alreadyEnded","client":"Claude"}"#)

        // then
        #expect(fixture.state.lines.last == .disconnected(client: "Claude", already: true))
    }

    @Test func 목록에없는번호일때_끊으면_묻지않고없는연결줄을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("연결 끊기 9")
        await fixture.respond(json: Self.listJSON)
        await fixture.submit("끊기")

        // then
        #expect(fixture.transport.requests.allSatisfy { $0.method != .delete })
        #expect(fixture.state.lines.contains(.connectionNotFound(number: 9)))
    }

    @Test(arguments: [
        ("연결 끊기", TerminalViewState.Line.missingArgument(.plug)),
        ("연결 끊기 1 2", .oneNumberOnly(.plug)),
        ("연결 끊기 하나", .invalidNumber("하나")),
    ])
    func 끊기번호가하나가아닐때_실행하면_요청없이실패줄을찍는지(typed: String, line: TerminalViewState.Line) async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit(typed)

        // then
        #expect(fixture.transport.requests.isEmpty)
        #expect(fixture.state.lines.last == line)
    }

    @Test func 로그아웃모든기기를칠때_연결수를받으면_확인줄에연결수를넣는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("로그아웃 모든기기")
        await fixture.respond(json: Self.listJSON)

        // then
        #expect(fixture.transport.requests.last?.path == "/connections")
        #expect(fixture.state.lines.last == .signOutEverywhereConfirm(connectionCount: 2))
    }

    @Test func 그렙을열때_끊긴연결알림을받으면_연결끊김줄을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        fixture.handle?.showConnectionNotices([
            ConnectionNotice(client: "Claude", reason: .expired),
            ConnectionNotice(client: "Cursor", reason: .revoked),
        ])

        // then
        #expect(Array(fixture.state.lines.suffix(2)) == [
            .connectionEnded(client: "Claude", reason: .expired),
            .connectionEnded(client: "Cursor", reason: .revoked),
        ])
    }

    @Test func 연결줄이있을때_기록을남기고읽으면_같은줄로되살리는지() {
        // given
        let lines: [TerminalViewState.Line] = [
            .connectionList(mcpUrl: "https://grep.example/mcp", connections: [
                ConnectionEntry(number: 1, client: "Claude", connectedAt: "2026-11-20T10:00:00+09:00", lastReadAt: nil),
            ]),
            .disconnectConfirm(number: 1, client: "Claude"),
            .disconnected(client: "Claude", already: true),
            .connectionNotFound(number: 9),
            .connectionEnded(client: "Claude", reason: .revoked),
            .signOutEverywhereConfirm(connectionCount: 2),
        ]

        // when
        let restored = TerminalHistory.decode(
            TerminalHistory.encode(TerminalHistory.Snapshot(lines: lines, input: "", selection: []))
        )

        // then
        #expect(restored?.lines == lines)
    }
}
