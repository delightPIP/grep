import FeatureTerminal
import FeatureTerminalInterface
import GrepCore
import GrepCoreTesting
import Testing

@MainActor
struct TerminalTrashTests {
    @Test func 자료를버릴때_서버가성공으로답하면_휴지통줄을찍고건수와선택을줄이는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach(itemCount: 5)
        await fixture.pick([5])

        // when
        await fixture.submit("버리기 5")
        await fixture.respond(json: #"{"items":[{"number":5,"title":"자료 5"}]}"#)

        // then
        #expect(fixture.transport.requests.last?.method == .post)
        #expect(fixture.transport.requests.last?.path == "/items/trash")
        #expect(fixture.state.lines.contains(.dropped([ItemRef(number: 5, title: "자료 5")])))
        #expect(fixture.state.itemCount == 4)
        #expect(fixture.state.selection.isEmpty)
    }

    @Test func 휴지통자료를되살릴때_서버가성공으로답하면_되살림줄을찍고건수를늘리는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach(itemCount: 4)

        // when
        await fixture.submit("되살리기 5")
        await fixture.respond(json: #"{"items":[{"number":5,"title":"자료 5"}]}"#)

        // then
        #expect(fixture.transport.requests.last?.method == .post)
        #expect(fixture.transport.requests.last?.path == "/items/restore")
        #expect(fixture.state.lines.contains(.revived([ItemRef(number: 5, title: "자료 5")])))
        #expect(fixture.state.itemCount == 5)
    }

    @Test func 없는번호를버릴때_서버가404로답하면_없는번호줄을찍고건수를유지하는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach(itemCount: 5)

        // when
        await fixture.submit("버리기 99")
        await fixture.respond(status: 404, json: #"{"code":"not_found","numbers":[99]}"#)

        // then
        #expect(fixture.state.lines.contains(.notFound(numbers: [99])))
        #expect(fixture.state.itemCount == 5)
    }

    @Test func 버리기나되살리기인자가없을때_실행하면_요청없이빠진인자줄을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("버리기")
        await fixture.submit("되살리기")

        // then
        #expect(fixture.transport.requests.isEmpty)
        #expect(fixture.state.lines.contains(.missingArgument(.drop)))
        #expect(fixture.state.lines.contains(.missingArgument(.revive)))
    }

    @Test func 범위로2건이상버릴때_확인후버리기를입력하면_펼친번호로요청하는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach(itemCount: 10)

        // when
        await fixture.submit("버리기 1-3")
        let askedConfirm = fixture.state.lines.contains(.dropConfirm(total: 3))
        let requestsBeforeConfirm = fixture.transport.requests.count
        await fixture.submit("버리기")
        await fixture.respond(json: #"{"items":[{"number":1,"title":"자료 1"},{"number":2,"title":"자료 2"},{"number":3,"title":"자료 3"}]}"#)

        // then
        #expect(askedConfirm)
        #expect(requestsBeforeConfirm == 0)
        #expect(fixture.transport.requests.last?.body == #"{"numbers":[1,2,3]}"#)
        #expect(fixture.state.itemCount == 7)
    }

    @Test func 버리기확인대기중일때_다른명령을치면_취소됨을찍고그명령을실행하는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach(itemCount: 10)
        await fixture.submit("버리기 1 2")

        // when
        await fixture.submit("도움말")

        // then
        #expect(fixture.transport.requests.isEmpty)
        #expect(fixture.state.lines.contains(.cancelled))
        #expect(fixture.state.lines.contains(.guide))
    }

    @Test func 휴지통명령을칠때_목록과더보기를불러오는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach(itemCount: 5)
        let entry1 = #"{"item":\#(TerminalFixture.json(TerminalFixture.item(1))),"trashedAt":"2026-11-27T01:00:00Z","daysLeft":30}"#
        let entry2 = #"{"item":\#(TerminalFixture.json(TerminalFixture.item(2))),"trashedAt":"2026-11-26T01:00:00Z","daysLeft":29}"#

        // when
        await fixture.submit("휴지통")
        await fixture.respond(json: #"{"items":[\#(entry1)],"total":2,"nextCursor":"c2"}"#)
        await fixture.send(.moreRequested)
        await fixture.respond(json: #"{"items":[\#(entry2)],"total":2,"nextCursor":null}"#)

        // then
        guard case .binList(let total, let items, let hasMore) = fixture.state.lines.last else {
            Issue.record("Expected binList")
            return
        }
        #expect(total == 2)
        #expect(items.map(\.item.number) == [1, 2])
        #expect(!hasMore)
    }

    @Test func 휴지통비우기를칠때_전체건수로확인받고비우기를치면_영구삭제하는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach(itemCount: 5)

        // when
        await fixture.submit("휴지통 비우기")
        await fixture.respond(json: #"{"items":[],"total":3,"nextCursor":null}"#)
        let asked = fixture.state.lines.contains(.binEmptyConfirm(total: 3))
        await fixture.submit("비우기")
        await fixture.respond(json: #"{"count":3}"#)

        // then
        #expect(asked)
        #expect(fixture.transport.requests.last?.method == .delete)
        #expect(fixture.transport.requests.last?.path == "/items/trash")
        #expect(fixture.state.lines.contains(.binEmptied(count: 3)))
    }
}
