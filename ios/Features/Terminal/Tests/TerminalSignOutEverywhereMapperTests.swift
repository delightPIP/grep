import FeatureTerminalAdapter
import FeatureTerminalInterface
import FeatureTerminalUI
import GrepCore
import Testing

/// `로그아웃 모든기기` 확인 줄과 확인 시트(#112, ACC-002 규칙 4·5, COM-007).
struct TerminalSignOutEverywhereMapperTests {
    @Test func 연결수를모를때_매핑하면_연결칸없이확인줄과로그아웃시트를띄우는지() {
        // given
        let state = TerminalViewState(lines: [
            .prompt("로그아웃 모든기기"),
            .signOutEverywhereConfirm(connectionCount: nil),
        ])

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.blocks.first?.lines.last
            == .status(tone: .warn, boldPrefix: "로그아웃?", body: " 모든 기기 (다른 기기는 최대 1시간 뒤)"))
        #expect(presentation.pendingConfirm == TerminalConfirmPrompt(
            question: "로그아웃? 모든 기기 (다른 기기는 최대 1시간 뒤)",
            answer: "로그아웃"
        ))
    }

    @Test func 끊길AI도구연결이있을때_매핑하면_연결수를함께묻는지() {
        // given
        let state = TerminalViewState(lines: [.signOutEverywhereConfirm(connectionCount: 2)])

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.pendingConfirm?.question == "로그아웃? 모든 기기 · AI 도구 연결 2개 (다른 기기는 최대 1시간 뒤)")
    }

    @Test func 연결이0개일때_매핑하면_연결칸을빼는지() {
        // given
        let state = TerminalViewState(lines: [.signOutEverywhereConfirm(connectionCount: 0)])

        // when
        let line = TerminalStateMapper.map(state).blocks.first?.lines.first

        // then
        #expect(line == .status(tone: .warn, boldPrefix: "로그아웃?", body: " 모든 기기 (다른 기기는 최대 1시간 뒤)"))
    }

    @Test func 확인뒤취소됐을때_매핑하면_시트를닫는지() {
        // given
        let state = TerminalViewState(lines: [
            .signOutEverywhereConfirm(connectionCount: nil),
            .cancelled,
        ])

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.pendingConfirm == nil)
    }
}
