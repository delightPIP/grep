import FeatureTerminal
import FeatureTerminalInterface
import GrepCore
import GrepCoreTesting
import Testing

@MainActor
struct TerminalReviseTests {
    @Test func 고치기번호를칠때_편집을열고제출하면_PATCH후고침줄을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach(itemCount: 5)
        let original = TerminalFixture.item(5, summary: "원래 요약")
        let updated = ItemSummary(
            number: 5, kind: .link, title: "새 제목", source: "example.com", status: .ready,
            listSummary: "직접 쓴 요약", summarySource: .user, tags: [], savedAt: "2026-11-27T10:00:00+09:00"
        )

        // when
        await fixture.submit("고치기 5")
        await fixture.respond(json: TerminalFixture.lookupJSON([original]))
        let opened = fixture.state.revising
        await fixture.send(.reviseSubmitted(number: 5, title: "새 제목", summary: "직접 쓴 요약"))
        await fixture.respond(json: TerminalFixture.json(updated))

        // then
        #expect(opened == Revising(number: 5, title: "자료 5", summary: "원래 요약"))
        #expect(fixture.state.revising == nil)
        #expect(fixture.transport.requests.last?.method == .patch)
        #expect(fixture.transport.requests.last?.path == "/items/5")
        #expect(fixture.state.lines.contains(.revised(updated)))
    }

    @Test func 고치기편집중일때_취소하면_편집상태를닫고취소됨을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach(itemCount: 5)
        await fixture.submit("고치기 5")
        await fixture.respond(json: TerminalFixture.lookupJSON([TerminalFixture.item(5)]))

        // when
        await fixture.send(.reviseCancelled)

        // then
        #expect(fixture.state.revising == nil)
        #expect(fixture.state.lines.contains(.cancelled))
    }

    @Test func 태그지우기명령을칠때_PATCH가성공하면_태그지움줄을찍는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach(itemCount: 5)
        let updated = TerminalFixture.item(5)

        // when
        await fixture.submit("고치기 5 -#광고 -#스팸")
        await fixture.respond(json: TerminalFixture.json(updated))

        // then
        #expect(fixture.transport.requests.last?.method == .patch)
        #expect(fixture.transport.requests.last?.path == "/items/5")
        #expect(fixture.state.lines.contains(.tagsRemoved(item: updated, tags: ["광고", "스팸"])))
    }

    @Test func 고른파일자료를고칠때_제목을바꾸면_선택에종류와출처를그대로두는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach(itemCount: 5)
        let file = ItemSummary(
            number: 5, kind: .file, title: "명세.pdf", source: "pdf", status: .ready, tags: [],
            savedAt: "2026-11-27T10:00:00+09:00"
        )
        let updated = ItemSummary(
            number: 5, kind: .file, title: "새 명세.pdf", source: "pdf", status: .ready, tags: [],
            savedAt: "2026-11-27T10:00:00+09:00"
        )
        await fixture.submit("고르기 5")
        await fixture.respond(json: TerminalFixture.lookupJSON([file]))
        await fixture.submit("고치기 5")
        await fixture.respond(json: TerminalFixture.lookupJSON([file]))

        // when
        await fixture.send(.reviseSubmitted(number: 5, title: "새 명세.pdf", summary: ""))
        await fixture.respond(json: TerminalFixture.json(updated))

        // then
        #expect(fixture.state.selection == [ItemRef(number: 5, title: "새 명세.pdf", kind: .file, source: "pdf")])
    }
}
