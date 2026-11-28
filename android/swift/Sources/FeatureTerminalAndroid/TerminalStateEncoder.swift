import FeatureTerminalInterface
import Foundation
import GrepCore

/// `TerminalViewState`를 Android Kotlin 어댑터가 읽는 JSON 문자열로 직렬화한다.
/// Swift-Java 브리지 시그니처를 단순하게 유지하면서 이후 피처 확장을 쉽게 하기 위한 전송 형식이다.
public enum TerminalStateEncoder {
    public static func encode(_ state: TerminalViewState) -> String {
        let dto = StateDTO(state)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(dto),
              let json = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return json
    }
}
