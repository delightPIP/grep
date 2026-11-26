import FeatureLoggedOutInterface
import GrepCore
import RIBs

public final class LoggedOutBuilder: Builder<any LoggedOutDependency>, LoggedOutBuildable {
    private let viewFactory: any LoggedOutViewFactory

    public init(dependency: any LoggedOutDependency, viewFactory: any LoggedOutViewFactory) {
        self.viewFactory = viewFactory
        super.init(dependency: dependency)
    }

    public func build(listener: any LoggedOutListener, notice: LoggedOutViewState.Notice?) -> any ViewableRouting {
        let view = viewFactory.makeLoggedOutView()
        let interactor = LoggedOutInteractor(
            presenter: view,
            authService: dependency.authService,
            listener: listener,
            notice: notice
        )
        return LoggedOutRouter(interactor: interactor, viewController: view)
    }
}

/// 로그인 버튼 입력을 받아 외부 로그인 창을 하나만 열고(ACC-001 규칙 9), 결과를 알림으로 그린다(규칙 8).
/// 로그인 화면은 버튼 말고 다른 입력을 받지 않는다(규칙 1). `LoggedOutViewAction`에 다른 입력이 없다.
final class LoggedOutInteractor: PresentableInteractor<any LoggedOutPresentable>, LoggedOutPresentableListener {
    private let authService: any AuthService
    private weak var listener: (any LoggedOutListener)?
    private var viewState: LoggedOutViewState

    init(
        presenter: any LoggedOutPresentable,
        authService: any AuthService,
        listener: any LoggedOutListener,
        notice: LoggedOutViewState.Notice?
    ) {
        self.authService = authService
        self.listener = listener
        self.viewState = LoggedOutViewState(notice: notice)
        super.init(presenter: presenter)
    }

    override func didBecomeActive() {
        presenter.listener = self
        presenter.render(viewState)
    }

    override func willResignActive() {
        presenter.listener = nil
    }

    func handle(_ action: LoggedOutViewAction) {
        switch action {
        case .signInTapped(let provider): signIn(provider)
        }
    }

    private func signIn(_ provider: AuthProvider) {
        guard !viewState.isSigningIn else { return }
        update(LoggedOutViewState(isSigningIn: true))
        startTask { [weak self] in
            guard let self else { return }
            let result = await authService.signIn(provider)
            // 비활성화로 취소됐다. 뷰는 이미 떨어졌다.
            guard !Task.isCancelled else { return }
            switch result {
            case .success:
                update(LoggedOutViewState())
                listener?.didSignIn()
            case .cancelled:
                update(LoggedOutViewState(notice: .cancelled))
            case .failed(let reason):
                update(LoggedOutViewState(notice: .failed(reason)))
            }
        }
    }

    /// 상태가 바뀌었을 때만 한 번 그린다.
    private func update(_ next: LoggedOutViewState) {
        guard next != viewState else { return }
        viewState = next
        presenter.render(next)
    }
}

typealias LoggedOutRouter = ViewableRouter<LoggedOutInteractor, any LoggedOutViewControllable>
