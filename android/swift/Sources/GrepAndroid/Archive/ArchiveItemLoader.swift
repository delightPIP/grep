import Foundation
import GrepCore
import GrepData

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

/// `GET /items`로 최근 저장 순 자료 목록을 불러온다. 요청과 응답 해석은 코어 `BrowseAPI`(GrepData)가 한다.
@MainActor
public final class HTTPArchiveItemLoader {
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
        switch await BrowseAPI.recent(limit: limit, cursor: cursor, transport: httpTransport, accessToken: token) {
        case .page(let items, _, let nextCursor): return .page(items: items, nextCursor: nextCursor)
        case .sessionExpired: return .sessionExpired
        case .failed(let reason): return .failed(ArchiveLoadFailure(reason))
        case .cancelled: return .cancelled
        }
    }
}

extension ArchiveLoadFailure {
    /// 코어 명령 실패 이유를 보관함 실패 이유로. 보관함에는 클립보드가 없다.
    init(_ reason: CommandFailure) {
        switch reason {
        case .disconnected: self = .disconnected
        case .timedOut: self = .timedOut
        case .serverError, .clipboardDenied: self = .serverError
        }
    }
}
