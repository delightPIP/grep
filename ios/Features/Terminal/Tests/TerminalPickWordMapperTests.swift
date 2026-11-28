import FeatureTerminalAdapter
import FeatureTerminalInterface
import FeatureTerminalUI
import GrepCore
import Testing

/// 선택 칩의 `<종류 낱말> <번호>`(ARC-003 규칙 14, #179, 웹 `pick-word.ts`).
struct TerminalPickWordMapperTests {
    @Test func 종류가다른자료를골랐을때_매핑하면_칩마다종류낱말과번호를붙이는지() {
        // given
        let state = TerminalViewState(selection: [
            ItemRef(number: 25, title: "겨울 음료 트렌드 보고서.pdf", kind: .file, source: "pdf"),
            ItemRef(number: 12, title: "캠페인 카피 초안", kind: .text),
            ItemRef(number: 3, title: "카페 텀블러 할인", kind: .link, source: "example.com"),
        ])

        // when
        let tags = TerminalStateMapper.map(state).selection.map(\.tag)

        // then
        #expect(tags == ["PDF 25", "글 12", "example.com 3"])
    }

    @Test func 파일형식이없을때_매핑하면_제목의확장자를대문자로쓰는지() {
        // given
        let state = TerminalViewState(selection: [
            ItemRef(number: 28, title: "파란컵 캡처.png", kind: .file),
        ])

        // when
        let tags = TerminalStateMapper.map(state).selection.map(\.tag)

        // then
        #expect(tags == ["PNG 28"])
    }

    @Test func 낱말을정할수없을때_매핑하면_링크나파일로쓰는지() {
        // given
        let state = TerminalViewState(selection: [
            ItemRef(number: 9, title: "호스트 없는 링크", kind: .link),
            ItemRef(number: 7, title: "확장자없음", kind: .file),
        ])

        // when
        let tags = TerminalStateMapper.map(state).selection.map(\.tag)

        // then
        #expect(tags == ["링크 9", "파일 7"])
    }
}
