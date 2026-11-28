import GrepDomain

/// 보관함 목록 한 쪽. `nextCursor`가 nil이면 마지막 쪽이다.
public struct ArchivePage: Equatable, Sendable {
    public let items: [ItemSummary]
    public let nextCursor: String?

    public init(items: [ItemSummary], nextCursor: String?) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

/// 보관함 탭이 받는 값(ARC-007, ARC-003 규칙 18, ARC-012). 접근 토큰이 없으면 `sessionExpired`.
@MainActor
public protocol ArchiveRepository: AnyObject {
    /// 거르기 조건의 한 쪽. 모르는 조건이면 `failed`.
    func page(filter: ArchiveFilter, cursor: String?) async -> FetchOutcome<ArchivePage>
    /// 자동 묶음. 0건은 뺀다.
    func autoGroups() async -> FetchOutcome<[AutoGroupEntry]>
    /// 묶음. 0건도 둔다.
    func bundles() async -> FetchOutcome<[BundleEntry]>
    /// 찾아둔 검색. 0건은 뺀다.
    func savedSearches() async -> FetchOutcome<[SavedSearchEntry]>
}
