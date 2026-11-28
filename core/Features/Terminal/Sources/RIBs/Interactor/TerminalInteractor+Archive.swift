import FeatureTerminalInterface
import GrepCore
import GrepData

// MARK: 보관함 탭(#168, ARC-007)

extension TerminalInteractor {
    /// 보관함을 열었다. 보던 조건의 첫 쪽, 자동 묶음, 묶음, 찾아둔 검색을 차례로 받아 오는 대로 그린다.
    func openArchive() {
        reloadArchive(filter: viewState.archive?.filter ?? .all)
    }

    /// 거를 것을 골랐다. 보던 목록을 비우고 그 조건의 첫 쪽을 받는다. 옆 목록(묶음 등)은 그대로 둔다.
    func selectArchive(_ filter: ArchiveFilter) {
        let load = beginArchiveLoad()
        let current = viewState.archive ?? ArchiveState()
        update(viewState.with(archive: current.with(filter: filter, items: [], hasMore: false, status: .loading)))
        withToken { [weak self] token in
            await self?.fetchArchivePage(filter: filter, cursor: nil, load: load, accessToken: token)
        }
    }

    /// `더 보기`. 실패하면 보던 목록을 두고 오류로 둔다. 다시 누르면 같은 커서로 다시 묻는다.
    func loadMoreArchive() {
        guard let archive = viewState.archive, archive.status != .loading, archive.hasMore,
              let cursor = archiveCursor else { return }
        let load = beginArchiveLoad()
        update(viewState.with(archive: archive.with(status: .loading)))
        withToken { [weak self] token in
            await self?.fetchArchivePage(filter: archive.filter, cursor: cursor, load: load, accessToken: token)
        }
    }

    /// 저장·버리기·묶음 넣기 뒤에 부른다. 보관함을 연 적이 있을 때만 다시 받는다.
    func refreshArchiveIfOpened() {
        guard let archive = viewState.archive else { return }
        reloadArchive(filter: archive.filter)
    }

    private func reloadArchive(filter: ArchiveFilter) {
        let load = beginArchiveLoad()
        let current = viewState.archive ?? ArchiveState()
        update(viewState.with(archive: current.with(filter: filter, status: .loading)))
        withToken { [weak self] token in
            guard let self else { return }
            guard await fetchArchivePage(filter: filter, cursor: nil, load: load, accessToken: token) else { return }
            await fetchArchiveSides(load: load, accessToken: token)
        }
    }

    private func beginArchiveLoad() -> Int {
        archiveLoad += 1
        return archiveLoad
    }

    /// 토큰을 받아 `request`를 돌린다. 친 줄이 없으니 화면 줄은 찍지 않는다. 토큰이 없으면 만료를 알린다.
    private func withToken(_ request: @escaping @MainActor (_ accessToken: String) async -> Void) {
        startTask { [weak self] in
            guard let self else { return }
            let token = await authService.accessToken()
            guard !Task.isCancelled else { return }
            guard let token else {
                expire(restoring: viewState.input)
                return
            }
            await request(token)
        }
    }

    /// 한 쪽을 받아 그린다. 늦게 왔거나 실패·만료면 false.
    @discardableResult
    private func fetchArchivePage(filter: ArchiveFilter, cursor: String?, load: Int, accessToken: String) async -> Bool {
        guard let request = ArchiveQuery.request(
            for: filter, now: deviceTime.now(), timeZone: deviceTime.timeZone
        ) else {
            showArchiveError(load: load)
            return false
        }
        let outcome = await ArchiveAPI.page(request, cursor: cursor, transport: httpTransport, accessToken: accessToken)
        guard !Task.isCancelled, load == archiveLoad, let archive = viewState.archive else { return false }
        switch outcome {
        case .success(let page):
            archiveCursor = page.nextCursor
            let items = cursor == nil ? page.items : archive.items + page.items
            update(viewState.with(archive: archive.with(items: items, hasMore: page.nextCursor != nil, status: .idle)))
            return true
        case .failed:
            showArchiveError(load: load)
            return false
        case .sessionExpired:
            expire(restoring: viewState.input)
            return false
        case .cancelled:
            return false
        }
    }

    /// 자동 묶음·묶음·찾아둔 검색. 하나가 실패해도 받은 값은 그리고, 못 받은 목록은 전에 받은 값을 둔다.
    private func fetchArchiveSides(load: Int, accessToken: String) async {
        let groups = await ArchiveAPI.groups(
            timeZone: deviceTime.timeZoneID, transport: httpTransport, accessToken: accessToken
        )
        guard applyArchiveSide(groups, load: load, { $0.with(groups: $1) }) else { return }
        let bundles = await BundleAPI.list(transport: httpTransport, accessToken: accessToken)
        guard applyArchiveSide(Self.archiveOutcome(of: bundles), load: load, { $0.with(bundles: $1) }) else { return }
        let searches = await SavedSearchAPI.list(transport: httpTransport, accessToken: accessToken)
        // 0건 찾아둔 검색은 숨긴다(ARC-012).
        let shown = Self.archiveOutcome(of: searches).map { $0.filter { $0.count > 0 } }
        applyArchiveSide(shown, load: load) { $0.with(savedSearches: $1) }
    }

    /// 받은 값을 넣는다. 늦게 왔거나 만료·취소면 false(뒤 요청을 멈춘다).
    @discardableResult
    private func applyArchiveSide<Value>(
        _ outcome: ArchiveAPI.Outcome<Value>,
        load: Int,
        _ apply: (ArchiveState, Value) -> ArchiveState
    ) -> Bool {
        guard !Task.isCancelled, load == archiveLoad, let archive = viewState.archive else { return false }
        switch outcome {
        case .success(let value):
            update(viewState.with(archive: apply(archive, value)))
            return true
        case .failed:
            return true
        case .sessionExpired:
            expire(restoring: viewState.input)
            return false
        case .cancelled:
            return false
        }
    }

    private func showArchiveError(load: Int) {
        guard load == archiveLoad, let archive = viewState.archive else { return }
        update(viewState.with(archive: archive.with(status: .error)))
    }

    private static func archiveOutcome<Value>(of outcome: BundleAPI.Outcome<Value>) -> ArchiveAPI.Outcome<Value> {
        switch outcome {
        case .success(let value): .success(value)
        case .sessionExpired: .sessionExpired
        case .rejected, .failed: .failed
        case .cancelled: .cancelled
        }
    }

    private static func archiveOutcome<Value>(of outcome: SavedSearchAPI.Outcome<Value>) -> ArchiveAPI.Outcome<Value> {
        switch outcome {
        case .success(let value): .success(value)
        case .sessionExpired: .sessionExpired
        case .notFound, .rejected, .failed: .failed
        case .cancelled: .cancelled
        }
    }
}

extension ArchiveAPI.Outcome {
    func map<Other>(_ transform: (Value) -> Other) -> ArchiveAPI.Outcome<Other> {
        switch self {
        case .success(let value): .success(transform(value))
        case .sessionExpired: .sessionExpired
        case .failed: .failed
        case .cancelled: .cancelled
        }
    }
}

extension TerminalViewState {
    func with(archive: ArchiveState) -> TerminalViewState {
        var next = self
        next.archive = archive
        return next
    }
}

extension ArchiveState {
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
