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

    @Test func 넘길글을기다릴때_글이오면_받은글그대로복사하고복사됨줄을찍는지() async {
        // given
        await fixture.attach()
        await fixture.pick([30, 25])
        await fixture.submit("넘기기")
        let result = Fixture.handoff([30, 25], missingSummaryCount: 1)

        // when
        await fixture.respond(json: Fixture.handoffJSON(result))

        // then: 화면 글자 수는 클립보드에 넣은 글과 함께 온 서버 값이다(AC-13).
        #expect(fixture.fakeClipboard.copied == [result.text])
        #expect(fixture.state.lines.last == .handedOff(result))
        #expect(fixture.state.selection == [Fixture.ref(30), Fixture.ref(25)])
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
}
