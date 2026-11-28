import GrepCore
import GrepData
import TerminalCommandKit
import TerminalDomain

/// `최근`·`찾기`·`열기`·`찾아두기`(commands 3·6절, ARC-011, ARC-012). 열기·찾아두기는 같은 이름의 확장 파일에 있다.
public final class TerminalBrowseCommands: TerminalCommandBase, TerminalCommand {
    /// 답을 기다리는 `찾아두기 <검색어> 지우기` 확인(ARC-012 규칙 7, COM-007).
    var pendingSavedSearchDelete: PendingSavedSearchDelete?

    public var hasPendingAnswer: Bool { pendingSavedSearchDelete != nil }

    public func answer(_ text: String) -> Bool {
        guard let pending = pendingSavedSearchDelete, pending.matches(text) else { return false }
        pendingSavedSearchDelete = nil
        confirmSavedSearchDelete(pending, typed: text)
        return true
    }

    public func cancelPendingAnswer() {
        pendingSavedSearchDelete = nil
    }

    // MARK: 최근

    /// `GET /items`. 친 줄은 바로 찍는다. 실패하면 `✗ 최근 안 됨`과 다시 칠 명령을 보인다(COM-010 규칙 1).
    public func showRecent(limit: Int, period: Period?, typed: String) {
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

    // MARK: 찾기

    public func seek(_ parsed: SeekCommand.Parsed, typed: String) {
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
            case .page(let items, _, _, _, let related) where items.isEmpty:
                await showNoResults(for: query, period: period, related: related, typed: typed, accessToken: token)
            case .page(let items, let total, let nextCursor, let isSavedSearch, _):
                showList(
                    .searchResult(
                        query: query, total: total, items: items, hasMore: nextCursor != nil, period: period,
                        isSavedSearch: isSavedSearch
                    ),
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
}
