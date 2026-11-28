import FeatureArchiveInterface
import GrepCore
import GrepData
import RIBs

/// 보관함 탭(#168, ARC-007). 처음 열 때 보던 조건의 첫 쪽, 자동 묶음, 묶음, 찾아둔 검색을 차례로 받아 오는 대로 그린다.
/// 늦게 온 응답은 차례 번호(`load`)로 버린다.
final class ArchiveInteractor: PresentableInteractor<any ArchivePresentable>, ArchivePresentableListener, ArchiveHandle {
    private let authService: any AuthService
    private let httpTransport: any HTTPTransport
    private let deviceTime: DeviceTime
    private weak var listener: (any ArchiveListener)?
    /// 처음 열기 전이면 nil.
    private var state: ArchiveState?
    /// 다음 쪽 커서. 마지막 쪽이면 nil.
    private var cursor: String?
    /// 새로 받을 때마다 늘린다. 응답이 왔을 때 값이 다르면 그 응답은 늦게 온 것이다.
    private var load = 0

    init(
        presenter: any ArchivePresentable,
        authService: any AuthService,
        httpTransport: any HTTPTransport,
        deviceTime: DeviceTime,
        listener: any ArchiveListener
    ) {
        self.authService = authService
        self.httpTransport = httpTransport
        self.deviceTime = deviceTime
        self.listener = listener
        super.init(presenter: presenter)
    }

    override func didBecomeActive() {
        presenter.listener = self
        presenter.render(state)
    }

    override func willResignActive() {
        presenter.listener = nil
    }

    // MARK: ArchivePresentableListener

    func handle(_ action: ArchiveViewAction) {
        switch action {
        case .open: reload(filter: state?.filter ?? .all)
        case .select(let filter): select(filter)
        case .more: loadMore()
        }
    }

    // MARK: ArchiveHandle

    func refreshIfOpened() {
        guard let state else { return }
        reload(filter: state.filter)
    }

    // MARK: 받기

    /// 거를 것을 골랐다. 보던 목록을 비우고 그 조건의 첫 쪽을 받는다. 옆 목록(묶음 등)은 그대로 둔다.
    private func select(_ filter: ArchiveFilter) {
        let load = beginLoad()
        update((state ?? ArchiveState()).with(filter: filter, items: [], hasMore: false, status: .loading))
        withToken { [weak self] token in
            await self?.fetchPage(filter: filter, cursor: nil, load: load, accessToken: token)
        }
    }

    /// `더 보기`. 실패하면 보던 목록을 두고 오류로 둔다. 다시 누르면 같은 커서로 다시 묻는다.
    private func loadMore() {
        guard let state, state.status != .loading, state.hasMore, let cursor else { return }
        let load = beginLoad()
        update(state.with(status: .loading))
        withToken { [weak self] token in
            await self?.fetchPage(filter: state.filter, cursor: cursor, load: load, accessToken: token)
        }
    }

    private func reload(filter: ArchiveFilter) {
        let load = beginLoad()
        update((state ?? ArchiveState()).with(filter: filter, status: .loading))
        withToken { [weak self] token in
            guard let self else { return }
            guard await fetchPage(filter: filter, cursor: nil, load: load, accessToken: token) else { return }
            await fetchSides(load: load, accessToken: token)
        }
    }

    private func beginLoad() -> Int {
        load += 1
        return load
    }

    /// 토큰을 받아 `request`를 돌린다. 토큰이 없으면 만료를 알린다.
    private func withToken(_ request: @escaping @MainActor (_ accessToken: String) async -> Void) {
        startTask { [weak self] in
            guard let self else { return }
            let token = await authService.accessToken()
            guard !Task.isCancelled else { return }
            guard let token else {
                listener?.archiveDidExpire()
                return
            }
            await request(token)
        }
    }

    /// 한 쪽을 받아 그린다. 늦게 왔거나 실패·만료면 false.
    @discardableResult
    private func fetchPage(filter: ArchiveFilter, cursor: String?, load: Int, accessToken: String) async -> Bool {
        guard let request = ArchiveQuery.request(for: filter, now: deviceTime.now(), timeZone: deviceTime.timeZone) else {
            showError(load: load)
            return false
        }
        let outcome = await ArchiveAPI.page(request, cursor: cursor, transport: httpTransport, accessToken: accessToken)
        guard !Task.isCancelled, load == self.load, let state else { return false }
        switch outcome {
        case .success(let page):
            self.cursor = page.nextCursor
            let items = cursor == nil ? page.items : state.items + page.items
            update(state.with(items: items, hasMore: page.nextCursor != nil, status: .idle))
            return true
        case .failed:
            showError(load: load)
            return false
        case .sessionExpired:
            listener?.archiveDidExpire()
            return false
        case .cancelled:
            return false
        }
    }

    /// 자동 묶음·묶음·찾아둔 검색. 하나가 실패해도 받은 값은 그리고, 못 받은 목록은 전에 받은 값을 둔다.
    private func fetchSides(load: Int, accessToken: String) async {
        let groups = await ArchiveAPI.groups(
            timeZone: deviceTime.timeZoneID, transport: httpTransport, accessToken: accessToken
        )
        guard apply(groups, load: load, { $0.with(groups: $1) }) else { return }
        let bundles = await BundleAPI.list(transport: httpTransport, accessToken: accessToken)
        guard apply(bundles.fetchOutcome, load: load, { $0.with(bundles: $1) }) else { return }
        let searches = await SavedSearchAPI.list(transport: httpTransport, accessToken: accessToken)
        // 0건 찾아둔 검색은 숨긴다(ARC-012).
        let shown = searches.fetchOutcome.map { $0.filter { $0.count > 0 } }
        apply(shown, load: load) { $0.with(savedSearches: $1) }
    }

    /// 받은 값을 넣는다. 늦게 왔거나 만료·취소면 false(뒤 요청을 멈춘다).
    @discardableResult
    private func apply<Value>(
        _ outcome: FetchOutcome<Value>,
        load: Int,
        _ change: (ArchiveState, Value) -> ArchiveState
    ) -> Bool {
        guard !Task.isCancelled, load == self.load, let state else { return false }
        switch outcome {
        case .success(let value):
            update(change(state, value))
            return true
        case .failed:
            return true
        case .sessionExpired:
            listener?.archiveDidExpire()
            return false
        case .cancelled:
            return false
        }
    }

    private func showError(load: Int) {
        guard load == self.load, let state else { return }
        update(state.with(status: .error))
    }

    private func update(_ next: ArchiveState) {
        guard next != state else { return }
        state = next
        presenter.render(next)
    }
}
