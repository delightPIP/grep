import FeatureTerminalInterface
import FeatureTerminalUI
import Foundation
import GrepCore

// 고르기: 선택, 없는·잘못된 번호, 선택 빼기·비우기.
extension TerminalStateMapper {
    static func mapPickLine(_ line: TerminalViewState.Line) -> [TerminalOutputBlockLine] {
        switch line {
        case .picked(let items):
            let titleList = items.map(\.title).joined(separator: " · ")
            return [
                .status(tone: .ok, boldPrefix: nil, body: "선택 \(items.count)건  \(titleList)"),
                .commandHint(prefix: "→ ", command: "넘기기", suffix: " 또는 묶음 <이름>"),
            ]
        case .notFound(let numbers):
            let list = numbers.map(String.init).joined(separator: ", ")
            return [.status(tone: .error, boldPrefix: nil, body: "없는 번호: \(list)")]
        case .invalidNumber(let input):
            return [.status(tone: .error, boldPrefix: nil, body: "잘못된 번호: \(input)  예: 고르기 131 140")]
        case .unpicked(_, let remaining):
            // commands 6절 선택 빼기. 남은 수는 그 시점 값을 줄이 들고 온다(지난 줄이 나중 선택에 따라 바뀌지 않게).
            return [.status(tone: .ok, boldPrefix: "뺌", body: "  선택 \(remaining)건 남음")]
        case .pickCleared:
            // commands 6절 "모두 풀면 `✓ 선택 비움`". 건수는 문구에 없다.
            return [.status(tone: .ok, boldPrefix: "선택 비움", body: "")]
        default:
            return []
        }
    }
}
