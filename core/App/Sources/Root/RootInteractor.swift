import FeatureLoggedIn
import FeatureLoggedInInterface
import FeatureLoggedOut
import FeatureLoggedOutInterface
import FeatureTerminal
import FeatureTerminalInterface
import GrepCore
import RIBs

@MainActor
protocol RootRouting: AnyObject {
    func routeToLoggedOut(notice: LoggedOutViewState.Notice?)
    func routeAwayFromLoggedOut()
    func routeToLoggedIn(pendingInput: PendingInput?)
    func routeAwayFromLoggedIn()
}

/// 로그인 여부에 따라 로그인 화면과 터미널 화면 중 하나를 붙인다(ACC-001 규칙 1).
final class RootInteractor: Interactor, LoggedOutListener, LoggedInListener {
    weak var router: (any RootRouting)?
    private let authService: any AuthService
    /// 로그인 만료 때 입력줄에 치던 줄과 그 계정. 같은 계정으로 다시 로그인하면 되살린다(ACC-001 규칙 7).
    private var pendingInput: PendingInput?

    init(authService: any AuthService) {
        self.authService = authService
        super.init()
    }

    /// 이 기기에 세션이 남아 있으면 로그인 화면을 건너뛴다(COM-009 규칙 1).
    override func didBecomeActive() {
        startTask { [weak self] in
            guard let self else { return }
            let hasSession = await authService.accessToken() != nil
            guard !Task.isCancelled else { return }
            if hasSession {
                router?.routeToLoggedIn(pendingInput: nil)
            } else {
                router?.routeToLoggedOut(notice: nil)
            }
        }
    }

    func didSignIn() {
        let restored = pendingInput
        pendingInput = nil
        router?.routeAwayFromLoggedOut()
        router?.routeToLoggedIn(pendingInput: restored)
    }

    /// 터미널 화면을 떼면 출력과 치던 줄이 함께 사라진다(COM-009 규칙 2).
    func didSignOut() {
        pendingInput = nil
        router?.routeAwayFromLoggedIn()
        router?.routeToLoggedOut(notice: .signedOut)
    }

    func didSignOutEverywhere() {
        pendingInput = nil
        router?.routeAwayFromLoggedIn()
        router?.routeToLoggedOut(notice: .signedOutEverywhere)
    }

    /// 서버가 거부한 세션을 이 기기에서도 지운다. 남겨 두면 새로 고침할 때 터미널이 잠깐 떴다가 다시 만료로 간다.
    /// 지운 뒤에 로그인 화면을 붙여, 새 로그인이 늦게 끝난 로그아웃에 지워지지 않게 한다.
    func didExpire(pendingInput: PendingInput?) {
        self.pendingInput = pendingInput
        router?.routeAwayFromLoggedIn()
        startTask { [weak self] in
            guard let self else { return }
            await authService.signOut()
            guard !Task.isCancelled else { return }
            router?.routeToLoggedOut(notice: .expired)
        }
    }
}
