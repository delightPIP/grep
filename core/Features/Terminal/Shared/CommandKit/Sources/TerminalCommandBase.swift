import GrepCore
import TerminalDomain

/// 명령 모듈의 공통 부모. `TerminalContext`의 것을 같은 이름으로 넘겨, 명령 코드는 터미널 안에 있을 때와 같이 쓴다.
/// 터미널 RIB이 명령 모듈을 쥐므로 `context`는 약하게 든다. RIB이 사라진 뒤 끝나는 작업은 화면을 바꾸지 않는다.
/// 포트(인증·전송·클립보드·파일·기다리기)는 만들 때 받아 직접 쥔다.
@MainActor
open class TerminalCommandBase {
    public private(set) weak var context: (any TerminalContext)?
    public let authService: any AuthService
    public let httpTransport: any HTTPTransport
    public let rawTransport: any HTTPTransport
    public let clipboard: any ClipboardPort
    public let files: any FilePort
    public let sleeper: any Sleeper

    public init(context: any TerminalContext) {
        self.context = context
        authService = context.authService
        httpTransport = context.httpTransport
        rawTransport = context.rawTransport
        clipboard = context.clipboard
        files = context.files
        sleeper = context.sleeper
    }

    public var viewState: TerminalViewState { context?.viewState ?? TerminalViewState() }
    /// RIB이 사라졌으면 어떤 입력 차례와도 같지 않은 값.
    public var inputSequence: Int { context?.inputSequence ?? -1 }

    public func update(_ next: TerminalViewState) { context?.update(next) }

    public func run(typed: String, _ request: @escaping @MainActor (_ accessToken: String) async -> Void) {
        context?.run(typed: typed, request)
    }

    public func startTask(_ operation: @escaping @MainActor () async -> Void) { context?.launch(operation) }
    public func restoreInput(_ text: String) { context?.restoreInput(text) }
    public func expire() { context?.expire() }
    public func expire(restoring typed: String) { context?.expire(restoring: typed) }
    public func notifyItemsChanged() { context?.notifyItemsChanged() }
    public func notifyConnectionsChanged() { context?.notifyConnectionsChanged() }

    public func showList(
        _ line: TerminalViewState.Line, nextCursor: String?, source: TerminalListSource, typed: String
    ) {
        context?.showList(line, nextCursor: nextCursor, source: source, typed: typed)
    }

    public func showNoResults(
        for query: SearchQuery, period: Period? = nil, related: [ItemSummary] = [], typed: String, accessToken: String
    ) async {
        await context?.showNoResults(for: query, period: period, related: related, typed: typed, accessToken: accessToken)
    }

    public func searchThenHandOff(
        _ query: SearchQuery, period: Period?, typed: String, sequence: Int, accessToken: String
    ) async {
        await context?.searchThenHandOff(query, period: period, typed: typed, sequence: sequence, accessToken: accessToken)
    }
}
