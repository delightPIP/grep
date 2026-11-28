import FeatureTerminalInterface
import GrepCore
import GrepData

// MARK: 설정 탭(#168)

extension TerminalInteractor {
    /// 설정을 열었다. 계정(`GET /me`)과 AI 도구 연결(`GET /connections`)을 차례로 받는다.
    /// 하나를 받지 못하면 그 칸만 전에 받은 값을 둔다. 연결 끊기·로그아웃은 있던 명령을 그대로 쓴다.
    func openSettings() {
        if viewState.settings == nil { update(viewState.with(settings: SettingsState())) }
        startTask { [weak self] in
            guard let self else { return }
            guard let token = await authService.accessToken() else {
                guard !Task.isCancelled else { return }
                expire(restoring: viewState.input)
                return
            }
            guard !Task.isCancelled else { return }
            switch await SettingsAPI.account(transport: httpTransport, accessToken: token) {
            case .success(let account):
                guard !Task.isCancelled, let settings = viewState.settings else { return }
                update(viewState.with(settings: SettingsState(account: account, connections: settings.connections)))
            case .sessionExpired:
                guard !Task.isCancelled else { return }
                expire(restoring: viewState.input)
                return
            case .cancelled:
                return
            case .failed:
                break
            }
            await fetchSettingsConnections(accessToken: token)
        }
    }

    /// 연결을 끊은 뒤에 부른다. 설정을 연 적이 있을 때만 연결을 다시 받는다.
    func refreshSettingsConnectionsIfOpened(accessToken: String) async {
        guard viewState.settings != nil else { return }
        await fetchSettingsConnections(accessToken: accessToken)
    }

    private func fetchSettingsConnections(accessToken: String) async {
        let outcome = await ConnectionsAPI.list(transport: httpTransport, accessToken: accessToken)
        guard !Task.isCancelled, let settings = viewState.settings else { return }
        switch outcome {
        case .success(let list):
            update(viewState.with(settings: SettingsState(account: settings.account, connections: list.connections)))
        case .sessionExpired:
            expire(restoring: viewState.input)
        case .notFound, .failed, .cancelled:
            break
        }
    }
}

extension TerminalViewState {
    func with(settings: SettingsState) -> TerminalViewState {
        var next = self
        next.settings = settings
        return next
    }
}
