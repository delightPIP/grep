import Foundation

// 순수 뷰 모델(ADR-0015). `FeatureTerminalUI`는 SwiftUI와 Foundation에만 의존하고 `GrepCore`·`RIBs`를 모른다.

public enum TerminalLineTone: Equatable, Sendable {
    case ok
    case info
    case warn
    case error
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

    public init(
        number: Int,
        title: String,
        meta: String,
        summary: String?,
        summaryIsWarning: Bool,
        matchLabel: String?,
        tags: [String],
        isPicked: Bool = false
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
    }
}

public enum TerminalOutputBlockLine: Equatable, Sendable {
    case prompt(command: String, failed: Bool)
    case status(tone: TerminalLineTone, boldPrefix: String?, body: String)
    case plain(text: String, dim: Bool)
    case itemRow(TerminalItemRow)
    case list(header: String?, items: [TerminalItemRow], hasMore: Bool)
    case welcome
}

public struct TerminalOutputBlock: Equatable, Sendable, Identifiable {
    public let id: Int
    public let lines: [TerminalOutputBlockLine]

    public init(id: Int, lines: [TerminalOutputBlockLine]) {
        self.id = id
        self.lines = lines
    }
}

public struct TerminalPresentation: Equatable, Sendable {
    public let title: String
    public let statusText: String
    public let blocks: [TerminalOutputBlock]
    public let input: String
    public let isOffline: Bool

    public init(
        title: String = "처음",
        statusText: String = "자료 0 · 선택 0",
        blocks: [TerminalOutputBlock] = [],
        input: String = "",
        isOffline: Bool = false
    ) {
        self.title = title
        self.statusText = statusText
        self.blocks = blocks
        self.input = input
        self.isOffline = isOffline
    }
}
