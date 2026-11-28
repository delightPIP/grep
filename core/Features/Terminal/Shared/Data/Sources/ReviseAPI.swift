#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

import GrepCore
import TerminalDomain
import GrepData

/// 자료 고치기 API(api/openapi.yaml `reviseItem`). 응답 해석까지만 한다.
public enum ReviseAPI {
    public enum Outcome: Equatable {
        case revised(ItemSummary)
        case notFound
        case sessionExpired
        case failed(CommandFailure)
        case cancelled
    }

    private static let notFoundStatus = 404
    private static let successStatuses = 200..<300

    private struct RequestBody: Encodable {
        public let title: String?
        public let summary: String?
        public let removeTags: [String]?
    }

    @MainActor
    public static func revise(
        number: Int,
        title: String? = nil,
        summary: String? = nil,
        removeTags: [String]? = nil,
        transport: any HTTPTransport,
        accessToken: String
    ) async -> Outcome {
        let encoded = (try? JSONEncoder().encode(RequestBody(title: title, summary: summary, removeTags: removeTags)))
            .map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        let request = HTTPRequest(
            method: .patch,
            path: "/items/\(number)",
            headers: [
                "Authorization": "Bearer \(accessToken)",
                "Content-Type": "application/json",
            ],
            body: encoded
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
        if response.status == notFoundStatus { return .notFound }
        guard successStatuses.contains(response.status),
              let item = ItemsAPI.decode(ItemSummary.self, from: response.body) else {
            return .failed(.serverError)
        }
        return .revised(item)
    }
}
