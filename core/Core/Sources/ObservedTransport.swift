/// 요청마다 서버에 닿았는지를 알려 주는 전송 계층. 연결 끊김 표시(COM-010)가 이 신호 하나만 본다.
/// 응답을 받았으면 상태 코드와 상관없이 닿은 것이고, 네트워크 오류면 닿지 못한 것이다. 응답 없음은 알리지 않는다.
@MainActor
public final class ObservedTransport: HTTPTransport {
    private let base: any HTTPTransport
    public var onReachabilityObserved: ((_ isReachable: Bool) -> Void)?

    public init(base: any HTTPTransport) {
        self.base = base
    }

    public func send(_ request: HTTPRequest) async throws(HTTPTransportError) -> HTTPResponse {
        do {
            let response = try await base.send(request)
            onReachabilityObserved?(true)
            return response
        } catch {
            if error == .unreachable { onReachabilityObserved?(false) }
            throw error
        }
    }
}
