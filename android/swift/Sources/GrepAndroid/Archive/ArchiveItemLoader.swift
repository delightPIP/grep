import Foundation
import GrepCore

/// 보관함 목록 조회 실패 이유(COM-010).
public enum ArchiveLoadFailure: Equatable, Sendable {
    case disconnected
    case timedOut
    case serverError
}

/// 보관함 목록 한 쪽 조회 결과.
public enum ArchivePageOutcome: Equatable, Sendable {
    case page(items: [ItemSummary], nextCursor: String?)
    case sessionExpired
    case failed(ArchiveLoadFailure)
    case cancelled
}

/// `GET /items`로 최근 저장 순 자료 목록을 불러온다(api/openapi.yaml `listRecentItems`).
/// iOS `HTTPArchiveItemLoader`(#91)와 같은 규칙을 따른다.
@MainActor
public final class HTTPArchiveItemLoader {
    private static let itemsPath = "/items"
    private static let unauthorizedStatus = 401
    private static let successStatuses = 200..<300
    private static let sessionExpiredCode = "session_expired"
    private static let unreservedBytes = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~".utf8)

    private struct PageBody: Decodable {
        let items: [ItemSummary]
        let nextCursor: String?
    }

    private struct ErrorBody: Decodable {
        let code: String
    }

    private let authService: any AuthService
    private let httpTransport: any HTTPTransport

    public init(authService: any AuthService, httpTransport: any HTTPTransport) {
        self.authService = authService
        self.httpTransport = httpTransport
    }

    public func loadPage(limit: Int, cursor: String?) async -> ArchivePageOutcome {
        guard let token = await authService.accessToken() else {
            return .sessionExpired
        }
        let query = "limit=\(limit)" + (cursor.map { "&cursor=\(Self.percentEncoded($0))" } ?? "")
        let request = HTTPRequest(
            method: .get,
            path: "\(Self.itemsPath)?\(query)",
            headers: ["Authorization": "Bearer \(token)"]
        )

        let response: HTTPResponse
        do {
            response = try await httpTransport.send(request)
        } catch {
            switch error {
            case .cancelled: return .cancelled
            case .unreachable: return .failed(.disconnected)
            case .timedOut: return .failed(.timedOut)
            }
        }

        if response.status == Self.unauthorizedStatus {
            let errorBody = try? JSONDecoder().decode(ErrorBody.self, from: Data(response.body))
            return errorBody?.code == Self.sessionExpiredCode ? .sessionExpired : .failed(.serverError)
        }

        guard Self.successStatuses.contains(response.status),
              let page = try? JSONDecoder().decode(PageBody.self, from: Data(response.body))
        else {
            return .failed(.serverError)
        }
        return .page(items: page.items, nextCursor: page.nextCursor)
    }

    private static func percentEncoded(_ value: String) -> String {
        value.utf8.map { byte in
            unreservedBytes.contains(byte)
                ? String(UnicodeScalar(byte))
                : "%" + (byte < 16 ? "0" : "") + String(byte, radix: 16, uppercase: true)
        }.joined()
    }
}
