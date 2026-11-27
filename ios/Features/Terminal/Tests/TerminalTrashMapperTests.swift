import FeatureTerminalAdapter
import FeatureTerminalInterface
import FeatureTerminalUI
import GrepCore
import Testing

/// `버리기`·`되살리기` 결과 줄과 확인 시트(#94, ARC-008, COM-007, MOB-002 규칙 4).
struct TerminalTrashMapperTests {
    @Test func 한건을버렸을때_매핑하면_휴지통건수와되살릴번호를보이는지() {
        // given
        let state = TerminalViewState(lines: [
            .prompt("버리기 131"),
            .dropped([ItemRef(number: 131, title: "결제 오류 정리")]),
        ])

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.blocks.first?.lines == [
            .prompt(command: "버리기 131", failed: false),
            .status(tone: .ok, boldPrefix: "휴지통 1건", body: " (30일 뒤 삭제, 되살리기 131)"),
        ])
        #expect(presentation.pendingConfirm == nil)
    }

    @Test func 두건을버렸을때_매핑하면_옮긴번호를모두적는지() {
        // given
        let state = TerminalViewState(lines: [
            .dropped([
                ItemRef(number: 131, title: "결제 오류 정리"),
                ItemRef(number: 57, title: "토스 문서"),
            ]),
        ])

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.blocks.first?.lines == [
            .status(tone: .ok, boldPrefix: "휴지통 2건", body: " (30일 뒤 삭제, 되살리기 131 57)"),
        ])
    }

    @Test func 되살렸을때_매핑하면_되살림건수를보이는지() {
        // given
        let state = TerminalViewState(lines: [
            .prompt("되살리기 131 57"),
            .revived([
                ItemRef(number: 131, title: "결제 오류 정리"),
                ItemRef(number: 57, title: "토스 문서"),
            ]),
        ])

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.blocks.first?.lines == [
            .prompt(command: "되살리기 131 57", failed: false),
            .status(tone: .ok, boldPrefix: "되살림 2건", body: ""),
        ])
    }

    @Test func 두건이상버리려할때_매핑하면_확인줄을남기고확인시트를띄우는지() {
        // given
        let state = TerminalViewState(lines: [
            .prompt("버리기 1-3"),
            .dropConfirm(total: 3),
        ])

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.blocks.first?.lines == [
            .prompt(command: "버리기 1-3", failed: false),
            .status(tone: .warn, boldPrefix: "버리기?", body: " 3건 (휴지통으로)"),
        ])
        #expect(presentation.pendingConfirm == TerminalConfirmPrompt(
            question: "버리기? 3건 (휴지통으로)",
            answer: "버리기"
        ))
    }

    @Test func 버리기확인뒤취소됐을때_매핑하면_확인시트를닫는지() {
        // given
        let state = TerminalViewState(lines: [
            .prompt("버리기 1-3"),
            .dropConfirm(total: 3),
            .cancelled,
        ])

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.pendingConfirm == nil)
    }

    @Test func 버리기확인에답했을때_매핑하면_확인시트를닫는지() {
        // given
        let state = TerminalViewState(lines: [
            .prompt("버리기 1-3"),
            .dropConfirm(total: 3),
            .prompt("버리기"),
        ])

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.pendingConfirm == nil)
    }

    @Test func 확인뒤다른줄만붙었을때_매핑하면_확인시트를유지하는지() {
        // given
        let state = TerminalViewState(lines: [
            .prompt("버리기 1-3"),
            .dropConfirm(total: 3),
            .reconnected,
        ])

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.pendingConfirm?.answer == "버리기")
    }
}
