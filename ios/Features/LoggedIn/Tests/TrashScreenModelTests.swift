import FeatureLoggedInAdapter
import FeatureLoggedInUI
import Foundation
import GrepCore
import Testing

/// 설정 › 휴지통 화면(#97, ARC-008 규칙 5·6·10·11).
@MainActor
struct TrashScreenModelTests {
    @Test func 휴지통을열었을때_불러오면_건수와남은날을보이는지() async {
        // given
        let client = StubTrashClient(pages: [
            .page(
                total: 2,
                entries: [
                    entry(number: 29, title: "주간 업무 메모.md", source: "md", daysLeft: 30),
                    entry(number: 31, title: "겨울 카피 아이디어", source: nil, daysLeft: 2, kind: .text),
                ],
                nextCursor: nil
            ),
        ])
        let model = TrashScreenModel(client: client)

        // when
        await model.refresh()

        // then
        #expect(model.presentation.countText == "2건")
        #expect(model.presentation.rows == [
            TrashRowPresentation(number: 29, title: "주간 업무 메모.md", meta: "md · 30일 남음"),
            TrashRowPresentation(number: 31, title: "겨울 카피 아이디어", meta: "2일 남음"),
        ])
    }

    @Test func 다음쪽이남았을때_더보기를누르면_중복없이이어붙이는지() async {
        // given
        let client = StubTrashClient(pages: [
            .page(total: 3, entries: [entry(number: 3), entry(number: 2)], nextCursor: "c2"),
            .page(total: 3, entries: [entry(number: 2), entry(number: 1)], nextCursor: nil),
        ])
        let model = TrashScreenModel(client: client, pageLimit: 2)

        // when
        await model.refresh()
        let headerBeforeMore = model.presentation.countText
        await model.loadMore()

        // then
        #expect(headerBeforeMore == "3건 중 2건")
        #expect(client.requestedCursors == [nil, "c2"])
        #expect(model.presentation.rows.map(\.number) == [3, 2, 1])
        #expect(!model.presentation.hasMore)
    }

    @Test func 되살리기를누르면_그행을빼고되살림건수를알리는지() async {
        // given
        let client = StubTrashClient(
            pages: [.page(total: 2, entries: [entry(number: 29), entry(number: 21)], nextCursor: nil)],
            restoreOutcome: .restored(numbers: [29])
        )
        let model = TrashScreenModel(client: client)
        await model.refresh()

        // when
        await model.revive(number: 29)

        // then
        #expect(client.restoredNumbers == [[29]])
        #expect(model.presentation.rows.map(\.number) == [21])
        #expect(model.presentation.countText == "1건")
        #expect(model.presentation.notice == TrashNotice(tone: .ok, boldPrefix: "되살림 1건"))
    }

    @Test func 이미영구삭제된번호를되살리면_없는번호를알리고행을빼는지() async {
        // given
        let client = StubTrashClient(
            pages: [.page(total: 1, entries: [entry(number: 21)], nextCursor: nil)],
            restoreOutcome: .notFound(numbers: [21])
        )
        let model = TrashScreenModel(client: client)
        await model.refresh()

        // when
        await model.revive(number: 21)

        // then
        #expect(model.presentation.notice == TrashNotice(tone: .error, boldPrefix: "없는 번호:", body: " 21"))
        #expect(model.presentation.rows.isEmpty)
        #expect(model.presentation.isEmpty)
    }

    @Test func 되살리기가연결끊김으로실패하면_행을남기고실패이유를알리는지() async {
        // given
        let client = StubTrashClient(
            pages: [.page(total: 1, entries: [entry(number: 21)], nextCursor: nil)],
            restoreOutcome: .failed(.disconnected)
        )
        let model = TrashScreenModel(client: client)
        await model.refresh()

        // when
        await model.revive(number: 21)

        // then
        #expect(model.presentation.rows.map(\.number) == [21])
        #expect(model.presentation.notice == TrashNotice(tone: .error, boldPrefix: "되살리기 안 됨:", body: " 연결 끊김"))
        #expect(!model.presentation.isBusy)
    }

    @Test func 비우기를확인하면_목록을비우고영구삭제건수를알리는지() async {
        // given
        let client = StubTrashClient(
            pages: [.page(total: 3, entries: [entry(number: 3), entry(number: 2), entry(number: 1)], nextCursor: nil)],
            emptyOutcome: .emptied(count: 3)
        )
        let model = TrashScreenModel(client: client)
        await model.refresh()
        let confirmTitle = model.presentation.emptyConfirmTitle

        // when
        await model.empty()

        // then
        #expect(confirmTitle == "비우기? 3건 (되돌릴 수 없음)")
        #expect(client.emptyCallCount == 1)
        #expect(model.presentation.rows.isEmpty)
        #expect(model.presentation.isEmpty)
        #expect(model.presentation.notice == TrashNotice(tone: .ok, boldPrefix: "비움", body: "  3건 영구 삭제"))
    }

    @Test func 불러오기에서로그인이만료되면_만료를알리는지() async {
        // given
        let client = StubTrashClient(pages: [.sessionExpired])
        var expired = false
        let model = TrashScreenModel(client: client, onSessionExpired: { expired = true })

        // when
        await model.refresh()

        // then
        #expect(expired)
    }

    @Test func 불러오기가실패하면_실패이유를알리는지() async {
        // given
        let client = StubTrashClient(pages: [.failed(.timedOut)])
        let model = TrashScreenModel(client: client)

        // when
        await model.refresh()

        // then
        #expect(model.presentation.notice == TrashNotice(tone: .error, boldPrefix: "휴지통 안 됨:", body: " 응답 없음"))
        #expect(model.presentation.total == nil)
    }
}

private func entry(
    number: Int,
    title: String = "자료",
    source: String? = nil,
    daysLeft: Int = 30,
    kind: ItemKind = .file
) -> TrashListEntry {
    TrashListEntry(
        item: ItemSummary(
            number: number,
            kind: kind,
            title: title,
            source: source,
            status: .ready,
            tags: [],
            savedAt: "2026-11-20T01:00:00Z"
        ),
        daysLeft: daysLeft
    )
}

@MainActor
private final class StubTrashClient: TrashClient {
    private var pages: [TrashPageOutcome]
    private let restoreOutcome: TrashRestoreOutcome
    private let emptyOutcome: TrashEmptyOutcome
    private(set) var requestedCursors: [String?] = []
    private(set) var restoredNumbers: [[Int]] = []
    private(set) var emptyCallCount = 0

    init(
        pages: [TrashPageOutcome],
        restoreOutcome: TrashRestoreOutcome = .restored(numbers: []),
        emptyOutcome: TrashEmptyOutcome = .emptied(count: 0)
    ) {
        self.pages = pages
        self.restoreOutcome = restoreOutcome
        self.emptyOutcome = emptyOutcome
    }

    func loadPage(limit: Int, cursor: String?) async -> TrashPageOutcome {
        requestedCursors.append(cursor)
        return pages.isEmpty ? .cancelled : pages.removeFirst()
    }

    func restore(numbers: [Int]) async -> TrashRestoreOutcome {
        restoredNumbers.append(numbers)
        return restoreOutcome
    }

    func empty() async -> TrashEmptyOutcome {
        emptyCallCount += 1
        return emptyOutcome
    }
}
