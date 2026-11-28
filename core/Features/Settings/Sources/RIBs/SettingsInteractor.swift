import FeatureSettingsInterface
import GrepCore
import GrepData
import RIBs

/// 설정 탭(#168). 열 때 계정(`GET /me`)과 AI 도구 연결(`GET /connections`)을 차례로 받는다.
/// 하나를 받지 못하면 그 칸만 전에 받은 값을 둔다. 연결 끊기·로그아웃은 터미널에 있던 명령을 그대로 쓴다.
final class SettingsInteractor: PresentableInteractor<any SettingsPresentable>, SettingsPresentableListener, SettingsHandle {
    private let authService: any AuthService
    private let httpTransport: any HTTPTransport
    private weak var listener: (any SettingsListener)?
    /// 처음 열기 전이면 nil.
    private var state: SettingsState?

    init(
        presenter: any SettingsPresentable,
        authService: any AuthService,
        httpTransport: any HTTPTransport,
        listener: any SettingsListener
    ) {
        self.authService = authService
        self.httpTransport = httpTransport
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

    // MARK: SettingsPresentableListener

    func handle(_ action: SettingsViewAction) {
        switch action {
        case .open: open()
        }
    }

    // MARK: SettingsHandle

    func refreshConnectionsIfOpened() {
        guard state != nil else { return }
        withToken { [weak self] token in await self?.fetchConnections(accessToken: token) }
    }

    // MARK: 받기

    private func open() {
        if state == nil { update(SettingsState()) }
        withToken { [weak self] token in
            guard let self else { return }
            switch await SettingsAPI.account(transport: httpTransport, accessToken: token) {
            case .success(let account):
                guard !Task.isCancelled, let state else { return }
                update(SettingsState(account: account, connections: state.connections))
            case .sessionExpired:
                guard !Task.isCancelled else { return }
                listener?.settingsDidExpire()
                return
            case .cancelled:
                return
            case .failed:
                break
            }
            await fetchConnections(accessToken: token)
        }
    }

    private func fetchConnections(accessToken: String) async {
        let outcome = await ConnectionsAPI.list(transport: httpTransport, accessToken: accessToken)
        guard !Task.isCancelled, let state else { return }
        switch outcome.fetchOutcome {
        case .success(let list):
            update(SettingsState(account: state.account, connections: list.connections))
        case .sessionExpired:
            listener?.settingsDidExpire()
        case .failed, .cancelled:
            break
        }
    }

    /// 토큰을 받아 `request`를 돌린다. 토큰이 없으면 만료를 알린다.
    private func withToken(_ request: @escaping @MainActor (_ accessToken: String) async -> Void) {
        startTask { [weak self] in
            guard let self else { return }
            let token = await authService.accessToken()
            guard !Task.isCancelled else { return }
            guard let token else {
                listener?.settingsDidExpire()
                return
            }
            await request(token)
        }
    }

    private func update(_ next: SettingsState) {
        guard next != state else { return }
        state = next
        presenter.render(next)
    }
}
