import FeatureTerminal
import FeatureTerminalInterface
import GrepCore
import GrepCoreTesting
import Testing

@MainActor
struct TerminalTypoTests {
    @Test func 한글명령오타를쳤을때_제안을붙이고빈엔터를치면_제안된명령을실행하는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("찻기 결제")
        let suggestedLine = fixture.state.lines.last
        await fixture.submit("")
        await fixture.respond(json: #"{"items":[],"total":0,"nextCursor":null}"#)
        await fixture.respond(json: #"{"items":[],"nextCursor":null}"#)

        // then
        #expect(suggestedLine == .unknownCommand("찻기", suggestion: "찾기 결제"))
        #expect(fixture.transport.requests.first?.path.hasPrefix("/items/search?") == true)
    }

    @Test func 영문명령오타를쳤을때_가까운영문명령을제안하는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("seak pay")

        // then
        #expect(fixture.state.lines.last == .unknownCommand("seak", suggestion: "seek pay"))
    }

    @Test func 오타제안이떠있을때_다른명령을치면_제안이사라지고빈엔터에실행되지않는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()
        await fixture.submit("찻기 결제")

        // when
        await fixture.submit("도움말")
        await fixture.submit("")

        // then
        #expect(fixture.transport.requests.isEmpty)
        #expect(fixture.state.lines.last == .guide)
    }
}
