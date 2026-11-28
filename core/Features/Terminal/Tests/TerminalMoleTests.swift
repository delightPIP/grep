import FeatureTerminalInterface
import GrepCore
import GrepCoreTesting
import Testing

@testable import FeatureTerminal

/// #175 땅굴 두더지 상태. 결과 줄이 찍힐 때 동작을 넣고 `seq`를 하나씩 늘린다.
@MainActor
struct TerminalMoleTests {
    private typealias Fixture = TerminalFixture

    @Test func 터미널을열었을때_아무것도치지않으면_두더지동작이없는지() async {
        // given
        let fixture = Fixture()

        // when
        await fixture.attach()

        // then
        #expect(fixture.state.mole == nil)
    }

    @Test func 찾기를쳤을때_결과가찍히면_찾기동작을넣는지() async {
        // given
        let fixture = Fixture()
        await fixture.attach()
        await fixture.submit("찾기 결제")
        #expect(fixture.state.mole == nil)

        // when
        await fixture.respond(json: Fixture.searchJSON([Fixture.item(25)], total: 1))

        // then
        #expect(fixture.state.mole == Mole(action: .seek, seq: 1))
    }

    @Test func 찾기를쳤을때_0건이면_찾기동작을넣는지() async {
        // given
        let fixture = Fixture()
        await fixture.attach()
        await fixture.submit("찾기 없는말")
        await fixture.respond(json: Fixture.searchJSON([], total: 0))

        // when
        await fixture.respond(json: Fixture.searchJSON([Fixture.item(25)], total: 1))

        // then
        #expect(fixture.state.mole == Mole(action: .seek, seq: 1))
    }

    @Test func 담기를쳤을때_저장되면_저장동작을넣는지() async {
        // given
        let fixture = Fixture()
        await fixture.attach()
        await fixture.submit("담기 https://example.com")

        // when
        await fixture.respond(status: 201, json: #"{"result":"saved","item":\#(Fixture.json(Fixture.item(35)))}"#)

        // then
        #expect(fixture.state.lines.last == .saved(Fixture.item(35)))
        #expect(fixture.state.mole == Mole(action: .save, seq: 1))
    }

    @Test func 자료를골랐을때_넘기기로복사하면_넘기기동작을넣는지() async {
        // given
        let fixture = Fixture()
        await fixture.attach()
        await fixture.pick([25])
        #expect(fixture.state.mole == nil)

        // when
        await fixture.submit("넘기기")
        await fixture.respond(json: Fixture.handoffJSON(Fixture.handoff([25])))

        // then
        #expect(fixture.state.lines.last == .handedOff(Fixture.handoff([25])))
        #expect(fixture.state.mole == Mole(action: .handoff, seq: 1))
    }

    @Test func 없는명령을쳤을때_오류줄이찍히면_틀림동작을넣는지() async {
        // given
        let fixture = Fixture()
        await fixture.attach()

        // when
        await fixture.submit("없는명령어임")

        // then
        #expect(fixture.state.mole == Mole(action: .error, seq: 1))
    }

    @Test func 찾기를쳤을때_서버에닿지못하면_틀림동작을넣는지() async {
        // given
        let fixture = Fixture()
        await fixture.attach()
        await fixture.submit("찾기 결제")

        // when
        await fixture.fail(.unreachable)

        // then
        #expect(fixture.state.mole == Mole(action: .error, seq: 1))
    }

    @Test func 같은오류가이어질때_다시치면_차례를하나씩늘리는지() async {
        // given
        let fixture = Fixture()
        await fixture.attach()
        await fixture.submit("찾기")

        // when
        await fixture.submit("찾기")

        // then
        #expect(fixture.state.mole == Mole(action: .error, seq: 2))
    }

    @Test func 두더지동작이있을때_동작이없는줄이찍히면_그대로두는지() async {
        // given
        let fixture = Fixture()
        await fixture.attach()
        await fixture.submit("찾기")

        // when
        await fixture.submit("도움말")

        // then
        #expect(fixture.state.lines.last == .guide)
        #expect(fixture.state.mole == Mole(action: .error, seq: 1))
    }

    @Test func 기록을되살릴때_터미널을열면_되살린줄로는두더지동작을넣지않는지() async {
        // given
        let fixture = Fixture()
        await fixture.attach()
        await fixture.submit("찾기")
        let record = fixture.fakeHistory.record

        // when
        let reopened = Fixture(history: record)
        await reopened.attach()

        // then
        #expect(reopened.state.lines.last == .missingArgument(.seek))
        #expect(reopened.state.mole == nil)
    }
}
