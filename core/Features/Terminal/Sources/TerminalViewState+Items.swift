import FeatureTerminalInterface
import GrepCore

extension TerminalViewState {
    /// 화면 줄에 있는 처리 중(`received`·`processing`) 자료의 번호. 처음 나온 순서, 겹치지 않게(ARC-005 규칙 10).
    func processingNumbers(excluding gone: Set<Int>) -> [Int] {
        var seen = gone
        return lines.flatMap(\.items)
            .filter { $0.status == .received || $0.status == .processing }
            .map(\.number)
            .filter { seen.insert($0).inserted }
    }

    /// 자료를 든 모든 줄에서 번호가 같은 자료를 새 값으로 바꾼다. 줄을 더 찍지 않는다(ARC-005 규칙 10).
    func replacingItems(with fresh: [ItemSummary]) -> TerminalViewState {
        let byNumber = Dictionary(fresh.map { ($0.number, $0) }) { first, _ in first }
        var next = self
        next.lines = lines.map { $0.mappingItems { byNumber[$0.number]?.keepingMatch(of: $0) ?? $0 } }
        return next
    }

    /// `index`의 목록 줄에 다음 쪽을 이어 붙인다. 그 줄이 목록이 아니면 그대로 둔다.
    func extendingRecentList(at index: Int, with added: [ItemSummary], hasMore: Bool) -> TerminalViewState {
        guard lines.indices.contains(index), case .recentList(let items, _) = lines[index] else { return self }
        var next = self
        next.lines[index] = .recentList(items: items + added, hasMore: hasMore)
        return next
    }

    /// `index`의 목록 줄에서 `→ 더 보기`를 뺀다.
    func closingRecentList(at index: Int) -> TerminalViewState {
        extendingRecentList(at: index, with: [], hasMore: false)
    }
}

extension TerminalViewState.Line {
    fileprivate var items: [ItemSummary] {
        switch self {
        case .saved(let item), .alreadySaved(let item): [item]
        case .recentList(let items, _), .searchResult(_, _, let items, _): items
        case .noResults(_, let recent): recent
        default: []
        }
    }

    fileprivate func mappingItems(_ transform: (ItemSummary) -> ItemSummary) -> Self {
        switch self {
        case .saved(let item): .saved(transform(item))
        case .alreadySaved(let item): .alreadySaved(transform(item))
        case .recentList(let items, let hasMore): .recentList(items: items.map(transform), hasMore: hasMore)
        case .searchResult(let query, let total, let items, let hasMore):
            .searchResult(query: query, total: total, items: items.map(transform), hasMore: hasMore)
        case .noResults(let query, let recent): .noResults(query: query, recent: recent.map(transform))
        default: self
        }
    }
}

extension ItemSummary {
    /// 번호 조회 응답에는 찾기에서 일치한 곳이 없다. 화면에 있던 값을 이어 쓴다.
    fileprivate func keepingMatch(of shown: ItemSummary) -> ItemSummary {
        ItemSummary(
            number: number, kind: kind, title: title, source: source, status: status,
            blockedReason: blockedReason, listSummary: listSummary, summarySource: summarySource,
            partialNote: partialNote, tags: tags, matchedIn: matchedIn ?? shown.matchedIn, savedAt: savedAt
        )
    }
}
