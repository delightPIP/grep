
import GrepCore

/// AI 도구 연결 API(api/openapi.yaml `listConnections`·`endConnection`). 응답 해석까지만 한다.
public enum ConnectionsAPI {
    public enum Outcome<Value: Equatable>: Equatable {
        case success(Value)
        /// 404. 그 번호의 연결이 없다.
        case notFound
        case sessionExpired
        case failed(CommandFailure)
        case cancelled
    }

    public struct List: Equatable, Decodable {
        public let mcpUrl: String
        public let connections: [ConnectionEntry]
    }

    public struct Ended: Equatable {
        public let client: String
        /// 이미 끊긴 연결이었다(ACC-002 규칙 9).
        public let already: Bool
    }

    private static let path = "/connections"
    private static let alreadyEnded = "alreadyEnded"
    private static let notFoundStatus = 404
    private static let successStatuses = 200..<300

    private struct EndBody: Decodable {
        public let result: String
        public let client: String
    }

    @MainActor
    public static func list(transport: any HTTPTransport, accessToken: String) async -> Outcome<List> {
        await send(.get, path, transport: transport, accessToken: accessToken) {
            ItemsAPI.decode(List.self, from: $0)
        }
    }

    @MainActor
    public static func end(number: Int, transport: any HTTPTransport, accessToken: String) async -> Outcome<Ended> {
        await send(.delete, "\(path)/\(number)", transport: transport, accessToken: accessToken) { body in
            ItemsAPI.decode(EndBody.self, from: body).map { Ended(client: $0.client, already: $0.result == alreadyEnded) }
        }
    }

    @MainActor
    private static func send<Value>(
        _ method: HTTPRequest.Method,
        _ path: String,
        transport: any HTTPTransport,
        accessToken: String,
        decode: ([UInt8]) -> Value?
    ) async -> Outcome<Value> {
        let request = HTTPRequest(method: method, path: path, headers: ["Authorization": "Bearer \(accessToken)"])
        let response: HTTPResponse
        do {
            response = try await transport.send(request)
        } catch {
            switch error {
            case .cancelled: return .cancelled
            case .unreachable: return .failed(.disconnected)
            case .timedOut: return .failed(.timedOut)
            }
        }
        if ItemsAPI.isSessionExpired(response) { return .sessionExpired }
        if response.status == notFoundStatus { return .notFound }
        guard successStatuses.contains(response.status), let value = decode(response.body) else {
            return .failed(.serverError)
        }
        return .success(value)
    }
}
