import FeatureTerminalInterface
import TerminalDomain
import GrepCore
import GrepCoreTesting
import Testing

@testable import FeatureTerminal

/// #66: 이어 쓰기 `찾기 … | 넘기기`(commands 4절)와 건수별 확인(COM-008 규칙 1~4), 확인의 답(COM-007).
@MainActor
struct TerminalPipeTests {
    private typealias Fixture = TerminalFixture
    private let fixture = Fixture()
    private static let typed = "찾기 pay | 넘기기"
    private static let firstPagePath = "/items/search?q=pay&limit=10"

    private static func items(_ range: ClosedRange<Int>) -> [ItemSummary] {
        range.map { Fixture.item($0) }
    }

    /// `찾기 pay | 넘기기`를 치고 서버가 `total`건 중 앞 10건까지 답하게 한다. 자료 번호는 1부터다.
    private func search(total: Int) async {
        await fixture.submit(Self.typed)
        await fixture.respond(json: Fixture.searchJSON(
            Self.items(1...min(total, 10)), total: total, nextCursor: total > 10 ? "next" : nil
        ))
    }

    // MARK: 해석

    @Test(arguments: ["찾기 pay | 넘기기", "seek pay | handoff", "찾기 pay ㅣ 넘기기", "찾기 pay|넘기기", "찾기 pay |  넘기기 "])
    func 터미널화면일때_찾기와넘기기를이어쓰면_찾기를먼저요청하는지(typed: String) async {
        // given
        await fixture.attach()

        // when
        await fixture.submit(typed)

        // then
        #expect(fixture.state.lines == [.prompt(typed)])
        #expect(fixture.state.input == "")
        #expect(fixture.transport.requests == [Fixture.get(Self.firstPagePath)])
    }

    @Test func 터미널화면일때_낱자ㅣ를붙여쓰면_이어쓰기로보지않고검색어로찾는지() async {
        // given
        await fixture.attach()

        // when
        await fixture.submit("찾기 payㅣ넘기기")

        // then
        #expect(fixture.transport.requests == [Fixture.get("/items/search?q=pay%E3%85%A3%EB%84%98%EA%B8%B0%EA%B8%B0&limit=10")])
    }

    @Test(arguments: [("찾기 pay | 고르기 1", "고르기 1"), ("찾기 pay | 넘기기 결제조사", "넘기기 결제조사"), ("찾기 pay | 찻기", "찻기")])
    func 터미널화면일때_넘기기가아닌명령을이어쓰면_요청없이없는명령으로그리는지(typed: String, tail: String) async {
        // given
        await fixture.attach()

        // when
        await fixture.submit(typed)

        // then
        #expect(fixture.state.lines == [.prompt(typed), .unknownCommand(tail)])
        #expect(fixture.transport.requests.isEmpty)
    }

    @Test(arguments: [("찾기 | 넘기기", TerminalViewState.Line.missingArgument(.seek)), ("찾기 ㅣ 넘기기", .missingArgument(.seek)),
        ("찾기 # | 넘기기", .missingTag),])
    func 터미널화면일때_검색어없이이어쓰면_요청없이찾기의빠진인자줄을그리는지(
        typed: String, line: TerminalViewState.Line
    ) async {
        // given
        await fixture.attach()

        // when
        await fixture.submit(typed)

        // then
        #expect(fixture.state.lines == [.prompt(typed), line])
        #expect(fixture.transport.requests.isEmpty)
    }

    // MARK: 건수별 동작(COM-008 규칙 1~3)

    @Test func 이어쓴찾기를기다릴때_5건이오면_묻지않고결과순서로복사하는지() async {
        // given
        await fixture.attach()

        // when
        await search(total: 5)
        let result = Fixture.handoff([1, 2, 3, 4, 5])
        await fixture.respond(json: Fixture.handoffJSON(result))

        // then
        #expect(fixture.transport.requests.filter { $0.path != "/events" }.last == Fixture.handoffRequest([1, 2, 3, 4, 5]))
        #expect(fixture.fakeClipboard.copied == [result.text])
        #expect(fixture.state.lines == [.prompt(Self.typed), .handedOff(result)])
        #expect(fixture.state.selection.isEmpty)
    }

    @Test func 선택이있을때_이어쓰기로넘기기에성공해도_기존선택을그대로두는지() async {
        // given
        await fixture.attach()
        await fixture.pick([30, 25])

        // when
        await search(total: 3)
        let result = Fixture.handoff([1, 2, 3])
        await fixture.respond(json: Fixture.handoffJSON(result))

        // then: 이어 쓰기는 찾기 결과를 넘기고 이미 고른 선택은 건드리지 않는다(COM-008 규칙 9).
        #expect(fixture.fakeClipboard.copied == [result.text])
        #expect(fixture.state.lines.last == .handedOff(result))
        #expect(fixture.state.selection == [Fixture.ref(30), Fixture.ref(25)])
    }

    @Test(arguments: [6, 10, 11])
    func 이어쓴찾기를기다릴때_5건을넘게오면_복사하지않고확인줄을그리는지(total: Int) async {
        // given
        await fixture.attach()

        // when
        await search(total: total)

        // then
        #expect(fixture.state.lines == [.prompt(Self.typed), .handoffConfirm(total: total)])
        #expect(fixture.transport.requests == [Fixture.get(Self.firstPagePath)])
        #expect(fixture.fakeClipboard.copied.isEmpty)
    }

    @Test func 이어쓴찾기를기다릴때_0건이오면_넘기지않고0건과최근자료를그리는지() async {
        // given
        await fixture.attach()
        await fixture.submit(Self.typed)
        await fixture.respond(json: Fixture.searchJSON([], total: 0))

        // when
        await fixture.respond(json: #"{"items":[\#(Fixture.json(Fixture.item(9)))],"nextCursor":null}"#)

        // then
        let query = SearchQuery(text: "pay", words: "pay", tags: [])
        #expect(fixture.state.lines == [.prompt(Self.typed), .noResults(query: query, recent: [Fixture.item(9)])])
        #expect(fixture.fakeClipboard.copied.isEmpty)
    }

    @Test func 이어쓴찾기를기다릴때_서버에닿지못하면_찾기실패줄과다시칠명령을그리는지() async {
        // given
        await fixture.attach()
        await fixture.submit(Self.typed)

        // when
        await fixture.fail(.unreachable)

        // then
        #expect(fixture.state.lines == [
            .prompt(Self.typed), .commandFailed(command: .seek, reason: .disconnected, retry: Self.typed),
        ])
    }

    // MARK: 확인의 답(COM-007)

    @Test(arguments: [(6, "전부"), (10, " 전부  ")])
    func 열건이하확인을기다릴때_전부라고답하면_더찾지않고전부복사하는지(total: Int, answer: String) async {
        // given
        await fixture.attach()
        await search(total: total)
        let numbers = Array(1...total)
        let result = Fixture.handoff(numbers)

        // when
        await fixture.submit(answer)
        await fixture.respond(json: Fixture.handoffJSON(result))

        // then
        #expect(fixture.transport.requests.filter { $0.path != "/events" }.suffix(2) == [Fixture.get(Self.firstPagePath), Fixture.handoffRequest(numbers)])
        #expect(fixture.fakeClipboard.copied == [result.text])
        #expect(fixture.state.lines.suffix(2) == [.prompt(answer), .handedOff(result)])
    }

    @Test func 열한건확인을기다릴때_앞10이라고답하면_앞열건만복사하는지() async {
        // given
        await fixture.attach()
        await search(total: 11)
        let result = Fixture.handoff(Array(1...10))

        // when
        await fixture.submit("앞10")
        await fixture.respond(json: Fixture.handoffJSON(result))

        // then
        #expect(fixture.transport.requests.filter { $0.path != "/events" }.last == Fixture.handoffRequest(Array(1...10)))
        #expect(fixture.fakeClipboard.copied == [result.text])
    }

    @Test func 열한건확인을기다릴때_전부라고답하면_남은쪽을받아모두복사하는지() async {
        // given
        await fixture.attach()
        await search(total: 11)
        let result = Fixture.handoff(Array(1...11))

        // when
        await fixture.submit("전부")
        await fixture.respond(json: Fixture.searchJSON([Fixture.item(11)], total: 11))
        await fixture.respond(json: Fixture.handoffJSON(result))

        // then
        #expect(fixture.transport.requests.filter { $0.path != "/events" }.suffix(2) == [
            Fixture.get("/items/search?q=pay&limit=50&cursor=next"), Fixture.handoffRequest(Array(1...11)),
        ])
        #expect(fixture.state.lines.suffix(2) == [.prompt("전부"), .handedOff(result)])
    }

    @Test func 열한건확인에전부라고답했을때_남은쪽을받지못하면_복사실패줄을그리는지() async {
        // given
        await fixture.attach()
        await search(total: 11)
        await fixture.submit("전부")

        // when
        await fixture.fail(.timedOut)

        // then
        #expect(fixture.state.lines.last == .handoffFailed(reason: .timedOut, preview: nil))
        #expect(fixture.fakeClipboard.copied.isEmpty)
    }

    @Test func 열건확인을기다릴때_앞10이라고답하면_선택지가아니라취소하고없는명령으로그리는지() async {
        // given
        await fixture.attach()
        await search(total: 10)

        // when
        await fixture.submit("앞10")

        // then
        #expect(fixture.state.lines.suffix(3) == [.cancelled, .prompt("앞10"), .unknownCommand("앞10")])
        #expect(fixture.fakeClipboard.copied.isEmpty)
    }

    @Test func 이어쓴찾기를기다릴때_그새다른명령을치면_늦게온확인을묻자마자취소하는지() async {
        // given
        await fixture.attach()
        await fixture.submit(Self.typed)
        await fixture.submit("도움말")

        // when
        await fixture.respond(json: Fixture.searchJSON(Self.items(1...8), total: 8))
        await fixture.submit("전부")

        // then
        #expect(fixture.state.lines == [
            .prompt(Self.typed), .prompt("도움말"), .guide, .handoffConfirm(total: 8), .cancelled,
            .prompt("전부"), .unknownCommand("전부"),
        ])
        #expect(fixture.fakeClipboard.copied.isEmpty)
    }

    @Test func 확인을기다릴때_다른명령을치면_취소됨을찍고그명령을실행하는지() async {
        // given
        await fixture.attach()
        await search(total: 8)

        // when
        await fixture.submit("찾기 tumbler")

        // then
        #expect(fixture.state.lines.suffix(2) == [.cancelled, .prompt("찾기 tumbler")])
        #expect(fixture.transport.requests.last == Fixture.get("/items/search?q=tumbler&limit=10"))
        #expect(fixture.fakeClipboard.copied.isEmpty)
    }

    @Test func 확인을기다릴때_실행낱말뒤에다른낱말을붙이면_취소하고새명령으로보는지() async {
        // given
        await fixture.attach()
        await search(total: 8)

        // when
        await fixture.submit("전부 다")

        // then
        #expect(fixture.state.lines.suffix(3) == [.cancelled, .prompt("전부 다"), .unknownCommand("전부")])
        #expect(fixture.fakeClipboard.copied.isEmpty)
    }

    @Test(arguments: ["", "   "])
    func 확인을기다릴때_빈줄로엔터를치면_취소됨만찍는지(answer: String) async {
        // given
        await fixture.attach()
        await search(total: 8)

        // when
        await fixture.submit(answer)

        // then
        #expect(fixture.state.lines == [.prompt(Self.typed), .handoffConfirm(total: 8), .cancelled])
        #expect(fixture.state.input == "")
        #expect(fixture.transport.requests.count == 1)
    }

    @Test func 확인이취소된뒤일때_전부라고치면_넘기지않고없는명령으로그리는지() async {
        // given
        await fixture.attach()
        await search(total: 8)
        await fixture.submit("")

        // when
        await fixture.submit("전부")

        // then
        #expect(fixture.state.lines.suffix(2) == [.prompt("전부"), .unknownCommand("전부")])
        #expect(fixture.fakeClipboard.copied.isEmpty)
    }

    @Test func 확인을기다릴때_글을붙여넣으면_취소됨을찍고저장하는지() async {
        // given
        await fixture.attach()
        await search(total: 8)

        // when
        await fixture.send(.pasted("https://example.com/a"))

        // then
        #expect(fixture.state.lines.suffix(2) == [.cancelled, .prompt("담기 https://example.com/a")])
        #expect(fixture.transport.requests.last?.path == "/items")
    }
}
