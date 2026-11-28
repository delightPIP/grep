import FeatureTerminalInterface
import GrepCore
import GrepCoreTesting
import Testing

@testable import FeatureTerminal

/// #168 터미널이 자료·연결이 바뀐 것을 부모에게 알린다. 보관함·설정이 다시 받을지는 부모가 정한다.
@MainActor
struct TerminalChangeNoticeTests {
    private typealias Fixture = TerminalFixture

    private let fixture = Fixture()

    @Test func 담기를쳤을때_저장되면_자료가바뀌었다고알리는지() async {
        // given
        await fixture.attach()
        await fixture.submit("담기 https://example.com")

        // when
        await fixture.respond(status: 201, json: #"{"result":"saved","item":\#(Fixture.json(Fixture.item(35)))}"#)

        // then
        #expect(fixture.listener.itemsChangedCount == 1)
    }

    @Test func 담기를쳤을때_이미있으면_알리지않는지() async {
        // given
        await fixture.attach()
        await fixture.submit("담기 https://example.com")

        // when
        await fixture.respond(json: #"{"result":"duplicate","item":\#(Fixture.json(Fixture.item(35)))}"#)

        // then
        #expect(fixture.listener.itemsChangedCount == 0)
    }

    @Test func 버리기를쳤을때_휴지통으로옮기면_자료가바뀌었다고알리는지() async {
        // given
        await fixture.attach()
        await fixture.submit("버리기 5")

        // when
        await fixture.respond(json: #"{"items":[{"number":5,"title":"자료 5"}]}"#)

        // then
        #expect(fixture.listener.itemsChangedCount == 1)
    }

    @Test func 연결끊기를확인했을때_끊기면_연결이바뀌었다고알리는지() async {
        // given
        await fixture.attach()
        await fixture.submit("연결 끊기 1")
        await fixture.respond(json: #"{"mcpUrl":"https://grep.example/mcp","connections":[{"number":1,"client":"Claude","connectedAt":"2026-11-20T10:00:00+09:00","lastReadAt":null}]}"#)
        await fixture.submit("끊기")

        // when
        await fixture.respond(json: #"{"result":"ended","client":"Claude"}"#)

        // then
        #expect(fixture.listener.connectionsChangedCount == 1)
    }
}
