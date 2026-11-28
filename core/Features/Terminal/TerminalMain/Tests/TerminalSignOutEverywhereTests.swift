import FeatureTerminal
import FeatureTerminalInterface
import TerminalDomain
import GrepCore
import GrepCoreTesting
import Testing

@MainActor
struct TerminalSignOutEverywhereTests {
    @Test func 로그아웃모든기기를칠때_확인줄을찍고로그아웃을다시치면_기록을지우고전역로그아웃을알리는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()

        // when
        await fixture.submit("로그아웃 모든기기")
        let asked = fixture.state.lines.contains(.signOutEverywhereConfirm(connectionCount: nil))
        let countBeforeConfirm = fixture.listener.signOutEverywhereRequestCount
        await fixture.submit("로그아웃")

        // then
        #expect(asked)
        #expect(countBeforeConfirm == 0)
        #expect(fixture.listener.signOutEverywhereRequestCount == 1)
    }

    @Test func 로그아웃모든기기확인중일때_다른명령을치면_취소됨을찍고로그아웃하지않는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach()
        await fixture.submit("로그아웃 모든기기")

        // when
        await fixture.submit("도움말")

        // then
        #expect(fixture.listener.signOutEverywhereRequestCount == 0)
        #expect(fixture.state.lines.contains(.cancelled))
        #expect(fixture.state.lines.contains(.guide))
    }
}
