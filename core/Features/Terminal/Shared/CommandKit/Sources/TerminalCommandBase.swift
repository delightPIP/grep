import GrepCore
import TerminalDomain

/// 명령 모듈의 공통 부모. `TerminalContext`의 것을 같은 이름으로 넘겨, 명령 코드는 터미널 안에 있을 때와 같이 쓴다.
/// 터미널 RIB이 명령 모듈을 쥐므로 `context`는 소유하지 않는다.
@MainActor
open class TerminalCommandBase {
    public unowned let context: any TerminalContext

    public init(context: any TerminalContext) {
        self.context = context
    }

    public var viewState: TerminalViewState { context.viewState }
    public var inputSequence: Int { context.inputSequence }
    public var authService: any AuthService { context.authService }
    public var httpTransport: any HTTPTransport { context.httpTransport }
    public var rawTransport: any HTTPTransport { context.rawTransport }
    public var clipboard: any ClipboardPort { context.clipboard }
    public var files: any FilePort { context.files }
    public var sleeper: any Sleeper { context.sleeper }

    public func update(_ next: TerminalViewState) { context.update(next) }

    public func run(typed: String, _ request: @escaping @MainActor (_ accessToken: String) async -> Void) {
        context.run(typed: typed, request)
    }

    public func startTask(_ operation: @escaping @MainActor () async -> Void) { context.launch(operation) }
    public func restoreInput(_ text: String) { context.restoreInput(text) }
    public func expire() { context.expire() }
    public func expire(restoring typed: String) { context.expire(restoring: typed) }
    public func notifyItemsChanged() { context.notifyItemsChanged() }
    public func notifyConnectionsChanged() { context.notifyConnectionsChanged() }

    public func showList(
        _ line: TerminalViewState.Line, nextCursor: String?, source: TerminalListSource, typed: String
    ) {
        context.showList(line, nextCursor: nextCursor, source: source, typed: typed)
    }

    public func showNoResults(
        for query: SearchQuery, period: Period? = nil, related: [ItemSummary] = [], typed: String, accessToken: String
    ) async {
        await context.showNoResults(for: query, period: period, related: related, typed: typed, accessToken: accessToken)
    }

    public func searchThenHandOff(
        _ query: SearchQuery, period: Period?, typed: String, sequence: Int, accessToken: String
    ) async {
        await context.searchThenHandOff(query, period: period, typed: typed, sequence: sequence, accessToken: accessToken)
    }
}
