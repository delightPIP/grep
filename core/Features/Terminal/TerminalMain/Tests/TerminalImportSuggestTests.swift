import FeatureTerminalInterface
import TerminalDomain
import GrepCore
import GrepCoreTesting
import Testing

@testable import FeatureTerminal

/// #172 끌어다 놓은 북마크 파일(`html`·`htm`)이 받지 않는 형식이면 `가져오기`를 제안한다.
@MainActor
struct TerminalImportSuggestTests {
    private typealias Fixture = TerminalFixture

    private static let html = "<DL><DT><A HREF=\"https://example.com\">예</A></DL>"
    private static let file = DroppedFile(id: "file-1", name: "bookmarks.html", size: 120)

    private static func unsupportedJSON(_ fileExtension: String) -> String {
        #"{"code":"unsupported_format","fileExtension":"\#(fileExtension)"}"#
    }

    /// 북마크 파일을 놓고 서버가 받지 않는 형식이라고 답하게 한다.
    private func dropRejected(
        _ fixture: Fixture, file: DroppedFile = TerminalImportSuggestTests.file, fileExtension: String = "html"
    ) async {
        fixture.fakeFiles.texts[file.id] = Self.html
        await fixture.send(.filesDropped([file]))
        await fixture.respond(status: 415, json: Self.unsupportedJSON(fileExtension))
    }

    @Test(arguments: ["html", "htm", "HTML"])
    func 북마크파일을놓았을때_받지않는형식이면_가져오기를제안하고파일을놓지않는지(fileExtension: String) async {
        // given
        let fixture = Fixture()
        await fixture.attach()

        // when
        await dropRejected(fixture, fileExtension: fileExtension)

        // then
        #expect(fixture.state.lines.suffix(2) == [
            .saveFailed(.unsupportedFormat(fileExtension: fileExtension), .file(name: "bookmarks.html")),
            .importSuggest(fileName: "bookmarks.html"),
        ])
        #expect(fixture.fakeFiles.released.isEmpty)
    }

    @Test func 다른파일을놓았을때_받지않는형식이면_제안하지않고파일을놓는지() async {
        // given
        let fixture = Fixture()
        await fixture.attach()
        let zip = DroppedFile(id: "z", name: "자료.zip", size: 10)

        // when
        await dropRejected(fixture, file: zip, fileExtension: "zip")

        // then
        #expect(fixture.state.lines.last == .saveFailed(.unsupportedFormat(fileExtension: "zip"), .file(name: "자료.zip")))
        #expect(fixture.fakeFiles.released == ["z"])
    }

    @Test(arguments: ["가져오기", "bring"])
    func 가져오기를제안했을때_가져오기를치면_파일을다시받지않고그내용을보내는지(command: String) async {
        // given
        let fixture = Fixture()
        await fixture.attach()
        await dropRejected(fixture)

        // when
        await fixture.submit(command)

        // then
        #expect(fixture.transport.requests.last?.method == .post)
        #expect(fixture.transport.requests.last?.path == "/imports")
        #expect(fixture.transport.requests.last?.body == #"{"html":"<DL><DT><A HREF=\"https:\/\/example.com\">예<\/A><\/DL>"}"#)
        #expect(fixture.state.lines.last == .prompt(command))
        #expect(fixture.fakeFiles.released == [Self.file.id])
    }

    @Test func 제안한파일을보냈을때_서버가진행을답하면_진행줄을찍는지() async {
        // given
        let fixture = Fixture()
        await fixture.attach()
        await dropRejected(fixture)
        await fixture.submit("가져오기")

        // when
        await fixture.respond(
            status: 202,
            json: #"{"id":"job-1","state":"running","total":3,"done":0,"saved":0,"skipped":0,"failed":0,"overLimit":0,"failedUrls":[]}"#
        )

        // then
        #expect(fixture.state.lines.last == .importProgress(done: 0, total: 3))
    }

    @Test func 가져오기를제안했을때_다른명령을치면_파일을놓고기억을지우는지() async {
        // given
        let fixture = Fixture()
        await fixture.attach()
        await dropRejected(fixture)

        // when
        await fixture.submit("도움말")
        await fixture.submit("가져오기")

        // then
        #expect(fixture.fakeFiles.released == [Self.file.id])
        #expect(fixture.state.lines.suffix(2) == [.prompt("가져오기"), .importPrompt])
        #expect(fixture.transport.requests.last?.path != "/imports")
    }

    @Test func 가져오기를제안했을때_다른파일을놓으면_앞파일을놓고새파일은저장하는지() async {
        // given
        let fixture = Fixture()
        await fixture.attach()
        await dropRejected(fixture)
        let pdf = DroppedFile(id: "p", name: "예산안.pdf", size: 10)

        // when
        await fixture.send(.filesDropped([pdf]))

        // then
        #expect(fixture.fakeFiles.released == [Self.file.id])
        #expect(fixture.state.lines.last == .prompt("담기 예산안.pdf"))
        #expect(fixture.transport.requests.last?.path == "/uploads")
    }

    @Test func 가져오기를제안했을때_글을붙여넣으면_파일을놓고기억을지우는지() async {
        // given
        let fixture = Fixture()
        await fixture.attach()
        await dropRejected(fixture)

        // when
        await fixture.send(.pasted("메모"))

        // then
        #expect(fixture.fakeFiles.released == [Self.file.id])
    }

    @Test func 북마크파일둘을놓았을때_둘다받지않는형식이면_나중파일만기억하는지() async {
        // given
        let fixture = Fixture()
        await fixture.attach()
        let second = DroppedFile(id: "file-2", name: "old.htm", size: 80)
        fixture.fakeFiles.texts[second.id] = Self.html
        await fixture.send(.filesDropped([Self.file, second]))

        // when
        await fixture.respond(status: 415, json: Self.unsupportedJSON("html"))
        await fixture.respond(status: 415, json: Self.unsupportedJSON("htm"))

        // then
        #expect(fixture.state.lines.suffix(4) == [
            .saveFailed(.unsupportedFormat(fileExtension: "html"), .file(name: "bookmarks.html")),
            .importSuggest(fileName: "bookmarks.html"),
            .saveFailed(.unsupportedFormat(fileExtension: "htm"), .file(name: "old.htm")),
            .importSuggest(fileName: "old.htm"),
        ])
        #expect(fixture.fakeFiles.released == [Self.file.id])
    }
}
