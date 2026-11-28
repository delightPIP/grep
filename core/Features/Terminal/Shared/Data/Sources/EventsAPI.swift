
import GrepCore
import TerminalDomain
import GrepData

/// 측정 이벤트 보고 API(api/openapi.yaml `recordEvent`).
/// 클립보드 복사에 성공한 뒤에만 보내며 결과를 기다리지 않고, 실패해도 화면은 그대로 둔다(08 6절 개발 답 9).
public enum EventsAPI {
    public enum Method: String, Encodable {
        case pick
        case pipe
    }

    private static let path = "/events"

    private struct Body: Encodable {
        public let name = "handoff_copied"
        public let numbers: [Int]
        public let method: Method
    }

    @MainActor
    public static func reportHandoffCopied(
        numbers: [Int],
        method: Method,
        transport: any HTTPTransport,
        accessToken: String
    ) async {
        guard !numbers.isEmpty else { return }
        _ = await ItemsAPI.post(
            path,
            body: Body(numbers: numbers, method: method),
            headers: [:],
            transport: transport,
            accessToken: accessToken
        )
    }
}
