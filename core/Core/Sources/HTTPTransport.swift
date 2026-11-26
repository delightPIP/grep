/// carti-RIBs-Swift Samples/TodoModular의 HTTPTransport와 같은 모양이다.
/// 플랫폼이 구현한다(웹: fetch, iOS: URLSession). 서버 주소는 플랫폼이 붙인다(ADR-0011 결정 3).
public struct HTTPRequest: Equatable, Sendable {
    public enum Method: String, Equatable, Sendable {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    public let method: Method
    /// 서버 주소를 뺀 경로(`/me`).
    public let path: String
    public let headers: [String: String]
    /// UTF-8 JSON 텍스트.
    public let body: String?

    public init(method: Method, path: String, headers: [String: String] = [:], body: String? = nil) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
    }
}

public struct HTTPResponse: Equatable, Sendable {
    public let status: Int
    public let body: [UInt8]

    public init(status: Int, body: [UInt8]) {
        self.status = status
        self.body = body
    }
}

public enum HTTPTransportError: Error, Equatable, Sendable {
    case cancelled
    /// 응답을 받지 못했다. COM-010 `연결 끊김`.
    case unreachable
    /// 정한 시간 안에 응답이 없다. COM-010 `응답 없음`(10초, 08 6절 14번).
    case timedOut
}

/// 상태 코드가 오류여도 응답을 받았으면 던지지 않는다. 해석은 코어가 한다.
@MainActor
public protocol HTTPTransport: AnyObject {
    func send(_ request: HTTPRequest) async throws(HTTPTransportError) -> HTTPResponse
}
