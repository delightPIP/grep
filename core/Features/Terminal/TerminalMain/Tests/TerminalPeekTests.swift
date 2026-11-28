import FeatureTerminalInterface
import TerminalDomain
import GrepCore
import GrepCoreTesting
import Testing

@testable import FeatureTerminal

/// #131 열기(ARC-011).
@MainActor
struct TerminalPeekTests {
    private static let detailJSON = """
        {"item":\(TerminalFixture.json(TerminalFixture.item(131))),"handoffSummary":"넘길 요약","allTags":["결제","sdk"],\
        "bundles":["pay"],"bodyLength":3420,"body":"본문","bodyFromImage":false,"originalUrl":null,"previewUrl":null,\
        "url":"https://example.com/a"}
        """

    private static let detail = ItemDetail(
        item: TerminalFixture.item(131), url: "https://example.com/a", handoffSummary: "넘길 요약",
        allTags: ["결제", "sdk"], bundles: ["pay"], bodyLength: 3420, body: "본문", bodyFromImage: false,
        originalUrl: nil, previewUrl: nil
    )

    @Test func 번호하나로열때_서버가자세히보기를주면_자세히보기줄을찍고선택을그대로두는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()
        await fixture.pick([7])

        // when
        await fixture.submit("열기 131")
        await fixture.respond(json: Self.detailJSON)

        // then
        #expect(fixture.transport.requests.last?.method == .get)
        #expect(fixture.transport.requests.last?.path == "/items/131")
        #expect(fixture.state.lines.last == .itemDetail(Self.detail))
        #expect(fixture.state.selection == [TerminalFixture.ref(7)])
    }

    @Test func 본문이없을때_열면_본문과글자수를nil로넘기는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()
        let json = """
            {"item":\(TerminalFixture.json(TerminalFixture.item(131))),"handoffSummary":null,"allTags":[],\
            "bundles":[],"bodyLength":null,"body":null,"bodyFromImage":false,"originalUrl":null,"previewUrl":null}
            """

        // when
        await fixture.submit("peek 131")
        await fixture.respond(json: json)

        // then
        #expect(fixture.state.lines.last == .itemDetail(ItemDetail(
            item: TerminalFixture.item(131), url: nil, handoffSummary: nil, allTags: [], bundles: [],
            bodyLength: nil, body: nil, bodyFromImage: false, originalUrl: nil, previewUrl: nil
        )))
    }

    @Test(arguments: [
        ("열기", TerminalViewState.Line.missingArgument(.peek)),
        ("열기 131 140", .oneNumberOnly(.peek)),
        ("열기 abc", .invalidNumber("abc")),
    ])
    func 번호가하나가아닐때_열면_요청없이실패줄을찍는지(typed: String, line: TerminalViewState.Line) async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit(typed)

        // then
        #expect(fixture.transport.requests.isEmpty)
        #expect(fixture.state.lines.last == line)
    }

    @Test func 없는번호를열때_서버가404로답하면_없는번호줄을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("열기 57")
        await fixture.respond(status: 404, json: #"{"code":"not_found","numbers":[57]}"#)

        // then
        #expect(fixture.state.lines.last == .notFound(numbers: [57]))
    }

    @Test func 열때_서버에닿지못하면_열기실패줄과다시칠명령을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("열기 131")
        await fixture.fail(.unreachable)

        // then
        #expect(fixture.state.lines.last == .commandFailed(command: .peek, reason: .disconnected, retry: "열기 131"))
    }

    @Test func 자세히보기줄이있을때_기록을남기고읽으면_같은줄로되살리는지() {
        // given
        let lines: [TerminalViewState.Line] = [.prompt("열기 131"), .itemDetail(Self.detail), .oneNumberOnly(.peek)]

        // when
        let restored = TerminalHistory.decode(
            TerminalHistory.encode(TerminalHistory.Snapshot(lines: lines, input: "", selection: []))
        )

        // then
        #expect(restored?.lines == lines)
    }
}
