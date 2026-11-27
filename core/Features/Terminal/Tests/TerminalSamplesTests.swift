import FeatureTerminal
import FeatureTerminalInterface
import GrepCore
import GrepCoreTesting
import Testing

@MainActor
struct TerminalSamplesTests {
    @Test func 샘플저장버튼을눌렀을때_서버가201로답하면_완료줄과목록을찍고건수를올리는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach(itemCount: 0)
        let sample1 = TerminalFixture.item(1)
        let sample2 = TerminalFixture.item(2)

        // when
        await fixture.send(.samplesRequested)
        await fixture.respond(status: 201, json: #"{"firstNumber":1,"lastNumber":8}"#)
        await fixture.respond(json: #"{"items":[\#(TerminalFixture.json(sample2)),\#(TerminalFixture.json(sample1))],"nextCursor":null}"#)

        // then
        #expect(fixture.transport.requests.first?.method == .post)
        #expect(fixture.transport.requests.first?.path == "/samples")
        #expect(fixture.state.itemCount == 8)
        #expect(fixture.state.lines.contains(.samplesSaved(firstNumber: 1, lastNumber: 8, items: [sample2, sample1])))
    }

    @Test func 이미샘플을받은계정일때_다시요청해200을받으면_건수를중복증가시키지않는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach(itemCount: 8)

        // when
        await fixture.send(.samplesRequested)
        await fixture.respond(status: 200, json: #"{"firstNumber":1,"lastNumber":8}"#)
        await fixture.respond(json: #"{"items":[],"nextCursor":null}"#)

        // then
        #expect(fixture.state.itemCount == 8)
        #expect(fixture.state.lines.contains(.samplesSaved(firstNumber: 1, lastNumber: 8, items: [])))
    }
}
