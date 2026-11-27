import FeatureTerminalAdapter
import FeatureTerminalInterface
import FeatureTerminalUI
import GrepCore
import Testing

/// `휴지통`·`휴지통 비우기` 결과 줄과 비우기 확인 시트(#97, ARC-008 규칙 5·6·10, COM-007).
struct TerminalBinMapperTests {
    private static func entry(number: Int, title: String, source: String?, daysLeft: Int) -> TrashEntry {
        TrashEntry(
            item: ItemSummary(
                number: number,
                kind: .file,
                title: title,
                source: source,
                status: .ready,
                tags: [],
                savedAt: "2026-11-20T01:00:00Z"
            ),
            trashedAt: "2026-11-27T01:00:00Z",
            daysLeft: daysLeft
        )
    }

    @Test func 휴지통을쳤을때_매핑하면_건수머리와남은날칸을보이는지() {
        // given
        let state = TerminalViewState(lines: [
            .prompt("휴지통"),
            .binList(
                total: 2,
                items: [
                    Self.entry(number: 29, title: "주간 업무 메모.md", source: "md", daysLeft: 30),
                    Self.entry(number: 21, title: "사무실 비품 주문 목록.txt", source: nil, daysLeft: 3),
                ],
                hasMore: false
            ),
        ])

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.blocks.first?.lines == [
            .prompt(command: "휴지통", failed: false),
            .trashList(
                header: "2건",
                rows: [
                    TerminalTrashRow(number: 29, title: "주간 업무 메모.md", meta: "md · 30일 남음"),
                    TerminalTrashRow(number: 21, title: "사무실 비품 주문 목록.txt", meta: "3일 남음"),
                ],
                hasMore: false
            ),
        ])
    }

    @Test func 휴지통에다음쪽이남았을때_매핑하면_머리에보인건수를적는지() {
        // given
        let state = TerminalViewState(lines: [
            .binList(
                total: 12,
                items: [Self.entry(number: 29, title: "주간 업무 메모.md", source: nil, daysLeft: 30)],
                hasMore: true
            ),
        ])

        // when
        let line = TerminalStateMapper.map(state).blocks.first?.lines.first

        // then
        guard case .trashList(let header, _, let hasMore) = line else {
            Issue.record("Expected trashList line")
            return
        }
        #expect(header == "12건 중 1건")
        #expect(hasMore)
    }

    @Test func 휴지통이비었을때_매핑하면_비어있다고알리는지() {
        // given
        let state = TerminalViewState(lines: [.binList(total: 0, items: [], hasMore: false)])

        // when
        let lines = TerminalStateMapper.map(state).blocks.first?.lines

        // then
        #expect(lines == [.status(tone: .info, boldPrefix: nil, body: "휴지통 비어 있음")])
    }

    @Test func 휴지통비우기를쳤을때_매핑하면_확인줄을남기고비우기시트를띄우는지() {
        // given
        let state = TerminalViewState(lines: [
            .prompt("휴지통 비우기"),
            .binEmptyConfirm(total: 3),
        ])

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.blocks.first?.lines.last
            == .status(tone: .warn, boldPrefix: "비우기?", body: " 3건 (되돌릴 수 없음)"))
        #expect(presentation.pendingConfirm == TerminalConfirmPrompt(
            question: "비우기? 3건 (되돌릴 수 없음)",
            answer: "비우기"
        ))
    }

    @Test func 버리기확인뒤비우기확인이왔을때_매핑하면_나중확인을시트로띄우는지() {
        // given
        let state = TerminalViewState(lines: [
            .prompt("버리기 1-3"),
            .dropConfirm(total: 3),
            .cancelled,
            .prompt("휴지통 비우기"),
            .binEmptyConfirm(total: 5),
        ])

        // when
        let presentation = TerminalStateMapper.map(state)

        // then
        #expect(presentation.pendingConfirm?.answer == "비우기")
    }

    @Test func 휴지통을비웠을때_매핑하면_영구삭제건수를보이는지() {
        // given
        let state = TerminalViewState(lines: [.prompt("비우기"), .binEmptied(count: 3)])

        // when
        let lines = TerminalStateMapper.map(state).blocks.first?.lines

        // then
        #expect(lines?.last == .status(tone: .ok, boldPrefix: "비움", body: "  3건 영구 삭제"))
        #expect(TerminalStateMapper.map(state).pendingConfirm == nil)
    }

    @Test func 빈휴지통을비웠을때_매핑하면_비어있다고만알리는지() {
        // given
        let state = TerminalViewState(lines: [.binEmptied(count: 0)])

        // when
        let lines = TerminalStateMapper.map(state).blocks.first?.lines

        // then
        #expect(lines == [.status(tone: .info, boldPrefix: nil, body: "휴지통 비어 있음")])
    }
}
