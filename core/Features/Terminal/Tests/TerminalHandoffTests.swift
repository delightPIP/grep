import FeatureTerminalInterface
import GrepCore
import GrepCoreTesting
import Testing

@testable import FeatureTerminal

/// #64: `넘기기` → `POST /handoff` → 클립보드(commands 6절 넘기기, handoff-format 5절).
/// #65: 실패 이유 4종과 직접 복사 안내(COM-008 규칙 5~7).
@MainActor
struct TerminalHandoffTests {
    private typealias Fixture = TerminalFixture
    private let fixture = Fixture()

    // MARK: 넘기기(#64)

    @Test(arguments: ["넘기기", "handoff", " 넘기기  "])
    func 자료를골랐을때_넘기기를치면_고른순서로넘길글을요청하는지(typed: String) async {
        // given
        await fixture.attach()
        await fixture.pick([30, 25])

        // when
        await fixture.submit(typed)

        // then
        #expect(fixture.state.lines.last == .prompt(typed))
        #expect(fixture.state.input == "")
        #expect(fixture.transport.requests.last == Fixture.handoffRequest([30, 25]))
        #expect(fixture.fakeClipboard.copied.isEmpty)
    }

    @Test func 넘길글을기다릴때_글이오면_받은글그대로복사하고복사됨줄을찍고선택을푸는지() async {
        // given
        await fixture.attach()
        await fixture.pick([30, 25])
        await fixture.submit("넘기기")
        let result = Fixture.handoff([30, 25], missingSummaryCount: 1)

        // when
        await fixture.respond(json: Fixture.handoffJSON(result))

        // then: 화면 글자 수는 클립보드에 넣은 글과 함께 온 서버 값이다(AC-13). 성공하면 선택을 푼다(COM-008 규칙 8).
        #expect(fixture.fakeClipboard.copied == [result.text])
        #expect(fixture.state.lines.last == .handedOff(result))
        #expect(fixture.state.selection.isEmpty)
    }

    @Test(arguments: ["넘기기", "handoff"])
    func 고른자료가없을때_넘기기를치면_요청없이빠진인자줄을그리는지(typed: String) async {
        // given
        await fixture.attach()

        // when
        await fixture.submit(typed)

        // then
        #expect(fixture.state.lines == [.prompt(typed), .missingArgument(.handoff)])
        #expect(fixture.transport.requests.isEmpty)
        #expect(fixture.fakeClipboard.copied.isEmpty)
    }

    @Test func 자료를골랐을때_넘기기뒤에묶음이름을붙이면_요청없이없는명령으로그리는지() async {
        // given
        await fixture.attach()
        await fixture.pick([25])
        let requestCount = fixture.transport.requests.count

        // when
        await fixture.submit("넘기기 결제조사")

        // then
        #expect(fixture.state.lines.suffix(2) == [.prompt("넘기기 결제조사"), .unknownCommand("넘기기 결제조사")])
        #expect(fixture.transport.requests.count == requestCount)
    }

    @Test func 처리중자료를넘긴뒤일때_요약이와도_클립보드와복사됨줄을그대로두는지() async {
        // given
        await fixture.attach()
        await fixture.submit("최근")
        await fixture.respond(json: #"{"items":[\#(Fixture.json(Fixture.item(25, status: .processing, summary: nil)))],"nextCursor":null}"#)
        await fixture.pick([25])
        await fixture.submit("넘기기")
        let result = Fixture.handoff([25], missingSummaryCount: 1)
        await fixture.respond(json: Fixture.handoffJSON(result))
        await fixture.respond(status: 204, json: "")

        // when
        await fixture.fakeSleeper.advance(by: .seconds(2))
        await fixture.respond(json: Fixture.lookupJSON([Fixture.item(25)]))

        // then
        #expect(fixture.state.lines.first { $0 == .recentList(items: [Fixture.item(25)], hasMore: false) } != nil)
        #expect(fixture.fakeClipboard.copied == [result.text])
        #expect(fixture.state.lines.last == .handedOff(result))
    }

    @Test func 넘길글을기다릴때_세션만료로답하면_친줄을되돌리고만료를알리는지() async {
        // given
        await fixture.attach()
        await fixture.pick([25])
        await fixture.submit("넘기기")

        // when
        await fixture.respond(status: 401, json: Fixture.sessionExpiredJSON)

        // then
        #expect(fixture.state.input == "넘기기")
        #expect(fixture.listener.expiredInputs == ["넘기기"])
        #expect(fixture.fakeClipboard.copied.isEmpty)
    }

    // MARK: 넘기기 실패(#65)

    @Test(arguments: [
        (HTTPTransportError.unreachable, CommandFailure.disconnected),
        (.timedOut, .timedOut),
    ])
    func 넘길글을기다릴때_서버에닿지못하면_실패줄을찍고선택을남기는지(
        error: HTTPTransportError, reason: CommandFailure
    ) async {
        // given
        await fixture.attach()
        await fixture.pick([30, 25])
        await fixture.submit("넘기기")

        // when
        await fixture.fail(error)

        // then
        #expect(fixture.state.lines.suffix(2) == [.prompt("넘기기"), .handoffFailed(reason: reason, preview: nil)])
        #expect(fixture.state.selection == [Fixture.ref(30), Fixture.ref(25)])
        #expect(fixture.state.input == "")
        #expect(fixture.fakeClipboard.copied.isEmpty)
    }

    @Test(arguments: [(500, #"{"code":"internal"}"#), (400, #"{"code":"invalid_request"}"#), (200, "{}"), (404, "{}")])
    func 넘길글을기다릴때_서버가오류나모르는글로답하면_서버오류로찍고복사하지않는지(status: Int, json: String) async {
        // given
        await fixture.attach()
        await fixture.pick([25])
        await fixture.submit("넘기기")

        // when
        await fixture.respond(status: status, json: json)

        // then
        #expect(fixture.state.lines.last == .handoffFailed(reason: .serverError, preview: nil))
        #expect(fixture.state.selection == [Fixture.ref(25)])
        #expect(fixture.fakeClipboard.copied.isEmpty)
    }

    @Test func 클립보드가막혀있을때_넘길글이오면_거부줄에글전체를실어직접복사하게하는지() async {
        // given
        await fixture.attach()
        await fixture.pick([30, 25])
        fixture.fakeClipboard.result = .denied
        await fixture.submit("넘기기")
        let result = Fixture.handoff([30, 25])

        // when
        await fixture.respond(json: Fixture.handoffJSON(result))

        // then
        #expect(fixture.state.lines.last == .handoffFailed(reason: .clipboardDenied, preview: result.text))
        #expect(fixture.state.selection == [Fixture.ref(30), Fixture.ref(25)])
    }

    @Test func 넘기기가실패한뒤일때_넘기기를다시치면_같은선택으로다시요청해복사하는지() async {
        // given
        await fixture.attach()
        await fixture.pick([30, 25])
        await fixture.submit("넘기기")
        await fixture.fail(.unreachable)
        let result = Fixture.handoff([30, 25])

        // when
        await fixture.submit("넘기기")
        await fixture.respond(json: Fixture.handoffJSON(result))

        // then
        #expect(fixture.transport.requests.filter { $0.path != "/events" }.last == Fixture.handoffRequest([30, 25]))
        #expect(fixture.fakeClipboard.copied == [result.text])
        #expect(fixture.state.lines.last == .handedOff(result))
        #expect(fixture.state.selection.isEmpty)
    }

    @Test func 고른자료가그새지워졌을때_넘기기를치면_없는번호줄을찍고복사하지않고선택을남기는지() async {
        // given
        await fixture.attach()
        await fixture.pick([30, 25])
        await fixture.submit("넘기기")

        // when
        await fixture.respond(status: 404, json: #"{"code":"not_found","numbers":[25]}"#)

        // then
        #expect(fixture.state.lines.last == .notFound(numbers: [25]))
        #expect(fixture.fakeClipboard.copied.isEmpty)
        #expect(fixture.state.selection == [Fixture.ref(30), Fixture.ref(25)])
    }
}
