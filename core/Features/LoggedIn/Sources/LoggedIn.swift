#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FeatureLoggedInInterface
import GrepCore
import RIBs

public final class LoggedInBuilder: Builder<any LoggedInDependency>, LoggedInBuildable {
    private let viewFactory: any LoggedInViewFactory

    public init(dependency: any LoggedInDependency, viewFactory: any LoggedInViewFactory) {
        self.viewFactory = viewFactory
        super.init(dependency: dependency)
    }

    public func build(listener: any LoggedInListener, pendingInput: PendingInput?) -> any ViewableRouting {
        let view = viewFactory.makeLoggedInView()
        let interactor = LoggedInInteractor(
            presenter: view,
            authService: dependency.authService,
            httpTransport: dependency.httpTransport,
            listener: listener,
            pendingInput: pendingInput
        )
        return LoggedInRouter(interactor: interactor, viewController: view)
    }
}

/// 터미널 화면. 붙으면 `GET /me`로 자료 수를 받고, 입력줄의 명령을 해석한다.
/// #31에서 아는 명령은 로그아웃뿐이다. 나머지는 없는 명령으로 그린다.
final class LoggedInInteractor: PresentableInteractor<any LoggedInPresentable>, LoggedInPresentableListener {

    private let authService: any AuthService
    private let httpTransport: any HTTPTransport
    private weak var listener: (any LoggedInListener)?
    private var viewState = LoggedInViewState()
    private var isSigningOut = false
    /// 만료 전에 치던 줄. 접근 토큰의 계정이 같을 때만 되살리고, 토큰을 받으면 비운다.
    private var pendingInput: PendingInput?
    /// 지금 로그인한 계정(접근 토큰의 `sub`). 토큰을 받기 전이거나 읽지 못하면 nil.
    private var subject: String?
    /// 실패해 입력줄에 되돌린 저장 줄과 그때의 멱등성 키. 같은 줄을 다시 치면 같은 키로 보낸다.
    /// 응답 없음 뒤 서버가 이미 저장했어도 두 번 만들지 않는다(글은 COM-001 판정이 없다).
    private var retryableSave: (typed: String, key: UUID)?

    init(
        presenter: any LoggedInPresentable,
        authService: any AuthService,
        httpTransport: any HTTPTransport,
        listener: any LoggedInListener,
        pendingInput: PendingInput?
    ) {
        self.authService = authService
        self.httpTransport = httpTransport
        self.listener = listener
        self.pendingInput = pendingInput
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
        // 붙여 넣기 저장(#57), 끌어다 놓기(#57), 더 보기(#60·#61)는 각 실행 이슈에서 채운다.
        case .pasted, .filesDropped, .moreRequested: break
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
            restorePendingInput(for: token)
            let outcome = await MeAPI.load(transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .loaded(let itemCount): update(viewState.with(itemCount: itemCount))
            case .sessionExpired: expire()
            case .failed, .cancelled: break
            }
        }
    }

    /// 같은 계정으로 다시 로그인했으면 만료 전에 치던 줄을 되살린다(ACC-001 규칙 7, COM-009 규칙 4).
    /// 다른 계정이면 버린다(COM-009 규칙 3). 사용자가 그새 친 글이 있으면 덮어쓰지 않는다.
    private func restorePendingInput(for token: String) {
        subject = AccessTokenSubject.read(from: token)
        defer { pendingInput = nil }
        guard let pendingInput, let subject, pendingInput.subject == subject, viewState.input.isEmpty else { return }
        update(viewState.with(input: pendingInput.text))
    }

    /// 치던 줄을 들려 부모에게 보낸다. 부모가 로그인 화면으로 바꾼다(ACC-001 규칙 7).
    /// 계정을 모르면(토큰을 못 받음) 받아 둔 되살릴 줄을 그대로 돌려준다.
    /// 로그아웃 중이면 알리지 않는다. 사용자가 끝낸 세션을 만료로 보이지 않게 한다.
    private func expire() {
        guard !isSigningOut else { return }
        guard let subject else {
            listener?.didExpire(pendingInput: pendingInput)
            return
        }
        let text = viewState.input
        listener?.didExpire(pendingInput: text.isEmpty ? nil : PendingInput(text: text, subject: subject))
    }

    private func submit(_ text: String) {
        guard let command = InputCommand(text) else { return }
        switch command.name {
        case .signOut where command.argument.isEmpty:
            signOut()
        case .keep where command.argument.isEmpty:
            update(viewState.appending(lines: [.prompt(text), .missingArgument(.keep)]).with(input: ""))
        case .keep:
            keep(KeepCommand.request(for: command.argument), typed: text)
        default:
            update(viewState.appending(lines: [.prompt(text), .unknownCommand(command.word)]).with(input: ""))
        }
    }

    /// 저장 요청. 친 줄은 바로 찍고 입력줄을 비운다. 실패하면 친 줄을 입력줄에 되돌린다(ARC-005 규칙 2).
    private func keep(_ request: ItemsAPI.SaveRequest, typed: String) {
        update(viewState.appending(lines: [.prompt(typed)]).with(input: ""))
        let key = retryableSave.flatMap { $0.typed == typed ? $0.key : nil } ?? UUID()
        retryableSave = nil
        startTask { [weak self] in
            guard let self else { return }
            let token = await authService.accessToken()
            guard !Task.isCancelled else { return }
            guard let token else {
                restoreInput(typed)
                expire()
                return
            }
            let outcome = await ItemsAPI.save(
                request, transport: httpTransport, accessToken: token, idempotencyKey: key
            )
            guard !Task.isCancelled else { return }
            switch outcome {
            case .saved(let item):
                // shortcut: /me 응답과 순서가 엇갈리면 한 건 어긋날 수 있다. 상태줄 갱신을 정하는 #60에서 맞춘다.
                update(viewState.appending(lines: [.saved(item)]).with(itemCount: viewState.itemCount.map { $0 + 1 }))
            case .duplicate(let item):
                update(viewState.appending(lines: [.alreadySaved(item)]))
            case .inTrash(let item):
                update(viewState.appending(lines: [.inTrash(number: item.number)]))
            case .failed(let reason):
                update(viewState.appending(lines: [.saveFailed(reason)]))
                retryableSave = (typed, key)
                restoreInput(typed)
            case .sessionExpired:
                restoreInput(typed)
                expire()
            case .cancelled:
                break
            }
        }
    }

    /// 사용자가 그새 다른 글을 치고 있으면 덮어쓰지 않는다.
    private func restoreInput(_ text: String) {
        guard viewState.input.isEmpty else { return }
        update(viewState.with(input: text))
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
        var next = self
        next.input = input
        return next
    }

    fileprivate func with(itemCount: Int?) -> LoggedInViewState {
        var next = self
        next.itemCount = itemCount
        return next
    }

    fileprivate func appending(lines added: [Line]) -> LoggedInViewState {
        var next = self
        next.lines += added
        return next
    }
}

typealias LoggedInRouter = ViewableRouter<LoggedInInteractor, any LoggedInViewControllable>
