
import GrepCore
import TerminalDomain
import GrepData

/// 샘플 8건 저장 API(api/openapi.yaml `saveSamples`). 응답 해석까지만 한다.
public enum SamplesAPI {
    public enum Outcome: Equatable {
        case saved(firstNumber: Int, lastNumber: Int, created: Bool)
        case sessionExpired
        case failed(CommandFailure)
        case cancelled
    }

    private static let path = "/samples"
    private static let createdStatus = 201
    private static let successStatuses = 200..<300

    private struct Body: Decodable {
        public let firstNumber: Int
        public let lastNumber: Int
    }

    @MainActor
    public static func save(transport: any HTTPTransport, accessToken: String) async -> Outcome {
        let request = HTTPRequest(
            method: .post,
            path: path,
            headers: ["Authorization": "Bearer \(accessToken)"]
        )
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
        guard successStatuses.contains(response.status),
              let body = ItemsAPI.decode(Body.self, from: response.body) else {
            return .failed(.serverError)
        }
        return .saved(
            firstNumber: body.firstNumber,
            lastNumber: body.lastNumber,
            created: response.status == createdStatus
        )
    }
}
