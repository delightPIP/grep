import FeatureTerminalInterface
import GrepCore
import GrepCoreTesting
import Testing

@testable import FeatureTerminal

/// #137 폴더 안내(ARC-007 규칙 11), #154 고르기 빼기 안내·제안.
@MainActor
struct TerminalHintTests {
    @Test(arguments: ["폴더", "폴더 만들기 결제", "mkdir pay", "MKDIR"])
    func 폴더를만들려는입력일때_실행하면_요청없이폴더안내를찍는지(typed: String) async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit(typed)

        // then
        #expect(fixture.transport.requests.isEmpty)
        #expect(fixture.state.lines.suffix(2) == [.prompt(typed), .folderHint])
    }

    @Test func 고르기빼기를번호없이쳤을때_실행하면_빼기예시로빠진인자줄을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("고르기 빼기")

        // then
        #expect(fixture.transport.requests.isEmpty)
        #expect(fixture.state.lines.last == .missingArgument(.pick, sub: .unpick))
    }

    @Test func 고르기를번호없이쳤을때_실행하면_빼기가아닌빠진인자줄을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("고르기")

        // then
        #expect(fixture.state.lines.last == .missingArgument(.pick, sub: nil))
    }

    @Test(arguments: [("빼기 6", "빼기", "고르기 빼기 6"), ("비우기", "비우기", "고르기 비우기")])
    func 고르기없이빼기나비우기를쳤을때_실행하면_고르기명령을제안하는지(typed: String, word: String, suggestion: String) async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit(typed)

        // then
        #expect(fixture.state.lines.last == .unknownCommand(word, suggestion: suggestion))
    }

    @Test func 안내줄이있을때_기록을남기고읽으면_같은줄로되살리는지() {
        // given
        let lines: [TerminalViewState.Line] = [.folderHint, .missingArgument(.pick, sub: .unpick), .missingArgument(.seek)]

        // when
        let restored = TerminalHistory.decode(
            TerminalHistory.encode(TerminalHistory.Snapshot(lines: lines, input: "", selection: []))
        )

        // then
        #expect(restored?.lines == lines)
    }
}
