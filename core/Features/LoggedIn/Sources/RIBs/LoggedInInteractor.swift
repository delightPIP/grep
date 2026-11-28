import FeatureArchiveInterface
import FeatureLoggedInInterface
import FeatureSettingsInterface
import FeatureTerminalInterface
import GrepCore
import GrepData
import RIBs

/// 로그인한 동안의 컨테이너(ADR-0015 결정 1). 계정에 딸린 일만 한다: `GET /me`, 만료 전에 치던 줄 되살리기, 만료, 로그아웃.
/// 화면에 그리는 것은 자식 `Terminal`·`Archive`·`Settings`가 한다. 컨테이너는 자식 사이 알림을 잇는다.
final class LoggedInInteractor: Interactor, TerminalListener, ArchiveListener, SettingsListener {

    private let authService: any AuthService
    private let httpTransport: ObservedTransport
    private weak var listener: (any LoggedInListener)?
    /// 자식 터미널. Router가 쥐고 있어 약하게 든다.
    weak var terminal: (any TerminalHandle)?
    /// 자식 보관함·설정. 붙이지 않은 조립이면 nil.
    weak var archive: (any ArchiveHandle)?
    weak var settings: (any SettingsHandle)?
    private var isSigningOut = false
    /// 만료 전에 치던 줄. 접근 토큰의 계정이 같을 때만 되살리고, 토큰을 받으면 비운다.
    private var pendingInput: PendingInput?
    /// 지금 로그인한 계정(접근 토큰의 `sub`). 토큰을 받기 전이거나 읽지 못하면 nil.
    private var subject: String?

    init(
        authService: any AuthService,
        httpTransport: any HTTPTransport,
        listener: any LoggedInListener,
        pendingInput: PendingInput?
    ) {
        self.authService = authService
        self.httpTransport = ObservedTransport(base: httpTransport)
        self.listener = listener
        self.pendingInput = pendingInput
        super.init()
    }

    override func didBecomeActive() {
        // `/me`가 서버에 닿았는지도 터미널의 `연결 끊김` 표시에 넣는다(COM-010 규칙 3).
        httpTransport.onReachabilityObserved = { [weak self] in self?.terminal?.observeReachability($0) }
        loadMe()
    }

    override func willResignActive() {
        httpTransport.onReachabilityObserved = nil
    }

    // MARK: TerminalListener

    func didRequestSignOut() {
        guard !isSigningOut else { return }
        isSigningOut = true
        startTask { [weak self] in
            guard let self else { return }
            await authService.signOut()
            guard !Task.isCancelled else { return }
            listener?.didSignOut()
        }
    }

    func didRequestSignOutEverywhere() {
        guard !isSigningOut else { return }
        isSigningOut = true
        startTask { [weak self] in
            guard let self else { return }
            // 토큰이 있으면 AI 도구 연결부터 끊는다. 끊지 못해도 이 기기는 로그아웃한다(ACC-002 규칙 4·5).
            if let token = await authService.accessToken() {
                await ConnectionNoticesAPI.revokeAll(transport: httpTransport, accessToken: token)
            }
            guard !Task.isCancelled else { return }
            await authService.signOutEverywhere()
            guard !Task.isCancelled else { return }
            listener?.didSignOutEverywhere()
        }
    }

    func didExpire(input: String) {
        expire(input: input)
    }

    func didChangeItems() {
        archive?.refreshIfOpened()
    }

    func didChangeConnections() {
        settings?.refreshConnectionsIfOpened()
    }

    // MARK: ArchiveListener, SettingsListener

    func archiveDidExpire() {
        expire(input: terminal?.input ?? "")
    }

    func settingsDidExpire() {
        expire(input: terminal?.input ?? "")
    }

    /// 모르는 사이 끊긴 AI 도구 연결을 그렙을 열 때 한 번 알린다(ACC-002 규칙 11).
    private func announceConnectionNotices(accessToken: String) async {
        let notices = await ConnectionNoticesAPI.take(transport: httpTransport, accessToken: accessToken)
        guard !Task.isCancelled else { return }
        terminal?.showConnectionNotices(notices)
    }

    private func loadMe() {
        startTask { [weak self] in
            guard let self else { return }
            let token = await authService.accessToken()
            // 비활성화로 취소됐으면 뷰가 이미 떨어졌다. 늦게 온 답을 그리지 않는다.
            guard !Task.isCancelled else { return }
            guard let token else {
                expire(input: terminal?.input ?? "")
                return
            }
            restorePendingInput(for: token)
            let outcome = await MeAPI.load(transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .loaded(let itemCount):
                terminal?.showItemCount(itemCount)
                await announceConnectionNotices(accessToken: token)
            case .sessionExpired: expire(input: terminal?.input ?? "")
            case .failed, .cancelled: break
            }
        }
    }

    /// 같은 계정으로 다시 로그인했으면 만료 전에 치던 줄을 되살린다(ACC-001 규칙 7, COM-009 규칙 4).
    /// 다른 계정이면 버린다(COM-009 규칙 3). 사용자가 그새 친 글이 있으면 터미널이 덮어쓰지 않는다.
    private func restorePendingInput(for token: String) {
        subject = AccessTokenSubject.read(from: token)
        defer { pendingInput = nil }
        guard let pendingInput, let subject, pendingInput.subject == subject else { return }
        terminal?.restoreInput(pendingInput.text)
    }

    /// 치던 줄을 들려 부모에게 보낸다. 부모가 로그인 화면으로 바꾼다(ACC-001 규칙 7).
    /// 계정을 모르면(토큰을 못 받음) 받아 둔 되살릴 줄을 그대로 돌려준다.
    /// 로그아웃 중이면 알리지 않는다. 사용자가 끝낸 세션을 만료로 보이지 않게 한다.
    private func expire(input: String) {
        guard !isSigningOut else { return }
        guard let subject else {
            listener?.didExpire(pendingInput: pendingInput)
            return
        }
        listener?.didExpire(pendingInput: input.isEmpty ? nil : PendingInput(text: input, subject: subject))
    }
}
