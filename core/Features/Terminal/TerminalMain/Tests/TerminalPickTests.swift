import FeatureTerminalInterface
import TerminalDomain
import GrepCore
import GrepCoreTesting
import Testing

@testable import FeatureTerminal

/// #62: `고르기 <번호…>`(commands 3절, ARC-001 규칙 9~11), 선택 상태, 실패(COM-010).
@MainActor
struct TerminalPickTests {
    private typealias Fixture = TerminalFixture
    private let fixture = Fixture()

    @Test(arguments: [
        ("고르기 25 30", "/items/status?numbers=25,30"),
        ("pick 25", "/items/status?numbers=25"),
        ("고르기  30   25 30", "/items/status?numbers=30,25"),
    ])
    func 터미널화면일때_고르기를치면_겹치지않게번호를확인하는지(typed: String, path: String) async {
        // given
        await fixture.attach()

        // when
        await fixture.submit(typed)

        // then
        #expect(fixture.state.lines == [.prompt(typed)])
        #expect(fixture.state.input == "")
        #expect(fixture.transport.requests.last == Fixture.get(path))
    }

    @Test func 번호를확인하는중일때_모두있다고답하면_친순서로선택하고선택줄을찍는지() async {
        // given
        await fixture.attach()
        await fixture.submit("고르기 30 25")

        // when
        await fixture.respond(json: Fixture.lookupJSON([Fixture.item(25), Fixture.item(30)]))

        // then
        let picked = [Fixture.ref(30), Fixture.ref(25)]
        #expect(fixture.state.selection == picked)
        #expect(fixture.state.lines == [.prompt("고르기 30 25"), .picked(picked)])
    }

    @Test func 이미고른자료가있을때_다른번호를고르면_선택뒤에더하는지() async {
        // given
        await fixture.attach()
        await fixture.pick([25])

        // when
        await fixture.submit("고르기 25 30")
        await fixture.respond(json: Fixture.lookupJSON([Fixture.item(25), Fixture.item(30)]))

        // then
        let picked = [Fixture.ref(25), Fixture.ref(30)]
        #expect(fixture.state.selection == picked)
        #expect(fixture.state.lines.last == .picked(picked))
    }

    @Test func 이미고른자료가있을때_없는번호가섞여있으면_없는번호줄만찍고선택을그대로두는지() async {
        // given
        await fixture.attach()
        await fixture.pick([25])

        // when
        await fixture.submit("고르기 30 98 99")
        await fixture.respond(json: Fixture.lookupJSON([Fixture.item(30)], missing: [98, 99]))

        // then
        #expect(fixture.state.selection == [Fixture.ref(25)])
        #expect(fixture.state.lines.suffix(2) == [.prompt("고르기 30 98 99"), .notFound(numbers: [98, 99])])
    }

    @Test func 번호를확인하는중일때_서버가어떤번호를빼고답하면_없는번호로보는지() async {
        // given
        await fixture.attach()
        await fixture.submit("고르기 25 30")

        // when
        await fixture.respond(json: Fixture.lookupJSON([Fixture.item(25)]))

        // then
        #expect(fixture.state.selection.isEmpty)
        #expect(fixture.state.lines.last == .notFound(numbers: [30]))
    }

    @Test(arguments: ["고르기", "pick", "고르기   "])
    func 터미널화면일때_고르기만치면_요청없이빠진인자줄을그리는지(typed: String) async {
        // given
        await fixture.attach()

        // when
        await fixture.submit(typed)

        // then
        #expect(fixture.state.lines == [.prompt(typed), .missingArgument(.pick)])
        #expect(fixture.state.input == "")
        #expect(fixture.transport.requests.isEmpty)
    }

    @Test(arguments: [
        ("고르기 0", "0"),
        ("고르기 25 -3", "-3"),
        ("고르기 1.5", "1.5"),
        ("고르기 25 결제", "결제"),
        ("고르기 +5", "+5"),
        ("고르기 99999999999999999999", "99999999999999999999"),
        ("고르기 3-7", "3-7"),
    ])
    func 터미널화면일때_양의정수가아닌번호를고르면_요청없이잘못된번호줄을그리는지(typed: String, input: String) async {
        // given
        await fixture.attach()

        // when
        await fixture.submit(typed)

        // then
        #expect(fixture.state.lines == [.prompt(typed), .invalidNumber(input)])
        #expect(fixture.state.selection.isEmpty)
        #expect(fixture.transport.requests.isEmpty)
    }

    @Test(arguments: [
        (HTTPTransportError.unreachable, CommandFailure.disconnected),
        (.timedOut, .timedOut),
    ])
    func 번호를확인하는중일때_서버에닿지못하면_고르기실패줄과다시칠명령을그리는지(
        error: HTTPTransportError, reason: CommandFailure
    ) async {
        // given
        await fixture.attach()
        await fixture.submit("고르기 25")

        // when
        await fixture.fail(error)

        // then
        #expect(fixture.state.lines == [
            .prompt("고르기 25"), .commandFailed(command: .pick, reason: reason, retry: "고르기 25"),
        ])
        #expect(fixture.state.selection.isEmpty)
    }

    @Test(arguments: [500, 400, 401])
    func 번호를확인하는중일때_서버가오류로답하면_서버오류로그리는지(status: Int) async {
        // given
        await fixture.attach()
        await fixture.submit("고르기 25")

        // when
        await fixture.respond(status: status, json: #"{"code":"internal"}"#)

        // then
        #expect(fixture.state.lines.last == .commandFailed(command: .pick, reason: .serverError, retry: "고르기 25"))
        #expect(fixture.listener.expiredInputs.isEmpty)
    }

    @Test func 번호를확인하는중일때_세션만료로답하면_친줄을되돌리고만료를알리는지() async {
        // given
        await fixture.attach()
        await fixture.submit("고르기 25")

        // when
        await fixture.respond(status: 401, json: Fixture.sessionExpiredJSON)

        // then
        #expect(fixture.state.input == "고르기 25")
        #expect(fixture.listener.expiredInputs == ["고르기 25"])
    }

    @Test func 토큰을받지못할때_고르기를치면_요청없이친줄을되돌리고만료를알리는지() async {
        // given
        await fixture.attach()
        fixture.auth.token = nil

        // when
        await fixture.submit("고르기 25")

        // then
        #expect(fixture.transport.requests.isEmpty)
        #expect(fixture.state.input == "고르기 25")
        #expect(fixture.listener.expiredInputs == ["고르기 25"])
    }

    @Test func 두건이선택되어있을때_하나만빼면_unpicked와남은건수1을찍는지() async {
        // given
        await fixture.attach()
        await fixture.pick([30, 25])

        // when
        await fixture.submit("고르기 빼기 30")

        // then
        #expect(fixture.state.selection == [Fixture.ref(25)])
        #expect(fixture.state.lines.last == .unpicked(items: [Fixture.ref(30)], remaining: 1))
    }

    @Test func 마지막선택을뺄때_남은선택이0이되면_unpicked대신pickCleared를찍는지() async {
        // given
        await fixture.attach()
        await fixture.pick([30])

        // when
        await fixture.submit("고르기 빼기 30")

        // then
        #expect(fixture.state.selection.isEmpty)
        #expect(fixture.state.lines.last == .pickCleared(count: 1))
    }

    @Test func 선택이있을때_고르기비우기를치면_모든선택을지우고pickCleared를찍는지() async {
        // given
        await fixture.attach()
        await fixture.pick([30, 25])

        // when
        await fixture.submit("고르기 비우기")

        // then
        #expect(fixture.state.selection.isEmpty)
        #expect(fixture.state.lines.last == .pickCleared(count: 2))
    }

    // MARK: #179 선택 칩 종류(ARC-003 규칙 14)

    @Test func 글과파일자료를고를때_모두있다고답하면_선택에종류와출처를담는지() async {
        // given
        await fixture.attach()
        let note = ItemSummary(
            number: 12, kind: .text, title: "메모", source: nil, status: .ready, tags: [],
            savedAt: "2026-11-27T10:00:00+09:00"
        )
        let file = ItemSummary(
            number: 25, kind: .file, title: "명세.pdf", source: "pdf", status: .ready, tags: [],
            savedAt: "2026-11-27T10:00:00+09:00"
        )
        await fixture.submit("고르기 25 12")

        // when
        await fixture.respond(json: Fixture.lookupJSON([note, file]))

        // then
        #expect(fixture.state.selection == [
            ItemRef(number: 25, title: "명세.pdf", kind: .file, source: "pdf"),
            ItemRef(number: 12, title: "메모", kind: .text, source: nil),
        ])
    }
}
