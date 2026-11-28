@_exported import ArchiveDomain
import GrepCore

/// 보관함 탭의 상태(#168, ARC-007). 필드 이름의 원본은 `web/support/view-state.ts`의 `ArchiveState`.
public struct ArchiveState: Equatable, Sendable {
    /// 자동 묶음(ARC-007). 0건은 서버가 뺀다.
    public let groups: [AutoGroupEntry]
    /// 묶음. 0건도 보인다(ARC-003 규칙 18).
    public let bundles: [BundleEntry]
    /// 찾아둔 검색. 0건은 숨긴다(ARC-012).
    public let savedSearches: [SavedSearchEntry]
    public let filter: ArchiveFilter
    public let items: [ItemSummary]
    public let hasMore: Bool
    public let status: ArchiveStatus

    public init(
        groups: [AutoGroupEntry] = [],
        bundles: [BundleEntry] = [],
        savedSearches: [SavedSearchEntry] = [],
        filter: ArchiveFilter = .all,
        items: [ItemSummary] = [],
        hasMore: Bool = false,
        status: ArchiveStatus = .idle
    ) {
        self.groups = groups
        self.bundles = bundles
        self.savedSearches = savedSearches
        self.filter = filter
        self.items = items
        self.hasMore = hasMore
        self.status = status
    }
}

public enum ArchiveStatus: String, Equatable, Sendable {
    case idle
    case loading
    case error
}
