import GrepCore

/// 보관함 탭의 상태(#168). 보관함을 처음 열 때 채운다. 필드 이름의 원본은 `web/support/view-state.ts`의 `ArchiveState`.
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

/// 자동 묶음의 갈래(ARC-007).
public enum AutoGroup: String, Equatable, Sendable, CaseIterable {
    case format
    case source
    case date
    case tag
}

/// 자동 묶음 한 줄. `value`는 갈래마다 다르다.
/// format: link·text·image·file / source: 호스트 또는 `direct` / date: today·week·month·earlier / tag: 태그 낱말.
public struct AutoGroupEntry: Equatable, Sendable {
    public let group: AutoGroup
    public let value: String
    public let count: Int

    public init(group: AutoGroup, value: String, count: Int) {
        self.group = group
        self.value = value
        self.count = count
    }
}

/// 보관함 목록을 무엇으로 거르는지.
public enum ArchiveFilter: Equatable, Sendable {
    case all
    case auto(group: AutoGroup, value: String)
    case bundle(name: String)
    case savedSearch(query: String)
}

public enum ArchiveStatus: String, Equatable, Sendable {
    case idle
    case loading
    case error
}

/// 설정 탭의 상태(#168). 설정을 처음 열 때 채운다.
public struct SettingsState: Equatable, Sendable {
    public let account: SettingsAccount?
    public let connections: [ConnectionEntry]

    public init(account: SettingsAccount? = nil, connections: [ConnectionEntry] = []) {
        self.account = account
        self.connections = connections
    }
}

/// 계정 칸. `GET /me`에 있는 값만 쓴다.
public struct SettingsAccount: Equatable, Sendable {
    public let authProvider: AuthProvider
    public let itemCount: Int

    public init(authProvider: AuthProvider, itemCount: Int) {
        self.authProvider = authProvider
        self.itemCount = itemCount
    }
}
