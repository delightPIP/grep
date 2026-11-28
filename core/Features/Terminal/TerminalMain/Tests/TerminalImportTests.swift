import FeatureTerminalInterface
import TerminalDomain
import GrepCore
import GrepCoreTesting
import Testing

@testable import FeatureTerminal

/// #127 북마크 가져오기(commands 6절, user-flow 10절).
@MainActor
struct TerminalImportTests {
    private static let html = "<DL><DT><A HREF=\"https://example.com\">예</A></DL>"
    private static let file = DroppedFile(id: "file-1", name: "bookmarks.html", size: 120)

    private static func statusJSON(
        state: String, total: Int, done: Int, saved: Int = 0, skipped: Int = 0, failed: Int = 0,
        overLimit: Int = 0, failedUrls: [String] = []
    ) -> String {
        let urls = failedUrls.map { "\"\($0)\"" }.joined(separator: ",")
        return #"{"id":"job-1","state":"\#(state)","total":\#(total),"done":\#(done),"saved":\#(saved),"#
            + #""skipped":\#(skipped),"failed":\#(failed),"overLimit":\#(overLimit),"failedUrls":[\#(urls)]}"#
    }

    private func startImport(_ fixture: TerminalFixture) async {
        fixture.fakeFiles.texts[Self.file.id] = Self.html
        await fixture.submit("가져오기")
        await fixture.send(.filesDropped([Self.file]))
    }

    @Test func 가져오기를쳤을때_실행하면_요청없이파일을기다리는줄을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("bring")

        // then
        #expect(fixture.transport.requests.isEmpty)
        #expect(fixture.state.lines.suffix(2) == [.prompt("bring"), .importPrompt])
    }

    @Test func 가져오기뒤에파일을놓으면_HTML글을보내고진행줄을찍으며저장하지않는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await startImport(fixture)
        await fixture.respond(status: 202, json: Self.statusJSON(state: "running", total: 3, done: 0))

        // then
        #expect(fixture.transport.requests.last?.method == .post)
        #expect(fixture.transport.requests.last?.path == "/imports")
        #expect(fixture.transport.requests.last?.body == #"{"html":"<DL><DT><A HREF=\"https:\/\/example.com\">예<\/A><\/DL>"}"#)
        #expect(fixture.fakeFiles.uploads.isEmpty)
        #expect(fixture.fakeFiles.released == [Self.file.id])
        #expect(fixture.state.lines.last == .importProgress(done: 0, total: 3))
    }

    @Test func 진행중일때_다른명령을쳐도_폴링으로진행을고치고끝나면완료줄을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()
        await startImport(fixture)
        await fixture.respond(status: 202, json: Self.statusJSON(state: "running", total: 3, done: 0))
        let progressIndex = fixture.state.lines.count - 1

        // when
        await fixture.submit("도움말")
        await fixture.fakeSleeper.advance(by: .seconds(2))
        await fixture.respond(json: Self.statusJSON(state: "running", total: 3, done: 2))
        let midway = fixture.state.lines[progressIndex]
        await fixture.fakeSleeper.advance(by: .seconds(2))
        await fixture.respond(json: Self.statusJSON(
            state: "finished", total: 3, done: 3, saved: 1, skipped: 1, failed: 1, failedUrls: ["https://bad.example"]
        ))

        // then
        #expect(fixture.transport.requests.last?.path == "/imports/job-1")
        #expect(midway == .importProgress(done: 2, total: 3))
        #expect(fixture.state.lines[progressIndex] == .importProgress(done: 3, total: 3))
        #expect(fixture.state.lines.last == .importFinished(
            saved: 1, skipped: 1, failed: 1, overLimit: 0, failedUrls: ["https://bad.example"]
        ))
    }

    @Test func 가져오기를치지않았을때_파일을놓으면_전처럼담는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.send(.filesDropped([Self.file]))

        // then
        #expect(fixture.transport.requests.last?.path == "/uploads")
    }

    @Test func 가져오기뒤에다른명령을쳤을때_파일을놓으면_가져오지않고담는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()
        await fixture.submit("가져오기")
        await fixture.submit("도움말")

        // when
        await fixture.send(.filesDropped([Self.file]))

        // then
        #expect(fixture.transport.requests.last?.path == "/uploads")
    }

    @Test func 가져오기를시작할때_서버에닿지못하면_가져오기실패줄을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await startImport(fixture)
        await fixture.fail(.unreachable)

        // then
        #expect(fixture.state.lines.last == .commandFailed(command: .bring, reason: .disconnected, retry: "가져오기"))
    }

    @Test func 가져오기줄이있을때_기록을남기고읽으면_같은줄로되살리는지() {
        // given
        let lines: [TerminalViewState.Line] = [
            .importPrompt,
            .importProgress(done: 2, total: 3),
            .importFinished(saved: 1, skipped: 1, failed: 1, overLimit: 4, failedUrls: ["https://bad.example"]),
        ]

        // when
        let restored = TerminalHistory.decode(
            TerminalHistory.encode(TerminalHistory.Snapshot(lines: lines, input: "", selection: []))
        )

        // then
        #expect(restored?.lines == lines)
    }
}
