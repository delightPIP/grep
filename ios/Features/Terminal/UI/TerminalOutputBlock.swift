import Foundation

// 순수 뷰 모델(ADR-0015). `FeatureTerminalUI`는 SwiftUI와 Foundation에만 의존하고 `GrepCore`·`RIBs`를 모른다.
// 로그 블록과 블록 안 줄 종류.

public enum TerminalLineTone: Equatable, Sendable {
    case ok
    case info
    case warn
    case error
}

public enum TerminalOutputBlockLine: Equatable, Sendable {
    case prompt(command: String, failed: Bool)
    case status(tone: TerminalLineTone, boldPrefix: String?, body: String)
    case plain(text: String, dim: Bool)
    case commandHint(prefix: String, command: String, suffix: String)
    case itemRow(TerminalItemRow)
    case list(header: String?, items: [TerminalItemRow], hasMore: Bool)
    case trashList(header: String, rows: [TerminalTrashRow], hasMore: Bool)
    case handedOff(TerminalHandoffPresentation)
    case handoffFailed(reasonLabel: String, preview: String?, isClipboardDenied: Bool)
    case handoffConfirm(total: Int, choices: [TerminalChoiceItem])
    case guide(rows: [TerminalGuideRow])
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
