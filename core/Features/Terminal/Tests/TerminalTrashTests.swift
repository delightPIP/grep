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
}
