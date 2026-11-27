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
            files: dependency.files,
            sleeper: dependency.sleeper,
            listener: listener,
            pendingInput: pendingInput
        )
        return LoggedInRouter(interactor: interactor, viewController: view)
    }
}

/// 터미널 화면. 붙으면 `GET /me`로 자료 수를 받고, 입력줄의 명령을 해석한다.
/// 아는 명령은 `담기`·`최근`·`로그아웃`이다. 붙여 넣기와 끌어다 놓기도 저장한다(#57). 나머지는 없는 명령으로 그린다.
/// 처리 중 자료가 화면에 있으면 2초마다 상태를 묻고(ARC-005 규칙 10), 서버에 닿지 못하면 5초마다 다시 확인한다(COM-010).
final class LoggedInInteractor: PresentableInteractor<any LoggedInPresentable>, LoggedInPresentableListener {

    private let authService: any AuthService
    /// ARC-005 규칙 10의 폴링 주기(08 6절 13번).
    private static let pollInterval: Duration = .seconds(2)
    /// COM-010의 다시 연결 확인 주기(08 6절 14번).
    private static let healthInterval: Duration = .seconds(5)

    /// `더 보기`가 이어 붙일 목록 줄과 다음 쪽을 받는 값.
    private struct RecentPage: Equatable {
        let lineIndex: Int
        let cursor: String
        let limit: Int
        /// 그 목록을 만든 명령. 다음 쪽이 실패하면 `→ 다시`에 쓴다.
        let typed: String
    }

    private let httpTransport: ObservedTransport
    private let files: any FilePort
    private let sleeper: any Sleeper
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
    /// 마지막 `최근` 목록에 다음 쪽이 있을 때만 있다.
    private var recentPage: RecentPage?
    private var isLoadingMore = false
    private var isPolling = false
    private var isCheckingHealth = false
    /// 폴링에서 없는 번호(휴지통·삭제)로 온 자료. 더 묻지 않는다.
    private var goneNumbers: Set<Int> = []

    init(
        presenter: any LoggedInPresentable,
        authService: any AuthService,
        httpTransport: any HTTPTransport,
        files: any FilePort,
        sleeper: any Sleeper,
        listener: any LoggedInListener,
        pendingInput: PendingInput?
    ) {
        self.authService = authService
        self.httpTransport = ObservedTransport(base: httpTransport)
        self.files = files
        self.sleeper = sleeper
        self.listener = listener
        self.pendingInput = pendingInput
        super.init(presenter: presenter)
    }

    override func didBecomeActive() {
        presenter.listener = self
        httpTransport.onReachabilityObserved = { [weak self] in self?.observeReachability($0) }
        presenter.render(viewState)
        loadMe()
    }

    override func willResignActive() {
        presenter.listener = nil
        httpTransport.onReachabilityObserved = nil
    }

    func handle(_ action: LoggedInViewAction) {
        switch action {
        case .inputChanged(let text): update(viewState.with(input: text))
        case .submitted(let text): submit(text)
        case .pasted(let text): paste(text)
        case .filesDropped(let dropped): drop(dropped)
        // shortcut: 찾기 결과의 더 보기는 #61에서 더한다.
        case .moreRequested: loadMoreRecent()
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
        case .recent:
            showRecent(limit: RecentCommand.limit(for: command.argument), typed: text)
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
            case .saved, .duplicate, .inTrash:
                showStored(outcome)
            case .failed(let reason):
                // 그새 친 글이 있으면 입력줄을 덮지 않고 다시 칠 명령을 보인다(#57 사용자 결정).
                let recovery: SaveRecovery = viewState.input.isEmpty ? .inputKept : .retry(typed)
                update(viewState.appending(lines: [.saveFailed(reason, recovery)]))
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

    /// 붙여 넣은 링크·글은 `담기 <붙인 것>`을 친 것과 같다(user-flow 3절 1단계). 줄바꿈은 살린다.
    private func paste(_ text: String) {
        let content = text.trimmingWhitespace()
        guard !content.isEmpty else { return }
        keep(KeepCommand.request(for: content), typed: "담기 \(content)")
    }

    /// 끌어다 놓은 파일을 하나씩 저장한다. 한 파일이 실패해도 나머지는 저장한다(COM-004 규칙 3·8).
    /// 원본은 사용자 기기에 있으니 입력줄에 되돌릴 것은 없다. 다 쓴 파일은 바로 놓는다.
    /// shortcut: `GET /uploads/limits`로 보내기 전에 거르지 않고 서버 판정(413·415)만 쓴다. 큰 파일을 올리기 전에 막아야 할 때 더한다.
    private func drop(_ dropped: [DroppedFile]) {
        guard !dropped.isEmpty else { return }
        update(viewState.appending(lines: [.prompt((["담기"] + dropped.map(\.name)).joined(separator: " "))]))
        startTask { [weak self] in
            guard let self else { return }
            var remaining = dropped[...]
            defer { remaining.forEach { self.files.release($0.id) } }
            let token = await authService.accessToken()
            guard !Task.isCancelled else { return }
            guard let token else {
                expire()
                return
            }
            while let file = remaining.popFirst() {
                let outcome = await saveFile(file, accessToken: token)
                files.release(file.id)
                guard !Task.isCancelled else { return }
                switch outcome {
                case .saved, .duplicate, .inTrash:
                    showStored(outcome)
                case .failed(let reason):
                    update(viewState.appending(lines: [.saveFailed(reason, .file(name: file.name))]))
                case .sessionExpired:
                    expire()
                    return
                case .cancelled:
                    return
                }
            }
        }
    }

    /// 업로드 자리 받기 → 서명 URL로 올리기 → `POST /items {kind: file}`(api/openapi.yaml `createUpload`).
    private func saveFile(_ file: DroppedFile, accessToken: String) async -> ItemsAPI.SaveOutcome {
        let upload = await ItemsAPI.createUpload(
            fileName: file.name, size: file.size, transport: httpTransport, accessToken: accessToken
        )
        let uploadID: String
        switch upload {
        case .created(let id, let url):
            do {
                try await files.upload(file.id, to: url)
            } catch {
                return Self.outcome(of: error)
            }
            uploadID = id
        case .sessionExpired: return .sessionExpired
        case .failed(let reason): return .failed(reason)
        case .cancelled: return .cancelled
        }
        guard !Task.isCancelled else { return .cancelled }
        return await ItemsAPI.save(
            .file(uploadID: uploadID), transport: httpTransport, accessToken: accessToken, idempotencyKey: UUID()
        )
    }

    private static func outcome(of error: FileUploadError) -> ItemsAPI.SaveOutcome {
        switch error {
        case .cancelled: .cancelled
        case .unreachable: .failed(.disconnected)
        case .timedOut: .failed(.timedOut)
        case .rejected, .missingFile: .failed(.serverError)
        }
    }

    /// 서버가 자료를 가진 결과(새로 저장, 이미 있음, 휴지통에 있음)를 줄로 찍는다.
    private func showStored(_ outcome: ItemsAPI.SaveOutcome) {
        switch outcome {
        case .saved(let item):
            // shortcut: /me 응답과 순서가 엇갈리면 한 건 어긋날 수 있다. 상태줄 갱신을 정하는 #60에서 맞춘다.
            update(viewState.appending(lines: [.saved(item)]).with(itemCount: viewState.itemCount.map { $0 + 1 }))
        case .duplicate(let item):
            update(viewState.appending(lines: [.alreadySaved(item)]))
        case .inTrash(let item):
            update(viewState.appending(lines: [.inTrash(number: item.number)]))
        case .failed, .sessionExpired, .cancelled:
            break
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

    // MARK: 최근과 더 보기

    /// `GET /items`. 친 줄은 바로 찍는다. 실패하면 `✗ 최근 안 됨`과 다시 칠 명령을 보인다(COM-010 규칙 1).
    private func showRecent(limit: Int, typed: String) {
        update(viewState.appending(lines: [.prompt(typed)]).with(input: ""))
        startTask { [weak self] in
            guard let self else { return }
            let token = await authService.accessToken()
            guard !Task.isCancelled else { return }
            guard let token else {
                restoreInput(typed)
                expire()
                return
            }
            let outcome = await BrowseAPI.recent(
                limit: limit, cursor: nil, transport: httpTransport, accessToken: token
            )
            guard !Task.isCancelled else { return }
            switch outcome {
            case .page(let items, let nextCursor):
                // `→ 더 보기`는 마지막 목록에만 둔다. 앞 목록의 것은 뺀다.
                let closed = recentPage.map { viewState.closingRecentList(at: $0.lineIndex) } ?? viewState
                update(closed.appending(lines: [.recentList(items: items, hasMore: nextCursor != nil)]))
                recentPage = nextCursor.map {
                    RecentPage(lineIndex: viewState.lines.count - 1, cursor: $0, limit: limit, typed: typed)
                }
            case .failed(let reason):
                update(viewState.appending(lines: [.commandFailed(command: .recent, reason: reason, retry: typed)]))
            case .sessionExpired:
                restoreInput(typed)
                expire()
            case .cancelled:
                break
            }
        }
    }

    /// 마지막 목록에 다음 쪽을 이어 붙인다. 받는 중에 또 누르면 무시한다.
    private func loadMoreRecent() {
        guard let page = recentPage, !isLoadingMore else { return }
        isLoadingMore = true
        startTask { [weak self] in
            guard let self else { return }
            defer { isLoadingMore = false }
            let token = await authService.accessToken()
            guard !Task.isCancelled else { return }
            guard let token else {
                expire()
                return
            }
            let outcome = await BrowseAPI.recent(
                limit: page.limit, cursor: page.cursor, transport: httpTransport, accessToken: token
            )
            // 기다리는 동안 `최근`을 다시 쳐 목록이 바뀌었으면 늦게 온 쪽을 버린다.
            guard !Task.isCancelled, recentPage == page else { return }
            switch outcome {
            case .page(let items, let nextCursor):
                recentPage = nextCursor.map {
                    RecentPage(lineIndex: page.lineIndex, cursor: $0, limit: page.limit, typed: page.typed)
                }
                update(viewState.extendingRecentList(at: page.lineIndex, with: items, hasMore: nextCursor != nil))
            case .failed(let reason):
                update(viewState.appending(lines: [.commandFailed(command: .recent, reason: reason, retry: page.typed)]))
            case .sessionExpired:
                expire()
            case .cancelled:
                break
            }
        }
    }

    // MARK: 처리 중 자료 폴링(ARC-005 규칙 10)

    /// 처리 중 자료가 화면에 있는 동안만 돈다. 실패해도 줄을 찍지 않고 다음 주기에 다시 묻는다.
    private func startPollingIfNeeded() {
        guard !isPolling, viewState.processingCount > 0 else { return }
        isPolling = true
        startTask { [weak self] in
            guard let self else { return }
            defer { isPolling = false }
            while true {
                await sleeper.sleep(for: Self.pollInterval)
                guard !Task.isCancelled else { return }
                let numbers = viewState.processingNumbers(excluding: goneNumbers)
                guard !numbers.isEmpty else { return }
                // 끊겨 있으면 묻지 않는다. 다시 연결됐는지는 `/health`가 본다.
                guard !viewState.isOffline else { continue }
                guard await refreshStatuses(of: numbers) else { return }
            }
        }
    }

    /// 계속 폴링해도 되면 true. 만료나 취소면 false.
    private func refreshStatuses(of numbers: [Int]) async -> Bool {
        let token = await authService.accessToken()
        guard !Task.isCancelled else { return false }
        guard let token else {
            expire()
            return false
        }
        let outcome = await BrowseAPI.statuses(of: numbers, transport: httpTransport, accessToken: token)
        guard !Task.isCancelled else { return false }
        switch outcome {
        case .found(let items, let missing):
            goneNumbers.formUnion(missing)
            update(viewState.replacingItems(with: items))
            return true
        case .failed:
            return true
        case .sessionExpired:
            expire()
            return false
        case .cancelled:
            return false
        }
    }

    // MARK: 연결 끊김과 다시 연결(COM-010)

    /// 네트워크 오류면 `연결 끊김` 칸을 두고, 그 뒤 처음 서버에 닿으면 `✓ 연결됨`을 한 줄 찍는다.
    /// 끊긴 동안 친 명령은 다시 하지 않는다(규칙 5).
    private func observeReachability(_ isReachable: Bool) {
        guard isReachable == viewState.isOffline else { return }
        if isReachable {
            update(viewState.with(isOffline: false).appending(lines: [.reconnected]))
        } else {
            update(viewState.with(isOffline: true))
            startHealthCheck()
        }
    }

    /// 끊겨 있는 동안 5초마다 `/health`를 부른다. 답이 오면 `observeReachability`가 끊김을 푼다.
    private func startHealthCheck() {
        guard !isCheckingHealth else { return }
        isCheckingHealth = true
        startTask { [weak self] in
            guard let self else { return }
            defer { isCheckingHealth = false }
            while viewState.isOffline {
                await sleeper.sleep(for: Self.healthInterval)
                guard !Task.isCancelled, viewState.isOffline else { return }
                await BrowseAPI.checkHealth(transport: httpTransport)
                guard !Task.isCancelled else { return }
            }
        }
    }

    /// 상태가 바뀌었을 때만 한 번 그린다. 처리 중 건수는 화면 줄에서 다시 센다.
    private func update(_ next: LoggedInViewState) {
        let counted = next.with(processingCount: next.processingNumbers(excluding: goneNumbers).count)
        guard counted != viewState else { return }
        viewState = counted
        presenter.render(counted)
        startPollingIfNeeded()
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

    fileprivate func with(processingCount: Int) -> LoggedInViewState {
        var next = self
        next.processingCount = processingCount
        return next
    }

    fileprivate func with(isOffline: Bool) -> LoggedInViewState {
        var next = self
        next.isOffline = isOffline
        return next
    }

    fileprivate func appending(lines added: [Line]) -> LoggedInViewState {
        var next = self
        next.lines += added
        return next
    }
}

typealias LoggedInRouter = ViewableRouter<LoggedInInteractor, any LoggedInViewControllable>
