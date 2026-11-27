import FeatureTerminalInterface
import GrepCore
import GrepCoreTesting
import Testing

@testable import FeatureTerminal

/// #67: 자료 0건 첫 화면(commands 6절, COM-009 규칙 5), `도움말`·`설명 <명령>`(commands 3절).
@MainActor
struct TerminalGuideTests {
    private let fixture = TerminalFixture()

    // MARK: 첫 화면

    @Test func 화면이비어있을때_자료가0건이라고오면_첫화면을그리는지() async {
        // given
        await fixture.attach(itemCount: nil)

        // when
        fixture.handle?.showItemCount(0)

        // then
        #expect(fixture.state.lines == [.welcome])
        #expect(fixture.state.itemCount == 0)
    }

    @Test func 화면이비어있을때_자료가1건이상이라고오면_상태줄과입력줄만두는지() async {
        // given
        await fixture.attach(itemCount: nil)

        // when
        fixture.handle?.showItemCount(1)

        // then
        #expect(fixture.state.lines.isEmpty)
        #expect(fixture.state.itemCount == 1)
    }

    @Test func 이미친명령이있을때_자료가0건이라고오면_첫화면을끼워넣지않는지() async {
        // given
        await fixture.attach(itemCount: nil)
        await fixture.submit("도움말")

        // when
        fixture.handle?.showItemCount(0)

        // then
        #expect(fixture.state.lines == [.prompt("도움말"), .guide])
    }

    @Test func 첫화면이떠있을때_자료수가다시0건으로오면_첫화면을한번만두는지() async {
        // given
        await fixture.attach(itemCount: 0)

        // when
        fixture.handle?.showItemCount(0)

        // then
        #expect(fixture.state.lines == [.welcome])
    }

    // MARK: 도움말과 설명

    @Test(arguments: ["도움말", "guide", " 도움말 "])
    func 자료가0건일때_도움말을치면_요청없이명령목록을그리는지(typed: String) async {
        // given
        await fixture.attach(itemCount: 0)

        // when
        await fixture.submit(typed)

        // then
        #expect(fixture.state.lines == [.welcome, .prompt(typed), .guide])
        #expect(fixture.state.input == "")
        #expect(fixture.transport.requests.isEmpty)
    }

    @Test(arguments: [
        ("설명 찾기", CommandName.seek), ("about seek", .seek), ("설명 handoff", .handoff),
        ("about 도움말", .guide), ("설명 설명", .about), ("설명 로그아웃", .signOut),
    ])
    func 터미널화면일때_설명뒤에명령이름을치면_그명령의설명을그리는지(typed: String, command: CommandName) async {
        // given
        await fixture.attach()

        // when
        await fixture.submit(typed)

        // then
        #expect(fixture.state.lines == [.prompt(typed), .about(command)])
        #expect(fixture.transport.requests.isEmpty)
    }

    @Test(arguments: ["설명", "about "])
    func 터미널화면일때_설명만치면_빠진인자줄을그리는지(typed: String) async {
        // given
        await fixture.attach()

        // when
        await fixture.submit(typed)

        // then
        #expect(fixture.state.lines == [.prompt(typed), .missingArgument(.about)])
    }

    @Test(arguments: [("설명 찻기", "찻기"), ("설명 묶음", "묶음"), ("설명 찾기 결제", "찾기 결제")])
    func 터미널화면일때_모르는명령의설명을찾으면_없는명령으로그리는지(typed: String, name: String) async {
        // given
        await fixture.attach()

        // when
        await fixture.submit(typed)

        // then
        #expect(fixture.state.lines == [.prompt(typed), .unknownCommand(name)])
    }
}
