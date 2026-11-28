
import GrepCore
import TerminalDomain
import GrepData

/// 자세히 보기 API(api/openapi.yaml `getItemDetail`). 응답 해석까지만 한다.
public enum ItemDetailAPI {
    public enum Outcome: Equatable {
        case detail(ItemDetail)
        case notFound(numbers: [Int])
        case sessionExpired
        case failed(CommandFailure)
        case cancelled
    }

    private static let notFoundStatus = 404
    private static let successStatuses = 200..<300

    @MainActor
    public static func fetch(number: Int, transport: any HTTPTransport, accessToken: String) async -> Outcome {
        let request = HTTPRequest(
            method: .get, path: "/items/\(number)", headers: ["Authorization": "Bearer \(accessToken)"]
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
        // 404 본문에 번호가 없어도 친 번호가 없는 번호다(ARC-001 규칙 10).
        if response.status == notFoundStatus { return .notFound(numbers: [number]) }
        guard successStatuses.contains(response.status),
              let detail = ItemsAPI.decode(ItemDetail.self, from: response.body) else {
            return .failed(.serverError)
        }
        return .detail(detail)
    }
}
