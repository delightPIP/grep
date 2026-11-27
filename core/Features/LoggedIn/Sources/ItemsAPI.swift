#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FeatureLoggedInInterface
import GrepCore

/// 자료 API(api/openapi.yaml `saveItem`). 응답 해석까지만 하고 화면은 모른다.
enum ItemsAPI {
    enum SaveRequest: Equatable {
        case link(url: String)
        case text(String)
    }

    enum SaveOutcome: Equatable {
        case saved(ItemSummary)
        /// COM-001: 같은 자료가 있어 새로 만들지 않았다.
        case duplicate(ItemSummary)
        /// COM-001 규칙 7: 같은 자료가 휴지통에 있다.
        case inTrash(ItemSummary)
        case sessionExpired
        case failed(SaveFailure)
        case cancelled
    }

    private static let path = "/items"
    private static let unauthorizedStatus = 401
    private static let successStatuses = 200..<300
    private static let sessionExpiredCode = "session_expired"

    private struct SaveBody: Encodable {
        let kind: String
        let url: String?
        let text: String?
    }

    private struct SaveResultBody: Decodable {
        enum Result: String, Decodable {
            case saved
            case duplicate
            case inTrash
        }

        let result: Result
        let item: ItemSummary
    }

    private struct ErrorBody: Decodable {
        let code: String
    }

    @MainActor
    static func save(
        _ save: SaveRequest,
        transport: any HTTPTransport,
        accessToken: String,
        idempotencyKey: UUID
    ) async -> SaveOutcome {
        let request = HTTPRequest(
            method: .post,
            path: path,
            headers: [
                "Authorization": "Bearer \(accessToken)",
                "Content-Type": "application/json",
                "Idempotency-Key": idempotencyKey.uuidString.lowercased(),
            ],
            body: encode(save)
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
        return outcome(of: response)
    }

    private static func outcome(of response: HTTPResponse) -> SaveOutcome {
        if response.status == unauthorizedStatus,
           decode(ErrorBody.self, from: response.body)?.code == sessionExpiredCode {
            return .sessionExpired
        }
        guard successStatuses.contains(response.status),
              let body = decode(SaveResultBody.self, from: response.body) else {
            return .failed(.serverError)
        }
        switch body.result {
        case .saved: return .saved(body.item)
        case .duplicate: return .duplicate(body.item)
        case .inTrash: return .inTrash(body.item)
        }
    }

    private static func encode(_ save: SaveRequest) -> String {
        let body = switch save {
        case .link(let url): SaveBody(kind: "link", url: url, text: nil)
        case .text(let text): SaveBody(kind: "text", url: nil, text: text)
        }
        // 고정 모양의 구조체라 인코딩은 실패하지 않는다.
        let data = (try? JSONEncoder().encode(body)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from body: [UInt8]) -> T? {
        try? JSONDecoder().decode(type, from: Data(body))
    }
}
