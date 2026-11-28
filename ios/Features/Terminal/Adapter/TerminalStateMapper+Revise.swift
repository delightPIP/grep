import FeatureTerminalInterface
import FeatureTerminalUI
import Foundation
import GrepCore

// 고치기: 고침, 태그 지움.
extension TerminalStateMapper {
    static func mapReviseLine(_ line: TerminalViewState.Line) -> [TerminalOutputBlockLine] {
        switch line {
        case .revised(let item):
            // 시안 Edit ②. 직접 고친 요약에는 ARC-004 규칙 1 이름표를 붙인다(웹 `RevisedLines`와 같음).
            var result: [TerminalOutputBlockLine] = [
                .status(tone: .ok, boldPrefix: "고침", body: "  \(item.number)번  \(item.title)"),
            ]
            if item.summarySource == .user, let summary = item.listSummary {
                result.append(.plain(text: "요약 (직접 고침)  \(summary)", dim: true))
            }
            return result
        case .tagsRemoved(let item, let tags):
            // 시안 Edit ③(문구 제안). 지운 태그는 다시 붙지 않는다(ARC-002 규칙 2).
            let removed = tags.map { "#\($0)" }.joined(separator: " ")
            return [.status(tone: .ok, boldPrefix: "태그 지움", body: " \(removed) (\(item.number)번)")]
        default:
            return []
        }
    }
}
