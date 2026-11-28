
import GrepCore
import TerminalDomain
import GrepData

/// 북마크 가져오기 API(api/openapi.yaml `startImport`·`getImport`). 응답 해석까지만 한다.
public enum ImportAPI {
    public struct Status: Equatable, Decodable {
        public let id: String
        public let state: String
        public let total: Int
        public let done: Int
        public let saved: Int
        public let skipped: Int
        public let failed: Int
        public let overLimit: Int
        public let failedUrls: [String]

        public var isFinished: Bool { state == "finished" }
    }

    public enum Outcome: Equatable {
        case status(Status)
        /// 404. 진행을 더 물을 수 없다.
        case notFound
        case sessionExpired
        case failed(CommandFailure)
        case cancelled
    }

    private static let path = "/imports"
    private static let notFoundStatus = 404
    private static let successStatuses = 200..<300

    private struct StartBody: Encodable {
        public let html: String
    }

    @MainActor
    public static func start(html: String, transport: any HTTPTransport, accessToken: String) async -> Outcome {
        let result = await ItemsAPI.post(
            path, body: StartBody(html: html), headers: [:], transport: transport, accessToken: accessToken
        )
        return outcome(of: result)
    }

    @MainActor
    public static func status(id: String, transport: any HTTPTransport, accessToken: String) async -> Outcome {
        let request = HTTPRequest(
            method: .get,
            path: "\(path)/\(BrowseAPI.percentEncoded(id))",
            headers: ["Authorization": "Bearer \(accessToken)"]
        )
        do {
            return outcome(of: .success(try await transport.send(request)))
        } catch {
            return outcome(of: .failure(error))
        }
    }

    private static func outcome(of result: Result<HTTPResponse, HTTPTransportError>) -> Outcome {
        let response: HTTPResponse
        switch result {
        case .success(let received): response = received
        case .failure(.cancelled): return .cancelled
        case .failure(.unreachable): return .failed(.disconnected)
        case .failure(.timedOut): return .failed(.timedOut)
        }
        if ItemsAPI.isSessionExpired(response) { return .sessionExpired }
        if response.status == notFoundStatus { return .notFound }
        guard successStatuses.contains(response.status),
              let status = ItemsAPI.decode(Status.self, from: response.body) else {
            return .failed(.serverError)
        }
        return .status(status)
    }
}
