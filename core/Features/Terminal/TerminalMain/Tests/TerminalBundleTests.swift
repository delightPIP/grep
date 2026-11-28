import FeatureTerminalInterface
import TerminalDomain
import GrepCore
import GrepCoreTesting
import Testing

@testable import FeatureTerminal

@MainActor
struct TerminalBundleTests {
    @Test func 묶음만쳤을때_서버가목록을주면_묶음목록줄을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("묶음")
        await fixture.respond(json: #"{"bundles":[{"name":"pay","count":2},{"name":"empty","count":0}]}"#)

        // then
        #expect(fixture.transport.requests.last?.method == .get)
        #expect(fixture.transport.requests.last?.path == "/bundles")
        #expect(fixture.state.lines.last == .bundleList([
            BundleEntry(name: "pay", count: 2), BundleEntry(name: "empty", count: 0),
        ]))
    }

    @Test func 선택이있을때_묶음이름을치면_선택을넣고선택을비우는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()
        await fixture.pick([131, 140])

        // when
        await fixture.submit("묶음 pay")
        await fixture.respond(json: #"{"name":"pay","count":3,"alreadyCount":1}"#)

        // then
        #expect(fixture.transport.requests.last?.method == .post)
        #expect(fixture.transport.requests.last?.path == "/bundles/pay/items")
        #expect(fixture.transport.requests.last?.body == #"{"numbers":[131,140]}"#)
        #expect(fixture.state.lines.last == .bundleAdded(name: "pay", count: 3, alreadyCount: 1))
        #expect(fixture.state.selection.isEmpty)
    }

    @Test func 선택이없을때_묶음이름을치면_묶음안자료를보여주는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()
        let item = TerminalFixture.item(140)

        // when
        await fixture.submit("묶음 결제조사")
        await fixture.respond(
            json: #"{"name":"결제조사","total":11,"items":["# + TerminalFixture.json(item) + #"],"nextCursor":"c2"}"#
        )

        // then
        #expect(fixture.transport.requests.last?.method == .get)
        #expect(fixture.transport.requests.last?.path == "/bundles/%EA%B2%B0%EC%A0%9C%EC%A1%B0%EC%82%AC?limit=10")
        #expect(fixture.state.lines.last == .bundleView(name: "결제조사", total: 11, items: [item], hasMore: true))
    }

    @Test func 묶음안자료에다음쪽이있을때_더보기를누르면_같은줄에이어붙이는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()
        let first = TerminalFixture.item(140)
        let second = TerminalFixture.item(131)
        await fixture.submit("묶음 pay")
        await fixture.respond(json: #"{"name":"pay","total":2,"items":["# + TerminalFixture.json(first) + #"],"nextCursor":"c2"}"#)

        // when
        await fixture.send(.moreRequested)
        await fixture.respond(json: #"{"name":"pay","total":2,"items":["# + TerminalFixture.json(second) + #"],"nextCursor":null}"#)

        // then
        #expect(fixture.transport.requests.last?.path == "/bundles/pay?limit=10&cursor=c2")
        #expect(fixture.state.lines.last == .bundleView(name: "pay", total: 2, items: [first, second], hasMore: false))
    }

    @Test func 없는묶음을볼때_서버가404로답하면_없는묶음줄을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("묶음 nope")
        await fixture.respond(status: 404, json: #"{"code":"not_found"}"#)

        // then
        #expect(fixture.state.lines.last == .bundleNotFound(name: "nope"))
    }

    @Test(arguments: [
        ("묶음 " + String(repeating: "가", count: 21), BundleNameProblem.format),
        ("묶음 결제!", .format),
        ("묶음 2026", .reserved),
        ("묶음 #결제", .reserved),
        ("묶음 빼기", .reserved),
        ("묶음 지우기", .reserved),
    ])
    func 이름규칙에맞지않을때_묶음을치면_요청없이이름규칙줄을찍는지(input: String, problem: BundleNameProblem) async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit(input)

        // then
        #expect(fixture.transport.requests.isEmpty)
        #expect(fixture.state.lines.last == .bundleNameInvalid(problem))
    }

    @Test func 이름이20자일때_묶음을치면_서버에묻는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("묶음 " + String(repeating: "a", count: 19) + "_")

        // then
        #expect(fixture.transport.requests.count == 1)
    }

    @Test func 서버가이름규칙위반으로답할때_넣으면_이름규칙줄을찍고선택을남기는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()
        await fixture.pick([131])

        // when
        await fixture.submit("묶음 pay")
        await fixture.respond(status: 400, json: #"{"code":"invalid_bundle_name","reason":"reserved"}"#)

        // then
        #expect(fixture.state.lines.last == .bundleNameInvalid(.reserved))
        #expect(fixture.state.selection == [TerminalFixture.ref(131)])
    }

    @Test func 묶음에서뺄때_서버가남은건수를주면_뺌줄을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("묶음 pay 빼기 140 131")
        await fixture.respond(json: #"{"count":4}"#)

        // then
        #expect(fixture.transport.requests.last?.path == "/bundles/pay/items/remove")
        #expect(fixture.transport.requests.last?.body == #"{"numbers":[140,131]}"#)
        #expect(fixture.state.lines.last == .bundleUnpicked(name: "pay", remaining: 4))
    }

    @Test func 묶음에없는번호를뺄때_서버가거부하면_묶음에없음줄을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("묶음 pay 빼기 99")
        await fixture.respond(status: 400, json: #"{"code":"not_in_bundle","numbers":[99]}"#)

        // then
        #expect(fixture.state.lines.last == .notInBundle(name: "pay", numbers: [99]))
    }

    @Test func 빼기뒤번호가없을때_실행하면_요청없이빠진인자줄을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("묶음 pay 빼기")

        // then
        #expect(fixture.transport.requests.isEmpty)
        #expect(fixture.state.lines.last == .missingArgument(.pack))
    }

    @Test func 묶음을지울때_지우기를다시치면_묶음을지우는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("묶음 pay 지우기")
        await fixture.respond(json: #"{"name":"pay","total":3,"items":[],"nextCursor":null}"#)
        let asked = fixture.state.lines.last == .bundleDeleteConfirm(name: "pay", itemCount: 3)
        await fixture.submit("지우기")
        await fixture.respond(status: 204, json: "")

        // then
        #expect(asked)
        #expect(fixture.transport.requests.last?.method == .delete)
        #expect(fixture.transport.requests.last?.path == "/bundles/pay")
        #expect(fixture.state.lines.last == .bundleDeleted(name: "pay"))
    }

    @Test func 지우기확인중일때_다른입력을치면_취소하고지우지않는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()
        await fixture.submit("묶음 pay 지우기")
        await fixture.respond(json: #"{"name":"pay","total":3,"items":[],"nextCursor":null}"#)

        // when
        await fixture.submit("아니")

        // then
        #expect(fixture.transport.requests.allSatisfy { $0.method != .delete })
        #expect(fixture.state.lines.contains(.cancelled))
    }

    @Test func 묶음이름으로넘길때_서버가글을주면_복사하고빠진수를보이며선택을남기는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()
        await fixture.pick([7])

        // when
        await fixture.submit("넘기기 pay")
        await fixture.respond(json: #"{"text":"글","charCount":1,"items":[{"number":140,"title":"자료 140"}],"missingSummaryCount":0,"bundle":"pay","removedCount":1}"#)

        // then
        #expect(fixture.transport.requests.last?.path == "/handoff")
        #expect(fixture.transport.requests.last?.body == #"{"bundle":"pay"}"#)
        #expect(fixture.fakeClipboard.copied.last == "글")
        #expect(fixture.state.lines.last == .handedOff(HandoffResult(
            items: [ItemRef(number: 140, title: "자료 140")], bundle: "pay", removedCount: 1,
            charCount: 1, missingSummaryCount: 0, text: "글"
        )))
        #expect(fixture.state.selection == [TerminalFixture.ref(7)])
    }

    @Test func 없는묶음을넘길때_서버가404로답하면_없는묶음줄을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("넘기기 nope")
        await fixture.respond(status: 404, json: #"{"code":"not_found"}"#)

        // then
        #expect(fixture.state.lines.last == .bundleNotFound(name: "nope"))
    }

    @Test func 묶음줄이있을때_기록을남기고읽으면_같은줄로되살리는지() {
        // given
        let lines: [TerminalViewState.Line] = [
            .prompt("묶음"),
            .bundleList([BundleEntry(name: "pay", count: 2)]),
            .bundleAdded(name: "pay", count: 3, alreadyCount: 1),
            .bundleView(name: "pay", total: 1, items: [TerminalFixture.item(140)], hasMore: false),
            .bundleNotFound(name: "nope"),
            .bundleUnpicked(name: "pay", remaining: 2),
            .notInBundle(name: "pay", numbers: [99]),
            .bundleDeleteConfirm(name: "pay", itemCount: 3),
            .bundleDeleted(name: "pay"),
            .bundleNameInvalid(.reserved),
            .handedOff(HandoffResult(
                items: [ItemRef(number: 140, title: "자료 140")], bundle: "pay", removedCount: 1,
                charCount: 1, missingSummaryCount: 0, text: "글"
            )),
        ]
        let snapshot = TerminalHistory.Snapshot(lines: lines, input: "", selection: [])

        // when
        let restored = TerminalHistory.decode(TerminalHistory.encode(snapshot))

        // then
        #expect(restored?.lines == lines)
    }
}
