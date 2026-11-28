import FeatureTerminalInterface
import FeatureTerminalUI
import Foundation
import GrepCore

// 담기: 저장됨, 이미 저장됨, 휴지통에 있음, 저장 안 됨.
extension TerminalStateMapper {
    static func mapKeepLine(_ line: TerminalViewState.Line, pickedNumbers: Set<Int>) -> [TerminalOutputBlockLine] {
        switch line {
        case .saved(let item):
            let headline = item.kind == .text
                ? "저장됨 (글)  \(TerminalTextFormat.textTitle(item.title))"
                : "저장됨  \(withSource(item))"
            var result: [TerminalOutputBlockLine] = [.status(tone: .ok, boldPrefix: nil, body: headline)]
            if isProcessing(item) {
                result.append(.plain(text: "· 요약 생성 중", dim: true))
            }
            return result
        case .alreadySaved(let item):
            return [
                .status(tone: .warn, boldPrefix: nil, body: "이미 저장됨 → \(item.number)번 (새로 만들지 않음)"),
                .itemRow(mapRow(item, isPicked: pickedNumbers.contains(item.number))),
                .commandHint(prefix: "→ ", command: "고르기 \(item.number)", suffix: ""),
            ]
        case .inTrash(let number):
            return [.status(tone: .warn, boldPrefix: nil, body: "휴지통에 있음 → \(number)번. 되살리기 \(number)")]
        case .saveFailed(let reason, let recovery):
            let headline = "저장 안 됨: \(failureText(reason))\(recoverySuffix(reason, recovery))"
            var result: [TerminalOutputBlockLine] = [.status(tone: .error, boldPrefix: nil, body: headline)]
            if case .retry(let command) = recovery {
                result.append(.commandHint(prefix: "→ 다시: ", command: command, suffix: ""))
            }
            return result
        default:
            return []
        }
    }

    private static func withSource(_ item: ItemSummary) -> String {
        if let source = item.source, !source.isEmpty {
            return "\(item.title) (\(source))"
        }
        return item.title
    }

    private static func failureText(_ reason: SaveFailure) -> String {
        switch reason {
        case .disconnected: "연결 끊김"
        case .timedOut: "응답 없음"
        case .serverError: "서버 오류"
        case .unsupportedFormat(let ext): "받지 않는 형식 (.\(ext))"
        case .tooLarge(let fileName, let bytes): "20MB 넘음 (\(fileName) · \(TerminalTextFormat.megabytes(bytes)))"
        }
    }

    private static func recoverySuffix(_ reason: SaveFailure, _ recovery: SaveRecovery) -> String {
        switch recovery {
        case .inputKept:
            return "  입력은 남겨 둠"
        case .file(let name):
            switch reason {
            case .disconnected, .timedOut, .serverError:
                return " (\(name))"
            case .unsupportedFormat, .tooLarge:
                return ""
            }
        case .retry:
            return ""
        }
    }
}
