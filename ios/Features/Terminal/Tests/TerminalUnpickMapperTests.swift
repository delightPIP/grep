import FeatureTerminalAdapter
import FeatureTerminalInterface
import FeatureTerminalUI
import GrepCore
import Testing

/// `고르기 빼기`·`고르기 비우기` 결과 줄(#109, commands 3절 고르기·6절 선택 빼기).
struct TerminalUnpickMapperTests {
    @Test func 선택에서뺐을때_매핑하면_남은건수를보이는지() {
        // given
        let state = TerminalViewState(
            lines: [
                .prompt("고르기 빼기 131"),
                .unpicked(items: [ItemRef(number: 131, title: "결제위젯 연동 가이드")], remaining: 1),
            ],
            selection: [ItemRef(number: 118, title: "결제 실패 화면 모음.png")]
        )

        // when
        let lines = TerminalStateMapper.map(state).blocks.first?.lines

        // then
        #expect(lines == [
            .prompt(command: "고르기 빼기 131", failed: false),
            .status(tone: .ok, boldPrefix: "뺌", body: "  선택 1건 남음"),
        ])
    }

    @Test func 지난빼기줄은_나중선택이바뀌어도_그때남은건수를그대로보이는지() {
        // given
        let state = TerminalViewState(
            lines: [.unpicked(items: [ItemRef(number: 131, title: "결제위젯 연동 가이드")], remaining: 2)],
            selection: []
        )

        // when
        let lines = TerminalStateMapper.map(state).blocks.first?.lines

        // then
        #expect(lines == [.status(tone: .ok, boldPrefix: "뺌", body: "  선택 2건 남음")])
    }

    @Test func 선택을모두풀었을때_매핑하면_선택비움을보이는지() {
        // given
        let state = TerminalViewState(lines: [.prompt("고르기 비우기"), .pickCleared(count: 3)])

        // when
        let lines = TerminalStateMapper.map(state).blocks.first?.lines

        // then
        #expect(lines?.last == .status(tone: .ok, boldPrefix: "선택 비움", body: ""))
    }
}
