#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FeatureTerminalInterface
import GrepCore
import RIBs

public final class TerminalBuilder: Builder<any TerminalDependency>, TerminalBuildable {
    private let viewFactory: any TerminalViewFactory

    public init(dependency: any TerminalDependency, viewFactory: any TerminalViewFactory) {
        self.viewFactory = viewFactory
        super.init(dependency: dependency)
    }

    public func build(listener: any TerminalListener) -> TerminalBuild {
        let view = viewFactory.makeTerminalView()
        let interactor = TerminalInteractor(
            presenter: view,
            authService: dependency.authService,
            httpTransport: dependency.httpTransport,
            clipboard: dependency.clipboard,
            files: dependency.files,
            historyStore: dependency.historyStore,
            sleeper: dependency.sleeper,
            listener: listener
        )
        return TerminalBuild(router: TerminalRouter(interactor: interactor, viewController: view), handle: interactor)
    }
}

/// 터미널 화면. 입력줄의 명령을 해석한다. 자료 수와 되살릴 줄은 부모가 `TerminalHandle`로 넘긴다.
/// 아는 명령은 `담기`·`최근`·`찾기`·`고르기`·`넘기기`·`도움말`·`설명`·`로그아웃`이다. 붙여 넣기와 끌어다 놓기도 저장한다(#57). 나머지는 없는 명령으로 그린다.
/// 처리 중 자료가 화면에 있으면 2초마다 상태를 묻고(ARC-005 규칙 10), 서버에 닿지 못하면 5초마다 다시 확인한다(COM-010).
final class TerminalInteractor: PresentableInteractor<any TerminalPresentable>, TerminalPresentableListener, TerminalHandle {

    let authService: any AuthService
    /// ARC-005 규칙 10의 폴링 주기(08 6절 13번).
    private static let pollInterval: Duration = .seconds(2)
    /// COM-010의 다시 연결 확인 주기(08 6절 14번).
    private static let healthInterval: Duration = .seconds(5)

    /// `더 보기`가 이어 붙일 목록 줄과 다음 쪽을 받는 값.
    struct ListPage: Equatable {
        enum Source: Equatable {
            case recent(limit: Int, period: Period?)
            case search(SearchQuery, period: Period?)
            case bin
        }

        let lineIndex: Int
        let cursor: String
        let source: Source
        /// 그 목록을 만든 명령. 다음 쪽이 실패하면 `→ 다시`에 쓴다(COM-010 규칙 7).
        let typed: String

        var command: CommandName {
            switch source {
            case .recent: .recent
            case .search: .seek
            case .bin: .bin
            }
        }
    }

    let rawTransport: any HTTPTransport
    let httpTransport: ObservedTransport
    let clipboard: any ClipboardPort
    private let files: any FilePort
    let historyStore: any HistoryStore
    private let sleeper: any Sleeper
    private weak var listener: (any TerminalListener)?
    private(set) var viewState = TerminalViewState()
    /// 실패해 입력줄에 되돌린 저장 줄과 그때의 멱등성 키. 같은 줄을 다시 치면 같은 키로 보낸다.
    /// 응답 없음 뒤 서버가 이미 저장했어도 두 번 만들지 않는다(글은 COM-001 판정이 없다).
    private var retryableSave: (typed: String, key: UUID)?
    /// 마지막 목록(`최근`·찾기 결과)에 다음 쪽이 있을 때만 있다.
    private var listPage: ListPage?
    /// 다음 쪽을 받고 있는 목록. 그 목록의 `더 보기`만 무시한다.
    private var loadingPage: ListPage?
    /// 답을 기다리는 `찾기 … | 넘기기` 확인. 다음 입력 한 번이 답이다(COM-007 규칙 1).
    var pendingHandoff: PendingHandoff?
    /// 답을 기다리는 `버리기` 2건 이상 확인(ARC-008 규칙 1, COM-007).
    var pendingDrop: PendingDrop?
    /// 답을 기다리는 `휴지통 비우기` 확인(ARC-008 규칙 6, COM-007).
    var pendingBinEmpty: PendingBinEmpty?
    /// 답을 기다리는 `로그아웃 모든기기` 확인(ACC-002 규칙 4, COM-007).
    var pendingSignOutEverywhere = false
    /// 오타 제안(#118, commands.md 207줄). 빈 입력 엔터면 이 문자열을 실행하고, 다른 입력이면 지운다.
    var pendingSuggestion: String?
    /// `POST /samples` 중복 실행 방지.
    var isSavingSamples = false
    /// 사용자가 넣은 입력(엔터·붙여 넣기·파일 놓기)의 차례. 늦게 온 응답이 그 뒤의 입력을 답으로 삼지 않게 한다.
    private(set) var inputSequence = 0
    /// `로그아웃`으로 기록을 지웠다. 늦게 끝난 되살리기가 다시 남기지 않게 한다.
    var isHistoryForgotten = false
    /// 기록을 남길 계정(접근 토큰의 `sub`). 알기 전과 로그아웃 뒤에는 nil이라 남기지 않는다(COM-009).
    var historySubject: String?
    /// 남긴 기록을 읽었는지. 읽기 전에는 첫 화면을 정하지 않는다.
    var isHistoryLoaded = false
    /// 마지막으로 남긴 줄과 그 JSON.
    var encodedLines: (lines: [TerminalViewState.Line], json: String)?
    private var isPolling = false
    private var isCheckingHealth = false
    /// 폴링에서 없는 번호(휴지통·삭제)로 온 자료. 더 묻지 않는다.
    private var goneNumbers: Set<Int> = []

    init(
        presenter: any TerminalPresentable,
        authService: any AuthService,
        httpTransport: any HTTPTransport,
        clipboard: any ClipboardPort,
        files: any FilePort,
        historyStore: any HistoryStore,
        sleeper: any Sleeper,
        listener: any TerminalListener
    ) {
        self.authService = authService
        self.rawTransport = httpTransport
        self.httpTransport = ObservedTransport(base: httpTransport)
        self.clipboard = clipboard
        self.files = files
        self.historyStore = historyStore
        self.sleeper = sleeper
        self.listener = listener
        super.init(presenter: presenter)
    }

    override func didBecomeActive() {
        presenter.listener = self
        httpTransport.onReachabilityObserved = { [weak self] in self?.observeReachability($0) }
        presenter.render(viewState)
        restoreHistory()
    }

    override func willResignActive() {
        presenter.listener = nil
        httpTransport.onReachabilityObserved = nil
    }

    func handle(_ action: TerminalViewAction) {
        switch action {
        case .inputChanged(let text): update(viewState.with(input: text))
        case .submitted(let text): submit(text)
        case .pasted(let text): paste(text)
        case .filesDropped(let dropped): drop(dropped)
        case .moreRequested: loadMore()
        case .samplesRequested: saveSamples()
        case .reviseSubmitted(let number, let title, let summary):
            submitRevise(number: number, title: title, summary: summary)
        case .reviseCancelled:
            cancelRevise()
        }
    }

    // MARK: TerminalHandle

    var input: String { viewState.input }

    func showItemCount(_ itemCount: Int) {
        update(viewState.with(itemCount: itemCount))
        showWelcomeIfNeeded()
    }

    /// 서버가 세션 만료로 답했거나 토큰을 받지 못했다. 치던 줄을 들려 부모에게 알린다(ACC-001 규칙 7).
    func expire() {
        listener?.didExpire(input: viewState.input)
    }

    /// 친 줄을 찍고 입력줄을 비운 뒤 접근 토큰으로 `request`를 돌린다.
    /// 토큰을 받지 못하면 친 줄을 입력줄에 되돌리고 만료를 알린다.
    func run(typed: String, _ request: @escaping @MainActor (_ accessToken: String) async -> Void) {
        update(viewState.appending(lines: [.prompt(typed)]).with(input: ""))
        startTask { [weak self] in
            guard let self else { return }
            let token = await authService.accessToken()
            guard !Task.isCancelled else { return }
            guard let token else {
                expire(restoring: typed)
                return
            }
            await request(token)
        }
    }

    /// 세션이 만료됐다. 친 줄을 입력줄에 되돌리고 부모에게 알린다.
    func expire(restoring typed: String) {
        restoreInput(typed)
        expire()
    }

    private func submit(_ text: String) {
        inputSequence += 1
        if text.trimmingWhitespace().isEmpty, let suggested = pendingSuggestion {
            pendingSuggestion = nil
            submit(suggested)
            return
        }
        pendingSuggestion = nil
        if let pending = pendingHandoff, let choice = pending.choice(for: text) {
            pendingHandoff = nil
            confirmHandoff(pending, choice: choice, typed: text)
            return
        }
        if let pending = pendingDrop, pending.matches(text) {
            pendingDrop = nil
            confirmDrop(pending, typed: text)
            return
        }
        if let pending = pendingBinEmpty, pending.matches(text) {
            pendingBinEmpty = nil
            confirmBinEmpty(typed: text)
            return
        }
        if pendingSignOutEverywhere {
            let answer = text.trimmingWhitespace()
            if answer == "로그아웃" || answer == "signout" {
                pendingSignOutEverywhere = false
                forgetHistory()
                listener?.didRequestSignOutEverywhere()
                return
            }
        }
        cancelPendingConfirmations()
        guard let command = InputCommand(text) else { return }
        switch command.name {
        case .signOut where command.argument.isEmpty:
            forgetHistory()
            listener?.didRequestSignOut()
        case .signOut where command.argument == "모든기기" || command.argument == "all":
            pendingSignOutEverywhere = true
            update(viewState.appending(lines: [.prompt(text), .signOutEverywhereConfirm]).with(input: ""))
        case .keep where command.argument.isEmpty:
            update(viewState.appending(lines: [.prompt(text), .missingArgument(.keep)]).with(input: ""))
        case .keep:
            keep(KeepCommand.request(for: command.argument), typed: text)
        case .recent:
            let parsed = RecentCommand.parse(command.argument)
            showRecent(limit: parsed.limit, period: parsed.period, typed: text)
        case .seek where pipe(seekArgument: command.argument, typed: text):
            break
        case .seek:
            seek(SeekCommand.parse(command.argument), typed: text)
        case .pick:
            pick(PickCommand.parse(command.argument), typed: text)
        case .drop:
            dropItems(command.argument, typed: text)
        case .revive:
            reviveItems(command.argument, typed: text)
        case .bin:
            handleBin(command.argument, typed: text)
        case .revise:
            reviseItem(command.argument, typed: text)
        case .guide:
            update(viewState.appending(lines: [.prompt(text), .guide]).with(input: ""))
        case .about:
            update(viewState.appending(lines: [.prompt(text), aboutLine(for: command.argument)]).with(input: ""))
        case .handoff where command.argument.isEmpty:
            handOffSelection(typed: text)
        // shortcut: `넘기기 <묶음 이름>`(F12)은 묶음이 데모 범위 밖이라 받지 않는다. 고른 자료를 대신 넘기지 않도록 없는 명령으로 알린다.
        case .handoff:
            update(viewState.appending(lines: [.prompt(text), .unknownCommand(text.trimmingWhitespace())]).with(input: ""))
        default:
            let suggestion = CommandSuggester.suggest(word: command.word, argument: command.argument)
            pendingSuggestion = suggestion
            update(viewState.appending(lines: [.prompt(text), .unknownCommand(command.word, suggestion: suggestion)]).with(input: ""))
        }
    }

    /// `설명 <명령>`(commands 3절). 한글·영문 이름을 모두 받는다.
    private func aboutLine(for argument: String) -> TerminalViewState.Line {
        guard !argument.isEmpty else { return .missingArgument(.about) }
        return InputCommand.name(for: argument).map { .about($0) } ?? .unknownCommand(argument)
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
        inputSequence += 1
        cancelPendingConfirmations()
        keep(KeepCommand.request(for: content), typed: "담기 \(content)")
    }

    /// 끌어다 놓은 파일을 하나씩 저장한다. 한 파일이 실패해도 나머지는 저장한다(COM-004 규칙 3·8).
    /// 원본은 사용자 기기에 있으니 입력줄에 되돌릴 것은 없다. 다 쓴 파일은 바로 놓는다.
    /// shortcut: `GET /uploads/limits`로 보내기 전에 거르지 않고 서버 판정(413·415)만 쓴다. 큰 파일을 올리기 전에 막아야 할 때 더한다.
    private func drop(_ dropped: [DroppedFile]) {
        guard !dropped.isEmpty else { return }
        inputSequence += 1
        cancelPendingConfirmations()
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
    func restoreInput(_ text: String) {
        guard viewState.input.isEmpty else { return }
        update(viewState.with(input: text))
    }

    // MARK: 최근과 더 보기

    /// `GET /items`. 친 줄은 바로 찍는다. 실패하면 `✗ 최근 안 됨`과 다시 칠 명령을 보인다(COM-010 규칙 1).
    private func showRecent(limit: Int, period: Period?, typed: String) {
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
                limit: limit, cursor: nil, period: period, transport: httpTransport, accessToken: token
            )
            guard !Task.isCancelled else { return }
            switch outcome {
            case .page(let items, let total, let nextCursor):
                showList(
                    .recentList(items: items, hasMore: nextCursor != nil, total: total, period: period),
                    nextCursor: nextCursor, source: .recent(limit: limit, period: period), typed: typed
                )
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

    func cancelPendingConfirmations() {
        let hadPending = pendingHandoff != nil || pendingDrop != nil || pendingBinEmpty != nil || pendingSignOutEverywhere
        pendingHandoff = nil
        pendingDrop = nil
        pendingBinEmpty = nil
        pendingSignOutEverywhere = false
        if hadPending {
            update(viewState.appending(lines: [.cancelled]).with(input: ""))
        }
    }

    /// 목록 줄을 찍는다. `→ 더 보기`는 마지막 목록에만 둔다. 앞 목록의 것은 뺀다.
    func showList(_ line: TerminalViewState.Line, nextCursor: String?, source: ListPage.Source, typed: String) {
        let closed = listPage.map { viewState.closingList(at: $0.lineIndex) } ?? viewState
        update(closed.appending(lines: [line]))
        listPage = nextCursor.map {
            ListPage(lineIndex: viewState.lines.count - 1, cursor: $0, source: source, typed: typed)
        }
    }

    /// 마지막 목록에 다음 쪽을 이어 붙인다. 받는 중에 또 누르면 무시한다.
    private func loadMore() {
        guard let page = listPage, loadingPage != page else { return }
        loadingPage = page
        startTask { [weak self] in
            guard let self else { return }
            defer { if loadingPage == page { loadingPage = nil } }
            let token = await authService.accessToken()
            guard !Task.isCancelled else { return }
            guard let token else {
                expire()
                return
            }
            if case .bin = page.source {
                let outcome = await TrashAPI.list(
                    limit: Self.binPageSize, cursor: page.cursor, transport: httpTransport, accessToken: token
                )
                guard !Task.isCancelled, listPage == page else { return }
                switch outcome {
                case .page(_, let items, let nextCursor):
                    listPage = nextCursor.map {
                        ListPage(lineIndex: page.lineIndex, cursor: $0, source: page.source, typed: page.typed)
                    }
                    update(viewState.extendingBinList(at: page.lineIndex, with: items, hasMore: nextCursor != nil))
                case .failed(let reason):
                    update(viewState.appending(lines: [
                        .commandFailed(command: .bin, reason: reason, retry: page.typed),
                    ]))
                case .sessionExpired:
                    expire()
                case .cancelled:
                    break
                }
                return
            }
            let outcome = await nextPage(of: page, accessToken: token)
            // 기다리는 동안 다른 목록이 찍혔으면 늦게 온 쪽을 버린다.
            guard !Task.isCancelled, listPage == page else { return }
            switch outcome {
            case .page(let items, _, let nextCursor):
                listPage = nextCursor.map {
                    ListPage(lineIndex: page.lineIndex, cursor: $0, source: page.source, typed: page.typed)
                }
                update(viewState.extendingList(at: page.lineIndex, with: items, hasMore: nextCursor != nil))
            case .failed(let reason):
                update(viewState.appending(lines: [
                    .commandFailed(command: page.command, reason: reason, retry: page.typed),
                ]))
            case .sessionExpired:
                expire()
            case .cancelled:
                break
            }
        }
    }

    private func nextPage(of page: ListPage, accessToken: String) async -> BrowseAPI.PageOutcome {
        switch page.source {
        case .recent(let limit, let period):
            return await BrowseAPI.recent(
                limit: limit, cursor: page.cursor, period: period, transport: httpTransport, accessToken: accessToken
            )
        case .search(let query, let period):
            let outcome = await BrowseAPI.search(
                query, limit: SeekCommand.pageSize, cursor: page.cursor, period: period,
                transport: httpTransport, accessToken: accessToken
            )
            switch outcome {
            case .page(let items, let total, let nextCursor): return .page(items: items, total: total, nextCursor: nextCursor)
            case .sessionExpired: return .sessionExpired
            case .failed(let reason): return .failed(reason)
            case .cancelled: return .cancelled
            }
        case .bin:
            return .cancelled
        }
    }

    // MARK: 찾기

    private func seek(_ parsed: SeekCommand.Parsed, typed: String) {
        switch parsed {
        case .missingArgument:
            update(viewState.appending(lines: [.prompt(typed), .missingArgument(.seek)]).with(input: ""))
        case .missingTag:
            update(viewState.appending(lines: [.prompt(typed), .missingTag]).with(input: ""))
        case .query(let query, let period):
            search(query, period: period, typed: typed)
        }
    }

    /// `GET /items/search`. 0건이면 최근 저장 자료를 함께 보인다(commands 6절). 실패는 `✗ 찾기 안 됨`(COM-010 규칙 1).
    private func search(_ query: SearchQuery, period: Period?, typed: String) {
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
            let outcome = await BrowseAPI.search(
                query, limit: SeekCommand.pageSize, cursor: nil, period: period, transport: httpTransport, accessToken: token
            )
            guard !Task.isCancelled else { return }
            switch outcome {
            case .page(let items, _, _) where items.isEmpty:
                await showNoResults(for: query, period: period, typed: typed, accessToken: token)
            case .page(let items, let total, let nextCursor):
                showList(
                    .searchResult(query: query, total: total, items: items, hasMore: nextCursor != nil, period: period),
                    nextCursor: nextCursor, source: .search(query, period: period), typed: typed
                )
            case .failed(let reason):
                update(viewState.appending(lines: [.commandFailed(command: .seek, reason: reason, retry: typed)]))
            case .sessionExpired:
                restoreInput(typed)
                expire()
            case .cancelled:
                break
            }
        }
    }

    /// `· 0건` 뒤에 붙일 최근 저장 자료를 받는다. 받지 못해도 찾기는 끝난 것이라 0건 줄은 찍는다.
    func showNoResults(for query: SearchQuery, period: Period? = nil, typed: String, accessToken: String) async {
        let outcome = await BrowseAPI.recent(
            limit: SeekCommand.noResultsRecentCount, cursor: nil, transport: httpTransport, accessToken: accessToken
        )
        guard !Task.isCancelled else { return }
        switch outcome {
        case .page(let items, _, _):
            showList(.noResults(query: query, recent: items, period: period), nextCursor: nil, source: .search(query, period: period), typed: typed)
        case .failed:
            showList(.noResults(query: query, recent: [], period: period), nextCursor: nil, source: .search(query, period: period), typed: typed)
        case .sessionExpired:
            restoreInput(typed)
            expire()
        case .cancelled:
            break
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

    /// 계속 폴링해도 되면 true. 만료·취소·인증 거절이면 false.
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
        // 인증이 거절되면 다시 물어도 같다. 화면이 바뀌어 폴링이 새로 시작될 때까지 멈춘다.
        case .unauthorized, .cancelled:
            return false
        }
    }

    // MARK: 연결 끊김과 다시 연결(COM-010)

    /// 네트워크 오류면 `연결 끊김` 칸을 두고, 그 뒤 처음 서버에 닿으면 `✓ 연결됨`을 한 줄 찍는다.
    /// 끊긴 동안 친 명령은 다시 하지 않는다(규칙 5).
    func observeReachability(_ isReachable: Bool) {
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
    func update(_ next: TerminalViewState) {
        let counted = next.with(processingCount: next.processingNumbers(excluding: goneNumbers).count)
        guard counted != viewState else { return }
        viewState = counted
        presenter.render(counted)
        saveHistory()
        startPollingIfNeeded()
    }
}

extension TerminalViewState {
    func with(input: String) -> TerminalViewState {
        var next = self
        next.input = input
        return next
    }

    func with(itemCount: Int?) -> TerminalViewState {
        var next = self
        next.itemCount = itemCount
        return next
    }

    func with(processingCount: Int) -> TerminalViewState {
        var next = self
        next.processingCount = processingCount
        return next
    }

    func with(isOffline: Bool) -> TerminalViewState {
        var next = self
        next.isOffline = isOffline
        return next
    }

    func with(selection: [ItemRef]) -> TerminalViewState {
        var next = self
        next.selection = selection
        return next
    }

    func with(revising: Revising?) -> TerminalViewState {
        var next = self
        next.revising = revising
        return next
    }

    func appending(lines added: [Line]) -> TerminalViewState {
        var next = self
        next.lines += added
        return next
    }
}

typealias TerminalRouter = ViewableRouter<TerminalInteractor, any TerminalViewControllable>
