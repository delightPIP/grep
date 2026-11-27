import Foundation
import GrepCore

/// 휴지통 한 줄(api `TrashItem`). `daysLeft`는 영구 삭제까지 남은 날(ARC-008 규칙 10).
public struct TrashListEntry: Equatable, Sendable, Decodable {
    public let item: ItemSummary
    public let daysLeft: Int

    public init(item: ItemSummary, daysLeft: Int) {
        self.item = item
        self.daysLeft = daysLeft
    }
}

/// `휴지통` 한 쪽 조회 결과.
public enum TrashPageOutcome: Equatable, Sendable {
    case page(total: Int, entries: [TrashListEntry], nextCursor: String?)
    case sessionExpired
    case failed(ArchiveLoadFailure)
    case cancelled
}

/// `되살리기` 결과. `notFound`는 이미 영구 삭제됐거나 휴지통에 없는 번호다(ARC-001).
public enum TrashRestoreOutcome: Equatable, Sendable {
    case restored(numbers: [Int])
    case notFound(numbers: [Int])
    case sessionExpired
    case failed(ArchiveLoadFailure)
    case cancelled
}

/// `휴지통 비우기` 결과.
public enum TrashEmptyOutcome: Equatable, Sendable {
    case emptied(count: Int)
    case sessionExpired
    case failed(ArchiveLoadFailure)
    case cancelled
}

/// 설정 › 휴지통 화면의 서버 포트(ARC-008 규칙 11). Example 앱과 단위 테스트에서 가짜 구현으로 교체한다.
@MainActor
public protocol TrashClient: AnyObject {
    func loadPage(limit: Int, cursor: String?) async -> TrashPageOutcome
    func restore(numbers: [Int]) async -> TrashRestoreOutcome
    func empty() async -> TrashEmptyOutcome
}

/// `/items/trash`·`/items/restore`를 부른다(api/openapi.yaml, 코어 `TrashAPI`와 같은 계약).
@MainActor
public final class HTTPTrashClient: TrashClient {
    private static let trashPath = "/items/trash"
    private static let restorePath = "/items/restore"
    private static let unauthorizedStatus = 401
    private static let notFoundStatus = 404
    private static let successStatuses = 200..<300
    private static let sessionExpiredCode = "session_expired"
    private static let unreservedBytes = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~".utf8)

    private struct PageBody: Decodable {
        let items: [TrashListEntry]
        let total: Int
        let nextCursor: String?
    }

    private struct NumbersBody: Codable {
        let numbers: [Int]
    }

    private struct RefListBody: Decodable {
        struct Ref: Decodable { let number: Int }
        let items: [Ref]
    }

    private struct CountBody: Decodable {
        let count: Int
    }

    private struct ErrorBody: Decodable {
        let code: String
    }

    /// 보낸 결과. 응답을 받았으면 `response`, 못 받았으면 이유.
    private enum Sent {
        case response(HTTPResponse)
        case sessionExpired
        case failed(ArchiveLoadFailure)
        case cancelled
    }

    private let authService: any AuthService
    private let httpTransport: any HTTPTransport

    public init(authService: any AuthService, httpTransport: any HTTPTransport) {
        self.authService = authService
        self.httpTransport = httpTransport
    }

    public func loadPage(limit: Int, cursor: String?) async -> TrashPageOutcome {
        let query = "limit=\(limit)" + (cursor.map { "&cursor=\(Self.percentEncoded($0))" } ?? "")
        switch await send(method: .get, path: "\(Self.trashPath)?\(query)", body: nil) {
        case .response(let response):
            guard Self.successStatuses.contains(response.status),
                  let page = Self.decode(PageBody.self, response) else {
                return .failed(.serverError)
            }
            return .page(total: page.total, entries: page.items, nextCursor: page.nextCursor)
        case .sessionExpired: return .sessionExpired
        case .failed(let reason): return .failed(reason)
        case .cancelled: return .cancelled
        }
    }

    public func restore(numbers: [Int]) async -> TrashRestoreOutcome {
        let body = (try? JSONEncoder().encode(NumbersBody(numbers: numbers))).flatMap { String(data: $0, encoding: .utf8) }
        switch await send(method: .post, path: Self.restorePath, body: body) {
        case .response(let response):
            if response.status == Self.notFoundStatus, let missing = Self.decode(NumbersBody.self, response) {
                return .notFound(numbers: missing.numbers)
            }
            guard Self.successStatuses.contains(response.status),
                  let restored = Self.decode(RefListBody.self, response) else {
                return .failed(.serverError)
            }
            return .restored(numbers: restored.items.map(\.number))
        case .sessionExpired: return .sessionExpired
        case .failed(let reason): return .failed(reason)
        case .cancelled: return .cancelled
        }
    }

    public func empty() async -> TrashEmptyOutcome {
        switch await send(method: .delete, path: Self.trashPath, body: nil) {
        case .response(let response):
            guard Self.successStatuses.contains(response.status),
                  let emptied = Self.decode(CountBody.self, response) else {
                return .failed(.serverError)
            }
            return .emptied(count: emptied.count)
        case .sessionExpired: return .sessionExpired
        case .failed(let reason): return .failed(reason)
        case .cancelled: return .cancelled
        }
    }

    private func send(method: HTTPRequest.Method, path: String, body: String?) async -> Sent {
        guard let token = await authService.accessToken() else {
            return .sessionExpired
        }
        var headers = ["Authorization": "Bearer \(token)"]
        if body != nil {
            headers["Content-Type"] = "application/json"
        }
        let response: HTTPResponse
        do {
            response = try await httpTransport.send(HTTPRequest(method: method, path: path, headers: headers, body: body))
        } catch {
            switch error {
            case .cancelled: return .cancelled
            case .unreachable: return .failed(.disconnected)
            case .timedOut: return .failed(.timedOut)
            }
        }
        if response.status == Self.unauthorizedStatus {
            return Self.decode(ErrorBody.self, response)?.code == Self.sessionExpiredCode ? .sessionExpired : .failed(.serverError)
        }
        return .response(response)
    }

    private static func decode<Body: Decodable>(_ type: Body.Type, _ response: HTTPResponse) -> Body? {
        try? JSONDecoder().decode(type, from: Data(response.body))
    }

    private static func percentEncoded(_ value: String) -> String {
        value.utf8.map { byte in
            unreservedBytes.contains(byte)
                ? String(UnicodeScalar(byte))
                : "%" + (byte < 16 ? "0" : "") + String(byte, radix: 16, uppercase: true)
        }.joined()
    }
}
