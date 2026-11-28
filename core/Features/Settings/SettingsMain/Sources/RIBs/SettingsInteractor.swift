import FeatureSettingsInterface
import GrepCore
import RIBs
import SettingsDomain

/// 설정 탭(#168). 열 때 계정과 AI 도구 연결을 차례로 받는다.
/// 하나를 받지 못하면 그 칸만 전에 받은 값을 둔다. 연결 끊기·로그아웃은 터미널에 있던 명령을 그대로 쓴다.
final class SettingsInteractor: PresentableInteractor<any SettingsPresentable>, SettingsPresentableListener, SettingsHandle {
    private let repository: any SettingsRepository
    private weak var listener: (any SettingsListener)?
    /// 처음 열기 전이면 nil.
    private var state: SettingsState?

    init(presenter: any SettingsPresentable, repository: any SettingsRepository, listener: any SettingsListener) {
        self.repository = repository
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
        startTask { [weak self] in await self?.fetchConnections() }
    }

    // MARK: 받기

    private func open() {
        if state == nil { update(SettingsState()) }
        startTask { [weak self] in
            guard let self else { return }
            let outcome = await repository.account()
            guard !Task.isCancelled else { return }
            switch outcome {
            case .success(let account):
                guard let state else { return }
                update(SettingsState(account: account, connections: state.connections))
            case .sessionExpired:
                listener?.settingsDidExpire()
                return
            case .cancelled:
                return
            case .failed:
                break
            }
            await fetchConnections()
        }
    }

    private func fetchConnections() async {
        let outcome = await repository.connections()
        guard !Task.isCancelled, let state else { return }
        switch outcome {
        case .success(let connections):
            update(SettingsState(account: state.account, connections: connections))
        case .sessionExpired:
            listener?.settingsDidExpire()
        case .failed, .cancelled:
            break
        }
    }

    private func update(_ next: SettingsState) {
        guard next != state else { return }
        state = next
        presenter.render(next)
    }
}
