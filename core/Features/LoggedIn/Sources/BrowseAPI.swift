#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FeatureLoggedInInterface
import GrepCore

/// 자료 조회 API(api/openapi.yaml `listRecentItems`·`getItemStatuses`·`getHealth`). 응답 해석까지만 한다.
enum BrowseAPI {
    enum PageOutcome: Equatable {
        /// `nextCursor`가 nil이면 마지막 쪽이다.
        case page(items: [ItemSummary], nextCursor: String?)
        case sessionExpired
        case failed(CommandFailure)
        case cancelled
    }

    enum LookupOutcome: Equatable {
        /// `missing`은 없거나 휴지통에 있는 번호다.
        case found(items: [ItemSummary], missing: [Int])
        case sessionExpired
        case failed(CommandFailure)
        case cancelled
    }

    private static let itemsPath = "/items"
    private static let statusPath = "/items/status"
    private static let healthPath = "/health"
    private static let unauthorizedStatus = 401
    private static let successStatuses = 200..<300
    private static let sessionExpiredCode = "session_expired"
    /// RFC 3986 unreserved. 그 밖의 글자는 쿼리 값에서 퍼센트 인코딩한다.
    private static let unreservedBytes = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~".utf8)

    private struct PageBody: Decodable {
        let items: [ItemSummary]
        let nextCursor: String?
    }

    private struct LookupBody: Decodable {
        let items: [ItemSummary]
        let missing: [Int]
    }

    private struct ErrorBody: Decodable {
        let code: String
    }

    private enum Reply<Body> {
        case body(Body)
        case sessionExpired
        case failed(CommandFailure)
        case cancelled
    }

    /// 최근 저장 순 한 쪽. `cursor`는 앞 응답의 `nextCursor`다.
    @MainActor
    static func recent(
        limit: Int,
        cursor: String?,
        transport: any HTTPTransport,
        accessToken: String
    ) async -> PageOutcome {
        let query = "limit=\(limit)" + (cursor.map { "&cursor=\(percentEncoded($0))" } ?? "")
        switch await get("\(itemsPath)?\(query)", as: PageBody.self, transport: transport, accessToken: accessToken) {
        case .body(let page): return .page(items: page.items, nextCursor: page.nextCursor)
        case .sessionExpired: return .sessionExpired
        case .failed(let reason): return .failed(reason)
        case .cancelled: return .cancelled
        }
    }

    /// 번호로 자료를 다시 받는다. 처리 중 자료 폴링에 쓴다(ARC-005 규칙 10).
    @MainActor
    static func statuses(
        of numbers: [Int],
        transport: any HTTPTransport,
        accessToken: String
    ) async -> LookupOutcome {
        let path = "\(statusPath)?numbers=\(numbers.map(String.init).joined(separator: ","))"
        switch await get(path, as: LookupBody.self, transport: transport, accessToken: accessToken) {
        case .body(let lookup): return .found(items: lookup.items, missing: lookup.missing)
        case .sessionExpired: return .sessionExpired
        case .failed(let reason): return .failed(reason)
        case .cancelled: return .cancelled
        }
    }

    /// 서버가 답하는지만 본다(COM-010). 답이 왔는지는 전송 계층을 지켜보는 쪽이 안다.
    @MainActor
    static func checkHealth(transport: any HTTPTransport) async {
        _ = try? await transport.send(HTTPRequest(method: .get, path: healthPath))
    }

    @MainActor
    private static func get<Body: Decodable>(
        _ path: String,
        as type: Body.Type,
        transport: any HTTPTransport,
        accessToken: String
    ) async -> Reply<Body> {
        let request = HTTPRequest(method: .get, path: path, headers: ["Authorization": "Bearer \(accessToken)"])
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
        if response.status == unauthorizedStatus,
           decode(ErrorBody.self, from: response.body)?.code == sessionExpiredCode {
            return .sessionExpired
        }
        guard successStatuses.contains(response.status), let body = decode(type, from: response.body) else {
            return .failed(.serverError)
        }
        return .body(body)
    }

    private static func percentEncoded(_ value: String) -> String {
        value.utf8.map { byte in
            unreservedBytes.contains(byte)
                ? String(UnicodeScalar(byte))
                : "%" + (byte < 16 ? "0" : "") + String(byte, radix: 16, uppercase: true)
        }.joined()
    }

    private static func decode<T: Decodable>(_ type: T.Type, from body: [UInt8]) -> T? {
        try? JSONDecoder().decode(type, from: Data(body))
    }
}
