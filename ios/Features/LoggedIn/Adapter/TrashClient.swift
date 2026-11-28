import Foundation
import GrepCore
import GrepData

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

/// `/items/trash`·`/items/restore`를 부른다. 요청과 응답 해석은 코어 `TrashAPI`(GrepData)가 한다.
@MainActor
public final class HTTPTrashClient: TrashClient {
    private let authService: any AuthService
    private let httpTransport: any HTTPTransport

    public init(authService: any AuthService, httpTransport: any HTTPTransport) {
        self.authService = authService
        self.httpTransport = httpTransport
    }

    public func loadPage(limit: Int, cursor: String?) async -> TrashPageOutcome {
        guard let token = await authService.accessToken() else { return .sessionExpired }
        switch await TrashAPI.list(limit: limit, cursor: cursor, transport: httpTransport, accessToken: token) {
        case .page(let total, let items, let nextCursor):
            let entries = items.map { TrashListEntry(item: $0.item, daysLeft: $0.daysLeft) }
            return .page(total: total, entries: entries, nextCursor: nextCursor)
        case .sessionExpired: return .sessionExpired
        case .failed(let reason): return .failed(ArchiveLoadFailure(reason))
        case .cancelled: return .cancelled
        }
    }

    public func restore(numbers: [Int]) async -> TrashRestoreOutcome {
        guard let token = await authService.accessToken() else { return .sessionExpired }
        switch await TrashAPI.restore(numbers: numbers, transport: httpTransport, accessToken: token) {
        case .moved(let items): return .restored(numbers: items.map(\.number))
        case .notFound(let missing): return .notFound(numbers: missing)
        case .sessionExpired: return .sessionExpired
        case .failed(let reason): return .failed(ArchiveLoadFailure(reason))
        case .cancelled: return .cancelled
        }
    }

    public func empty() async -> TrashEmptyOutcome {
        guard let token = await authService.accessToken() else { return .sessionExpired }
        switch await TrashAPI.empty(transport: httpTransport, accessToken: token) {
        case .emptied(let count): return .emptied(count: count)
        case .sessionExpired: return .sessionExpired
        case .failed(let reason): return .failed(ArchiveLoadFailure(reason))
        case .cancelled: return .cancelled
        }
    }
}
