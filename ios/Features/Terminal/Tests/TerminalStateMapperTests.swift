import FeatureTerminalAdapter
import FeatureTerminalInterface
import FeatureTerminalUI
import GrepCore
import Testing

struct TerminalStateMapperTests {
    @Test func 마지막프롬프트가있을때_매핑하면_명령첫단어를창제목으로쓰는지() {
        // given
        let state = TerminalViewState(
            itemCount: 34,
            lines: [
                .prompt("최근"),
                .prompt("찾기 결제 #sdk"),
            ]
        )

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.title == "찾기")
        #expect(presentation.statusText == "자료 34 · 선택 0")
    }

    @Test func 처리중과오프라인상태일때_매핑하면_상태줄에모두표시하는지() {
        // given
        let state = TerminalViewState(
            itemCount: 12,
            selection: [ItemRef(number: 1, title: "문서")],
            processingCount: 2,
            isOffline: true
        )

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.statusText == "자료 12 · 선택 1 · 요약 생성 중 2 · 연결 끊김")
        #expect(presentation.isOffline)
    }

    @Test func 처리중인링크저장결과일때_매핑하면_저장됨과요약생성중줄을만드는지() {
        // given
        let item = ItemSummary(
            number: 5,
            kind: .link,
            title: "결제 가이드",
            source: "tosspayments",
            status: .processing,
            tags: [],
            savedAt: "2026-11-26T05:03:00Z"
        )
        let state = TerminalViewState(lines: [.saved(item)])

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.blocks.first?.lines == [
            .status(tone: .ok, boldPrefix: nil, body: "저장됨  결제 가이드 (tosspayments)"),
            .plain(text: "· 요약 생성 중", dim: true),
        ])
    }

    @Test func 찾기결과에다음쪽이남았을때_매핑하면_전체중표시건수머리줄과이미지속글자꼬리표를붙이는지() {
        // given
        let item = ItemSummary(
            number: 118,
            kind: .file,
            title: "결제 실패.png",
            source: "이미지",
            status: .ready,
            listSummary: "토스트 비교",
            tags: ["결제", "에러", "ui", "초과태그"],
            matchedIn: .imageText,
            savedAt: "2026-11-26T05:03:00Z"
        )
        let state = TerminalViewState(
            lines: [
                .searchResult(
                    query: SearchQuery(text: "결제", words: "결제", tags: []),
                    total: 23,
                    items: [item],
                    hasMore: true
                ),
            ]
        )

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        guard case .list(let header, let rows, let hasMore) = presentation.blocks.first?.lines.first else {
            Issue.record("Expected list line")
            return
        }
        #expect(header == "23건 중 1건")
        #expect(hasMore)
        #expect(rows.first?.meta == "이미지 · 2026-11-26 14:03")
        #expect(rows.first?.matchLabel == "이미지 속 글자")
        #expect(rows.first?.tags == ["결제", "에러", "ui"])
    }

    @Test func 검색결과가0건이고최근자료가있을때_매핑하면_0건문구와검색결과아님머리줄을붙이는지() {
        // given
        let recent = ItemSummary(
            number: 1,
            kind: .text,
            title: "아주 긴 메모 첫 줄은 스물네 글자까지만 잘라서 제목으로 쓴다",
            source: nil,
            status: .ready,
            tags: [],
            savedAt: "2026-11-26T05:03:00Z"
        )
        let state = TerminalViewState(
            lines: [
                .noResults(query: SearchQuery(text: "없는말", words: "없는말", tags: []), recent: [recent]),
            ]
        )

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        let lines = presentation.blocks.first?.lines ?? []
        #expect(lines.count == 3)
        #expect(lines[0] == .status(tone: .info, boldPrefix: nil, body: #"0건: "없는말""#))
        #expect(lines[1] == .status(tone: .info, boldPrefix: nil, body: "최근 저장 1건 (검색 결과 아님)"))
    }
}
