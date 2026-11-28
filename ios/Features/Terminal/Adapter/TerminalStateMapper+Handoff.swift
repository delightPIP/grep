import FeatureTerminalInterface
import FeatureTerminalUI
import Foundation
import GrepCore

// 넘기기: 복사됨, 복사 안 됨, 5건 초과 확인.
extension TerminalStateMapper {
    private static let handoffFirstLimit = 10

    static func mapHandoffLine(_ line: TerminalViewState.Line) -> [TerminalOutputBlockLine] {
        switch line {
        case .handedOff(let result):
            return [.handedOff(TerminalHandoffPresentation(
                items: result.items.map { TerminalItemRef(number: $0.number, title: $0.title) },
                charCountText: TerminalTextFormat.charCount(result.charCount),
                missingSummaryCount: result.missingSummaryCount,
                text: result.text
            ))]
        case .handoffFailed(let reason, let preview):
            return [.handoffFailed(
                reasonLabel: TerminalTextFormat.commandFailureLabel(reason),
                preview: preview,
                isClipboardDenied: reason == .clipboardDenied
            )]
        case .handoffConfirm(let total):
            var choices: [TerminalChoiceItem] = []
            if total > handoffFirstLimit {
                choices.append(TerminalChoiceItem(command: "앞\(handoffFirstLimit)", label: "앞 \(handoffFirstLimit)건만"))
            }
            choices.append(TerminalChoiceItem(command: "전부", label: "\(total)건 전부"))
            choices.append(TerminalChoiceItem(command: "취소", label: "그 외 입력"))
            return [.handoffConfirm(total: total, choices: choices)]
        default:
            return []
        }
    }
}
