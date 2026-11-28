import FeatureArchiveInterface
import GrepCore

extension ArchiveState {
    /// 준 값만 바꾼 새 상태.
    func with(
        groups: [AutoGroupEntry]? = nil,
        bundles: [BundleEntry]? = nil,
        savedSearches: [SavedSearchEntry]? = nil,
        filter: ArchiveFilter? = nil,
        items: [ItemSummary]? = nil,
        hasMore: Bool? = nil,
        status: ArchiveStatus? = nil
    ) -> ArchiveState {
        ArchiveState(
            groups: groups ?? self.groups,
            bundles: bundles ?? self.bundles,
            savedSearches: savedSearches ?? self.savedSearches,
            filter: filter ?? self.filter,
            items: items ?? self.items,
            hasMore: hasMore ?? self.hasMore,
            status: status ?? self.status
        )
    }
}
