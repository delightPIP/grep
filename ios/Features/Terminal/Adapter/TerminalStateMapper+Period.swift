import FeatureTerminalInterface
import FeatureTerminalUI
import Foundation
import GrepCore

// 최근·찾기 목록과 0건, 목록 행.
extension TerminalStateMapper {
    private static let listTagLimit = 3

    static func mapPeriodLine(_ line: TerminalViewState.Line, pickedNumbers: Set<Int>) -> [TerminalOutputBlockLine] {
        switch line {
        case .recentList(let items, let hasMore, let total, let period):
            // 시점이 없는 `최근`은 머리 줄 없이 목록만(commands 6절). 시점이 있으면 찾기와 같은 머리 줄.
            return [periodList(items: items, total: total ?? items.count, hasMore: hasMore, period: period, pickedNumbers: pickedNumbers, showsCount: period != nil)]
        case .searchResult(_, let total, let items, let hasMore, let period, _):
            return [periodList(items: items, total: total, hasMore: hasMore, period: period, pickedNumbers: pickedNumbers, showsCount: true)]
        case .noResults(let query, let recent, let period, _):
            var result: [TerminalOutputBlockLine] = []
            if let period {
                // commands 6절 시점을 붙인 결과: `· 0건: "결제" (지난달)` 뒤에 `→ 기간 없이: 찾기 결제`.
                let bare = ([query.words] + query.tags.map { "#\($0)" }).filter { !$0.isEmpty }.joined(separator: " ")
                result.append(.status(tone: .info, boldPrefix: nil, body: #"0건: "\#(bare)" (\#(period.label))"#))
                result.append(.commandHint(prefix: "→ 기간 없이: ", command: "찾기 \(bare)", suffix: ""))
            } else {
                result.append(.status(tone: .info, boldPrefix: nil, body: #"0건: "\#(query.text)""#))
            }
            if !recent.isEmpty {
                result.append(.status(tone: .info, boldPrefix: nil, body: "최근 저장 \(recent.count)건 (검색 결과 아님)"))
                result.append(.list(
                    header: nil,
                    items: recent.map { mapRow($0, isPicked: pickedNumbers.contains($0.number)) },
                    hasMore: false
                ))
            }
            return result
        default:
            return []
        }
    }

    /// 찾기·최근 목록. 시점이 있으면 머리 줄 뒤에 ` · 지난달 (10/1~10/31)`, 여러 주면 주 구분선(웹 `SearchResultLines`).
    private static func periodList(
        items: [ItemSummary],
        total: Int,
        hasMore: Bool,
        period: Period?,
        pickedNumbers: Set<Int>,
        showsCount: Bool
    ) -> TerminalOutputBlockLine {
        var rows = items.map { mapRow($0, isPicked: pickedNumbers.contains($0.number)) }
        var header = showsCount ? TerminalTextFormat.countHeader(total: total, shown: items.count) : nil
        if let period {
            header = [header, PeriodFormat.label(period)].compactMap { $0 }.joined(separator: " · ")
            let dividers = PeriodFormat.dividers(for: items.map(\.savedAt), in: period)
            rows = zip(rows, dividers).map { $0.with(dividerBefore: $1) }
        }
        return .list(header: header, items: rows, hasMore: hasMore)
    }

    /// 자료 목록 한 행. 담기·샘플 묶음도 같은 행을 쓴다.
    static func mapRow(_ item: ItemSummary, isPicked: Bool) -> TerminalItemRow {
        let title = item.kind == .text ? TerminalTextFormat.textTitle(item.title) : item.title
        let savedAt = TerminalTextFormat.savedAt(item.savedAt)
        let metaParts = [item.source, savedAt].compactMap { $0 }.filter { !$0.isEmpty }
        let matchLabel: String? = item.matchedIn == .imageText ? "이미지 속 글자" : nil
        return TerminalItemRow(
            number: item.number,
            title: title,
            meta: metaParts.joined(separator: " · "),
            summary: rowSummary(item),
            summaryIsWarning: item.status == .blocked || item.status == .failed,
            matchLabel: matchLabel,
            tags: Array(item.tags.prefix(listTagLimit)),
            isPicked: isPicked
        )
    }

    static func isProcessing(_ item: ItemSummary) -> Bool {
        item.status == .received || item.status == .processing
    }

    private static func rowSummary(_ item: ItemSummary) -> String? {
        if isProcessing(item) { return "· 요약 생성 중" }
        if item.status == .blocked { return "! 본문 못 가져옴 → 고치기 \(item.number)" }
        if item.status == .failed { return "! 요약 못 만듦  제목·출처만 넘김" }
        guard let summary = item.listSummary else { return nil }
        if let partial = item.partialNote, !partial.isEmpty {
            return "\(summary) (\(partial))"
        }
        return summary
    }
}
