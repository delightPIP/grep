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

    /// `index`의 목록 줄(`최근` 목록·찾기 결과)에 다음 쪽을 이어 붙인다. 그 줄이 목록이 아니면 그대로 둔다.
    func extendingList(at index: Int, with added: [ItemSummary], hasMore: Bool) -> TerminalViewState {
        guard lines.indices.contains(index) else { return self }
        var next = self
        switch lines[index] {
        case .recentList(let items, _, let total, let period):
            next.lines[index] = .recentList(items: items + added, hasMore: hasMore, total: total, period: period)
        case .searchResult(let query, let total, let items, _, let period):
            next.lines[index] = .searchResult(
                query: query, total: total, items: items + added, hasMore: hasMore, period: period
            )
        default:
            return self
        }
        return next
    }

    /// `index`의 목록 줄에서 `→ 더 보기`를 뺀다.
    func closingList(at index: Int) -> TerminalViewState {
        extendingList(at: index, with: [], hasMore: false)
    }
}

extension TerminalViewState.Line {
    fileprivate var items: [ItemSummary] {
        switch self {
        case .saved(let item), .alreadySaved(let item), .revised(let item), .tagsRemoved(let item, _): [item]
        case .recentList(let items, _, _, _), .searchResult(_, _, let items, _, _), .samplesSaved(_, _, let items): items
        case .noResults(_, let recent, _): recent
        default: []
        }
    }

    fileprivate func mappingItems(_ transform: (ItemSummary) -> ItemSummary) -> Self {
        switch self {
        case .saved(let item): .saved(transform(item))
        case .alreadySaved(let item): .alreadySaved(transform(item))
        case .recentList(let items, let hasMore, let total, let period):
            .recentList(items: items.map(transform), hasMore: hasMore, total: total, period: period)
        case .searchResult(let query, let total, let items, let hasMore, let period):
            .searchResult(query: query, total: total, items: items.map(transform), hasMore: hasMore, period: period)
        case .noResults(let query, let recent, let period): .noResults(query: query, recent: recent.map(transform), period: period)
        case .revised(let item): .revised(transform(item))
        case .tagsRemoved(let item, let tags): .tagsRemoved(item: transform(item), tags: tags)
        case .samplesSaved(let first, let last, let items):
            .samplesSaved(firstNumber: first, lastNumber: last, items: items.map(transform))
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
