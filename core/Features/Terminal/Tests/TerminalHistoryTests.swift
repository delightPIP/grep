import FeatureTerminalInterface
import GrepCore
import GrepCoreTesting
import Testing

@testable import FeatureTerminal

/// #68: 터미널 기록을 이 기기에 남기고 되살린다(COM-009).
@MainActor
struct TerminalHistoryTests {
    private typealias Fixture = TerminalFixture
    private typealias Snapshot = TerminalHistory.Snapshot

    private static func record(_ snapshot: Snapshot, subject: String = Fixture.subject) -> HistoryRecord {
        HistoryRecord(subject: subject, payload: TerminalHistory.encode(snapshot))
    }

    private static let saved = Snapshot(
        lines: [.prompt("고르기 25 30"), .picked([Fixture.ref(25), Fixture.ref(30)])],
        input: "넘기",
        selection: [Fixture.ref(25), Fixture.ref(30)]
    )

    private func snapshot(of fixture: Fixture) -> Snapshot? {
        fixture.fakeHistory.record.flatMap { TerminalHistory.decode($0.payload) }
    }

    // MARK: 남기기(규칙 1)

    @Test func 터미널화면일때_명령을치고글을치면_출력과치던글과선택을계정과함께남기는지() async {
        // given
        let fixture = Fixture()
        await fixture.attach()
        await fixture.pick([25])

        // when
        await fixture.send(.inputChanged("넘기"))

        // then
        #expect(fixture.fakeHistory.record?.subject == Fixture.subject)
        #expect(snapshot(of: fixture) == Snapshot(
            lines: [.prompt("고르기 25"), .picked([Fixture.ref(25)])], input: "넘기", selection: [Fixture.ref(25)]
        ))
    }

    @Test func 토큰을받지못할때_글을쳐도_기록을남기지않는지() async {
        // given
        let fixture = Fixture()
        fixture.auth.token = nil
        await fixture.attach(itemCount: nil)

        // when
        await fixture.send(.inputChanged("찾"))

        // then
        #expect(fixture.fakeHistory.record == nil)
    }

    @Test func 줄이상한보다많을때_기록을남기면_최근줄만명령줄부터남기는지() {
        // given
        let blocks = (1...TerminalHistory.maxLines).flatMap { number -> [TerminalViewState.Line] in
            [.prompt("찾기 \(number)"), .cancelled, .reconnected]
        }

        // when
        let kept = TerminalHistory.decode(TerminalHistory.encode(Snapshot(lines: blocks, input: "", selection: [])))?.lines

        // then
        #expect(kept?.count == TerminalHistory.maxLines - 2)
        #expect(kept?.first == .prompt("찾기 135"))
        #expect(kept?.last == .reconnected)
    }

    @Test func 모든줄종류가있을때_기록으로바꿨다되돌리면_같은줄이되는지() {
        // given
        let query = SearchQuery(text: "pay #ui", words: "pay", tags: ["ui"])
        let item = ItemSummary(
            number: 7, kind: .file, title: "보고서.pdf", source: nil, status: .blocked, blockedReason: .noText,
            listSummary: "요약", summarySource: .user, partialNote: "앞부분만", tags: ["결제"], matchedIn: .imageText,
            savedAt: "2026-11-27T10:00:00+09:00"
        )
        let lines: [TerminalViewState.Line] = [
            .prompt("찾기 pay"), .unknownCommand("찻기"), .missingArgument(.seek), .missingTag,
            .saved(item), .alreadySaved(Fixture.item(25)), .inTrash(number: 3),
            .saveFailed(.disconnected, .inputKept), .saveFailed(.timedOut, .retry("담기 글")),
            .saveFailed(.serverError, .file(name: "a.hwp")),
            .saveFailed(.unsupportedFormat(fileExtension: "hwp"), .file(name: "a.hwp")),
            .saveFailed(.tooLarge(fileName: "b.pdf", bytes: 30_000_000), .file(name: "b.pdf")),
            .recentList(items: [item, Fixture.item(25, status: .processing, summary: nil)], hasMore: true),
            .searchResult(query: query, total: 23, items: [item], hasMore: false),
            .noResults(query: query, recent: [item]),
            .picked([Fixture.ref(25)]), .notFound(numbers: [98, 99]), .invalidNumber("0"),
            .handedOff(Fixture.handoff([25, 30], missingSummaryCount: 1)),
            .handoffFailed(reason: .clipboardDenied, preview: "넘길 글"), .handoffFailed(reason: .serverError, preview: nil),
            .commandFailed(command: .pick, reason: .timedOut, retry: "고르기 25"),
            .commandFailed(command: .recent, reason: .disconnected, retry: "최근"),
            .handoffConfirm(total: 8), .cancelled, .welcome, .guide, .reconnected,
        ] + CommandName.allCases.map { .about($0) }
        let snapshot = Snapshot(lines: lines, input: "치던 글", selection: [Fixture.ref(25), Fixture.ref(30)])

        // when
        let restored = TerminalHistory.decode(TerminalHistory.encode(snapshot))

        // then
        #expect(restored == snapshot)
    }

    // MARK: 되살리기(규칙 1·4·5)

    @Test func 같은계정의기록이있을때_터미널을열면_출력과치던글과선택을되살리는지() async {
        // given
        let fixture = Fixture(history: Self.record(Self.saved))

        // when
        await fixture.attach(itemCount: 0)

        // then
        #expect(fixture.state.lines == Self.saved.lines)
        #expect(fixture.state.input == "넘기")
        #expect(fixture.state.selection == Self.saved.selection)
    }

    @Test func 명령을친뒤일때_터미널을닫았다다시열면_그대로보이는지() async {
        // given
        let fixture = Fixture()
        await fixture.attach()
        await fixture.submit("도움말")
        await fixture.send(.inputChanged("찾기 결"))
        await fixture.detach()

        // when
        await fixture.attach()

        // then
        #expect(fixture.state.lines == [.prompt("도움말"), .guide])
        #expect(fixture.state.input == "찾기 결")
    }

    @Test func 기록이없을때_터미널을열면_0건은첫화면을1건이상은빈화면을보이는지() async {
        // given
        let empty = Fixture()
        let filled = Fixture()

        // when
        await empty.attach(itemCount: 0)
        await filled.attach(itemCount: 3)

        // then
        #expect(empty.state.lines == [.welcome])
        #expect(filled.state.lines.isEmpty)
    }

    @Test func 읽을수없는기록이있을때_터미널을열면_빈화면으로시작하는지() async {
        // given
        let fixture = Fixture(history: HistoryRecord(subject: Fixture.subject, payload: "{broken"))

        // when
        await fixture.attach()

        // then
        #expect(fixture.state.lines.isEmpty)
        #expect(fixture.state.input == "")
    }

    @Test func 확인을기다리다끊긴기록이있을때_터미널을열면_취소된것으로보는지() async {
        // given
        let waiting = Snapshot(lines: [.prompt("찾기 pay | 넘기기"), .handoffConfirm(total: 8)], input: "", selection: [])
        let fixture = Fixture(history: Self.record(waiting))
        await fixture.attach()

        // when
        await fixture.submit("전부")

        // then
        #expect(fixture.state.lines == waiting.lines + [.cancelled, .prompt("전부"), .unknownCommand("전부")])
        #expect(fixture.fakeClipboard.copied.isEmpty)
    }

    @Test func 확인뒤에다른줄이찍힌기록이있을때_터미널을열면_그래도취소된것으로보는지() async {
        // given
        let waiting = Snapshot(
            lines: [.prompt("찾기 pay | 넘기기"), .handoffConfirm(total: 8), .reconnected], input: "", selection: []
        )
        let fixture = Fixture(history: Self.record(waiting))

        // when
        await fixture.attach()

        // then
        #expect(fixture.state.lines == waiting.lines + [.cancelled])
    }

    @Test func 더보기가남은목록의기록이있을때_터미널을열면_이어받을수없는더보기를빼는지() async {
        // given
        let query = SearchQuery(text: "pay", words: "pay", tags: [])
        let listed = Snapshot(
            lines: [
                .prompt("찾기 pay"), .searchResult(query: query, total: 23, items: [Fixture.item(1)], hasMore: true),
                .prompt("최근"), .recentList(items: [Fixture.item(2)], hasMore: true),
            ],
            input: "", selection: []
        )
        let fixture = Fixture(history: Self.record(listed))

        // when
        await fixture.attach()
        await fixture.send(.moreRequested)

        // then
        #expect(fixture.state.lines == [
            .prompt("찾기 pay"), .searchResult(query: query, total: 23, items: [Fixture.item(1)], hasMore: false),
            .prompt("최근"), .recentList(items: [Fixture.item(2)], hasMore: false),
        ])
        #expect(fixture.transport.requests.isEmpty)
    }

    // MARK: 선택 맞추기(규칙 6)

    @Test func 선택이든기록이있을때_터미널을열면_선택한번호가아직있는지확인하는지() async {
        // given
        let fixture = Fixture(history: Self.record(Self.saved))

        // when
        await fixture.attach()

        // then
        #expect(fixture.transport.requests == [Fixture.get("/items/status?numbers=25,30")])
    }

    @Test func 되살린선택을확인할때_지워진자료가있으면_선택에서만빼고출력은그대로두는지() async {
        // given
        let fixture = Fixture(history: Self.record(Self.saved))
        await fixture.attach()

        // when
        await fixture.respond(json: Fixture.lookupJSON([Fixture.item(25)], missing: [30]))

        // then
        #expect(fixture.state.selection == [Fixture.ref(25)])
        #expect(fixture.state.lines == Self.saved.lines)
        #expect(snapshot(of: fixture)?.selection == [Fixture.ref(25)])
    }

    @Test func 되살린선택을확인할때_서버에닿지못하면_선택을그대로두는지() async {
        // given
        let fixture = Fixture(history: Self.record(Self.saved))
        await fixture.attach()

        // when
        await fixture.fail(.unreachable)

        // then
        #expect(fixture.state.selection == Self.saved.selection)
        #expect(fixture.state.lines == Self.saved.lines)
    }

    // MARK: 지우기(규칙 2·3)와 만료(규칙 4)

    @Test func 다른계정의기록이있을때_터미널을열면_되살리지않고지우는지() async {
        // given
        let fixture = Fixture(history: Self.record(Self.saved, subject: "user-b"))

        // when
        await fixture.attach(itemCount: nil)

        // then
        #expect(fixture.state.lines.isEmpty)
        #expect(fixture.state.selection.isEmpty)
        #expect(fixture.fakeHistory.record == nil)
        #expect(fixture.transport.requests.isEmpty)
    }

    @Test func 기록이남아있을때_로그아웃을치면_기록을지우고부모에게알리는지() async {
        // given
        let fixture = Fixture()
        await fixture.attach()
        await fixture.submit("도움말")

        // when
        await fixture.submit("로그아웃")

        // then
        #expect(fixture.fakeHistory.record == nil)
        #expect(fixture.listener.signOutRequestCount == 1)
    }

    @Test func 로그아웃을친뒤일때_글을더쳐도_기록을다시남기지않는지() async {
        // given
        let fixture = Fixture()
        await fixture.attach()
        await fixture.submit("로그아웃")

        // when
        await fixture.send(.inputChanged("찾"))

        // then
        #expect(fixture.fakeHistory.record == nil)
    }

    @Test func 기록을되살리기전일때_로그아웃을치면_늦게끝난되살리기가기록을다시남기지않는지() async {
        // given
        let fixture = Fixture(history: Self.record(Self.saved))
        fixture.attachWithoutRunning()

        // when
        await fixture.submit("로그아웃")
        await fixture.send(.inputChanged("찾"))

        // then
        #expect(fixture.fakeHistory.record == nil)
        #expect(fixture.state.lines.isEmpty)
    }

    @Test func 기록이남아있을때_세션이만료되면_기록을지우지않는지() async {
        // given
        let fixture = Fixture()
        await fixture.attach()
        await fixture.submit("최근")

        // when
        await fixture.respond(status: 401, json: Fixture.sessionExpiredJSON)

        // then
        #expect(fixture.listener.expiredInputs == ["최근"])
        #expect(snapshot(of: fixture) == Snapshot(lines: [.prompt("최근")], input: "최근", selection: []))
    }
}
