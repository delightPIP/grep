import FeatureTerminalInterface
import FeatureTerminalUI
import Foundation
import GrepCore

// 샘플 저장(ARC-010).
extension TerminalStateMapper {
    static func mapSamplesLine(_ line: TerminalViewState.Line, pickedNumbers: Set<Int>) -> [TerminalOutputBlockLine] {
        guard case .samplesSaved(let firstNumber, let lastNumber, let items) = line else { return [] }
        // ARC-010 규칙 4·6 사용자 문구. 받은 번호 범위와 치우는 법, 이어서 `최근`과 같은 목록.
        let range = "\(firstNumber)-\(lastNumber)"
        var result: [TerminalOutputBlockLine] = [
            .status(tone: .ok, boldPrefix: "샘플 \(lastNumber - firstNumber + 1)건 저장 (\(range)번)", body: ""),
            .commandHint(prefix: "· 치우려면: ", command: "버리기 \(range)", suffix: ""),
        ]
        if !items.isEmpty {
            result.append(.list(
                header: nil,
                items: items.map { mapRow($0, isPicked: pickedNumbers.contains($0.number)) },
                hasMore: false
            ))
        }
        return result
    }
}
