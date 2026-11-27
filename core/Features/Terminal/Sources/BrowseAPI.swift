#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FeatureTerminalInterface
import GrepCore

/// 자료 조회 API(api/openapi.yaml `listRecentItems`·`searchItems`·`getItemStatuses`·`getHealth`). 응답 해석까지만 한다.
enum BrowseAPI {
    enum PageOutcome: Equatable {
        /// `nextCursor`가 nil이면 마지막 쪽이다. `total`은 기간 조건이 있을 때만 내려온다(#114).
        case page(items: [ItemSummary], total: Int?, nextCursor: String?)
        case sessionExpired
        case failed(CommandFailure)
        case cancelled
    }

    enum SearchOutcome: Equatable {
        /// `total`은 조건에 맞는 전체 건수다. `nextCursor`가 nil이면 마지막 쪽이다.
        /// `isSavedSearch`는 같은 검색어를 찾아뒀는지(계약 2, #134). 서버가 주지 않으면 nil.
        case page(items: [ItemSummary], total: Int, nextCursor: String?, isSavedSearch: Bool?)
        case sessionExpired
        case failed(CommandFailure)
        case cancelled
    }

    enum LookupOutcome: Equatable {
        /// `missing`은 없거나 휴지통에 있는 번호다.
        case found(items: [ItemSummary], missing: [Int])
        case sessionExpired
        /// 세션 만료가 아닌 401(`unauthorized`). 같은 요청을 다시 보내도 같은 답이다.
        case unauthorized
        case failed(CommandFailure)
        case cancelled
    }

    private static let itemsPath = "/items"
    private static let searchPath = "/items/search"
    private static let statusPath = "/items/status"
    private static let healthPath = "/health"
    private static let unauthorizedStatus = 401
    private static let successStatuses = 200..<300
    private static let sessionExpiredCode = "session_expired"
    /// RFC 3986 unreserved. 그 밖의 글자는 쿼리 값에서 퍼센트 인코딩한다.
    private static let unreservedBytes = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~".utf8)

    private struct PageBody: Decodable {
        let items: [ItemSummary]
        let total: Int?
        let nextCursor: String?
    }

    private struct SearchBody: Decodable {
        let items: [ItemSummary]
        let total: Int
        let nextCursor: String?
        let isSavedSearch: Bool?
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
        case unauthorized
        case failed(CommandFailure)
        case cancelled
    }

    /// 최근 저장 순 한 쪽. `cursor`는 앞 응답의 `nextCursor`다.
    @MainActor
    static func recent(
        limit: Int,
        cursor: String?,
        period: Period? = nil,
        transport: any HTTPTransport,
        accessToken: String
    ) async -> PageOutcome {
        var params = ["limit=\(limit)"]
        if let cursor { params.append("cursor=\(percentEncoded(cursor))") }
        if let period {
            params.append("from=\(percentEncoded(period.from))")
            params.append("to=\(percentEncoded(period.to))")
        }
        switch await get("\(itemsPath)?\(params.joined(separator: "&"))", as: PageBody.self, transport: transport, accessToken: accessToken) {
        case .body(let page): return .page(items: page.items, total: page.total, nextCursor: page.nextCursor)
        case .sessionExpired: return .sessionExpired
        // 명령 실패 이유는 COM-010의 셋뿐이다.
        case .unauthorized: return .failed(.serverError)
        case .failed(let reason): return .failed(reason)
        case .cancelled: return .cancelled
        }
    }

    /// 찾기 한 쪽. `q`는 검색어, `tag`는 `#` 없는 태그를 조건마다 한 번씩 준다(ARC-002 규칙 5~7).
    @MainActor
    static func search(
        _ query: SearchQuery,
        limit: Int,
        cursor: String?,
        period: Period? = nil,
        transport: any HTTPTransport,
        accessToken: String
    ) async -> SearchOutcome {
        var conditions = (query.words.isEmpty ? [] : ["q=\(percentEncoded(query.words))"])
            + query.tags.map { "tag=\(percentEncoded($0))" }
            + ["limit=\(limit)"]
            + (cursor.map { ["cursor=\(percentEncoded($0))"] } ?? [])
        if let period {
            conditions.append("from=\(percentEncoded(period.from))")
            conditions.append("to=\(percentEncoded(period.to))")
        }
        let path = "\(searchPath)?\(conditions.joined(separator: "&"))"
        switch await get(path, as: SearchBody.self, transport: transport, accessToken: accessToken) {
        case .body(let page):
            return .page(
                items: page.items, total: page.total, nextCursor: page.nextCursor, isSavedSearch: page.isSavedSearch
            )
        case .sessionExpired: return .sessionExpired
        case .unauthorized: return .failed(.serverError)
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
        case .unauthorized: return .unauthorized
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
        if response.status == unauthorizedStatus {
            let isSessionExpired = decode(ErrorBody.self, from: response.body)?.code == sessionExpiredCode
            return isSessionExpired ? .sessionExpired : .unauthorized
        }
        guard successStatuses.contains(response.status), let body = decode(type, from: response.body) else {
            return .failed(.serverError)
        }
        return .body(body)
    }

    /// 경로 조각·쿼리 값용. RFC 3986 unreserved 밖은 모두 %XX로 바꾼다.
    static func percentEncoded(_ value: String) -> String {
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
