import FeatureLoggedInInterface
import GrepCore
import RIBs

public final class LoggedInBuilder: Builder<any LoggedInDependency>, LoggedInBuildable {
    private let viewFactory: any LoggedInViewFactory

    public init(dependency: any LoggedInDependency, viewFactory: any LoggedInViewFactory) {
        self.viewFactory = viewFactory
        super.init(dependency: dependency)
    }

    public func build(listener: any LoggedInListener, restoredInput: String) -> any ViewableRouting {
        let view = viewFactory.makeLoggedInView()
        let interactor = LoggedInInteractor(
            presenter: view,
            authService: dependency.authService,
            httpTransport: dependency.httpTransport,
            listener: listener,
            restoredInput: restoredInput
        )
        return LoggedInRouter(interactor: interactor, viewController: view)
    }
}

/// 터미널 화면. 붙으면 `GET /me`로 자료 수를 받고, 입력줄의 명령을 해석한다.
/// #31에서 아는 명령은 로그아웃뿐이다. 나머지는 없는 명령으로 그린다.
final class LoggedInInteractor: PresentableInteractor<any LoggedInPresentable>, LoggedInPresentableListener {
    /// ACC-001 값 "로그아웃 명령". `login`·`logout`은 받지 않는다.
    static let signOutCommands: Set<String> = ["로그아웃", "signout"]

    private let authService: any AuthService
    private let httpTransport: any HTTPTransport
    private weak var listener: (any LoggedInListener)?
    private var viewState: LoggedInViewState
    private var isSigningOut = false

    init(
        presenter: any LoggedInPresentable,
        authService: any AuthService,
        httpTransport: any HTTPTransport,
        listener: any LoggedInListener,
        restoredInput: String
    ) {
        self.authService = authService
        self.httpTransport = httpTransport
        self.listener = listener
        self.viewState = LoggedInViewState(input: restoredInput)
        super.init(presenter: presenter)
    }

    override func didBecomeActive() {
        presenter.listener = self
        presenter.render(viewState)
        loadMe()
    }

    override func willResignActive() {
        presenter.listener = nil
    }

    func handle(_ action: LoggedInViewAction) {
        switch action {
        case .inputChanged(let text): update(viewState.with(input: text))
        case .submitted(let text): submit(text)
        }
    }

    private func loadMe() {
        startTask { [weak self] in
            guard let self else { return }
            let token = await authService.accessToken()
            // 비활성화로 취소됐으면 뷰가 이미 떨어졌다. 늦게 온 답을 그리지 않는다.
            guard !Task.isCancelled else { return }
            guard let token else {
                expire()
                return
            }
            let outcome = await MeAPI.load(transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .loaded(let itemCount): update(viewState.with(itemCount: itemCount))
            case .sessionExpired: expire()
            case .failed, .cancelled: break
            }
        }
    }

    /// 치던 줄을 들려 부모에게 보낸다. 부모가 로그인 화면으로 바꾼다(ACC-001 규칙 7).
    /// 로그아웃 중이면 알리지 않는다. 사용자가 끝낸 세션을 만료로 보이지 않게 한다.
    private func expire() {
        guard !isSigningOut else { return }
        listener?.didExpire(pendingInput: viewState.input)
    }

    private func submit(_ text: String) {
        let words = text.split(whereSeparator: \.isWhitespace)
        guard let name = words.first.map(String.init) else { return }
        if words.count == 1, Self.signOutCommands.contains(name) {
            signOut()
        } else {
            update(viewState.appending(lines: [.prompt(text), .unknownCommand(name)]).with(input: ""))
        }
    }

    private func signOut() {
        guard !isSigningOut else { return }
        isSigningOut = true
        startTask { [weak self] in
            guard let self else { return }
            await authService.signOut()
            guard !Task.isCancelled else { return }
            listener?.didSignOut()
        }
    }

    /// 상태가 바뀌었을 때만 한 번 그린다.
    private func update(_ next: LoggedInViewState) {
        guard next != viewState else { return }
        viewState = next
        presenter.render(next)
    }
}

extension LoggedInViewState {
    fileprivate func with(input: String) -> LoggedInViewState {
        LoggedInViewState(itemCount: itemCount, lines: lines, input: input)
    }

    fileprivate func with(itemCount: Int) -> LoggedInViewState {
        LoggedInViewState(itemCount: itemCount, lines: lines, input: input)
    }

    fileprivate func appending(lines added: [Line]) -> LoggedInViewState {
        LoggedInViewState(itemCount: itemCount, lines: lines + added, input: input)
    }
}

typealias LoggedInRouter = ViewableRouter<LoggedInInteractor, any LoggedInViewControllable>
