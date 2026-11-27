import FeatureTerminal
import FeatureTerminalInterface
import GrepCore
import GrepCoreTesting
import Testing

@MainActor
struct TerminalEventsTests {
    @Test func 고른자료복사에성공했을때_이벤트를보면_pick방식으로handoff_copied를보내는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach(itemCount: 5)
        await fixture.pick([30, 25])

        // when
        await fixture.submit("넘기기")
        await fixture.respond(json: #"{"text":"글","charCount":1,"missingSummaryCount":0,"items":[{"number":30,"title":"자료 30"},{"number":25,"title":"자료 25"}]}"#)

        // then
        let eventRequest = fixture.transport.requests.first { $0.path == "/events" }
        #expect(eventRequest?.method == .post)
        #expect(eventRequest?.body?.contains(#""name":"handoff_copied""#) == true)
        #expect(eventRequest?.body?.contains(#""method":"pick""#) == true)
        #expect(eventRequest?.body?.contains(#""numbers":[30,25]"#) == true)
    }

    @Test func 클립보드복사가거부됐을때_넘기기를하면_이벤트를보내지않는지() async {
        // given
        let fixture = TerminalFixture()
        fixture.fakeClipboard.result = .denied
        await fixture.attach(itemCount: 5)
        await fixture.pick([30])

        // when
        await fixture.submit("넘기기")
        await fixture.respond(json: #"{"text":"글","charCount":1,"missingSummaryCount":0,"items":[{"number":30,"title":"자료 30"}]}"#)

        // then
        #expect(!fixture.transport.requests.contains { $0.path == "/events" })
    }

    @Test func 이벤트보고가실패했을때_화면상태를보면_연결끊김이나오류줄을찍지않는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach(itemCount: 5)
        await fixture.pick([30])

        // when
        await fixture.submit("넘기기")
        await fixture.respond(json: #"{"text":"글","charCount":1,"missingSummaryCount":0,"items":[{"number":30,"title":"자료 30"}]}"#)
        await fixture.fail(.unreachable)

        // then
        #expect(!fixture.state.isOffline)
        #expect(fixture.state.lines.contains {
            if case .handedOff = $0 { return true }
            return false
        })
    }
}
