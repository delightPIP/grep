import Foundation

// 순수 뷰 모델(ADR-0015). `FeatureTerminalUI`는 SwiftUI와 Foundation에만 의존하고 `GrepCore`·`RIBs`를 모른다.
// 자료 행과 선택 칩 값.

public struct TerminalItemRef: Equatable, Sendable, Identifiable {
    public var id: Int { number }
    public let number: Int
    public let title: String
    /// 선택 칩의 `<종류 낱말> <번호>`(ARC-003 규칙 14). 예: `PDF 25`, `글 12`, `example.com 3`.
    public let tag: String

    public init(number: Int, title: String, tag: String? = nil) {
        self.number = number
        self.title = title
        self.tag = tag ?? "\(number)"
    }
}

public struct TerminalItemRow: Equatable, Sendable, Identifiable {
    public let id: Int
    public let number: Int
    public let title: String
    public let meta: String
    public let summary: String?
    public let summaryIsWarning: Bool
    public let matchLabel: String?
    public let tags: [String]
    public let isPicked: Bool
    /// 시점이 여러 주에 걸치면 주가 바뀌는 행 앞에 `── 10/26~11/1 ──`(commands 6절 시점을 붙인 결과). 아니면 nil.
    public let dividerBefore: String?

    public init(
        number: Int,
        title: String,
        meta: String,
        summary: String?,
        summaryIsWarning: Bool,
        matchLabel: String?,
        tags: [String],
        isPicked: Bool = false,
        dividerBefore: String? = nil
    ) {
        self.id = number
        self.number = number
        self.title = title
        self.meta = meta
        self.summary = summary
        self.summaryIsWarning = summaryIsWarning
        self.matchLabel = matchLabel
        self.tags = tags
        self.isPicked = isPicked
        self.dividerBefore = dividerBefore
    }

    /// 같은 행에 주 구분선만 바꾼 값.
    public func with(dividerBefore: String?) -> TerminalItemRow {
        TerminalItemRow(
            number: number,
            title: title,
            meta: meta,
            summary: summary,
            summaryIsWarning: summaryIsWarning,
            matchLabel: matchLabel,
            tags: tags,
            isPicked: isPicked,
            dividerBefore: dividerBefore
        )
    }
}
