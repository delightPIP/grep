import FeatureTerminalInterface
import TerminalDomain
import GrepCore
import GrepData

// MARK: 찾아두기(#134, ARC-012)

/// `찾아두기 <검색어> 지우기` 확인 대기(COM-007). 실행 낱말은 `지우기` 하나뿐.
struct PendingSavedSearchDelete: Equatable {
    let query: String

    func matches(_ text: String) -> Bool {
        text.trimmingWhitespace() == GatherCommand.deleteWord
    }
}

extension TerminalInteractor {
    /// `찾아두기 <검색어> | 넘기기`는 찾아둔 뒤 `찾기 … | 넘기기`와 같이 넘긴다(규칙 8).
    func handleGather(_ argument: String, typed: String) {
        var head = argument
        var pipesToHandoff = false
        if let (left, tail) = PipeCommand.split(argument) {
            guard let next = InputCommand(tail), next.name == .handoff, next.argument.isEmpty else {
                update(viewState.appending(lines: [.prompt(typed), .unknownCommand(tail)]).with(input: ""))
                return
            }
            head = left
            pipesToHandoff = true
        }
        switch GatherCommand.parse(head) {
        case .list where !pipesToHandoff:
            showSavedSearches(typed: typed)
        case .list, .missingArgument:
            reject(.missingArgument(.gather), typed: typed)
        case .save(let query, let search):
            saveSearch(query, search: search, pipesToHandoff: pipesToHandoff, typed: typed)
        case .delete(let query) where !pipesToHandoff:
            pendingSavedSearchDelete = PendingSavedSearchDelete(query: query)
            update(viewState.appending(lines: [.prompt(typed), .savedSearchDeleteConfirm(query: query)]).with(input: ""))
        case .delete:
            update(viewState.appending(lines: [.prompt(typed), .unknownCommand(typed.trimmingWhitespace())]).with(input: ""))
        case .missingTag:
            reject(.missingTag, typed: typed)
        case .period(let period, let suggestion):
            reject(.savedSearchPeriod(period: period, suggestion: suggestion), typed: typed)
        case .tooLong:
            reject(.savedSearchTooLong, typed: typed)
        }
    }

    func confirmSavedSearchDelete(_ pending: PendingSavedSearchDelete, typed: String) {
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await SavedSearchAPI.delete(query: pending.query, transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .success:
                update(viewState.appending(lines: [.savedSearchDeleted(query: pending.query)]))
            case .notFound:
                update(viewState.appending(lines: [.savedSearchNotFound(query: pending.query)]))
            case .rejected:
                update(viewState.appending(lines: [.commandFailed(command: .gather, reason: .serverError, retry: typed)]))
            case .failed(let reason):
                update(viewState.appending(lines: [.commandFailed(command: .gather, reason: reason, retry: typed)]))
            case .sessionExpired:
                expire(restoring: typed)
            case .cancelled:
                break
            }
        }
    }

    private func reject(_ line: TerminalViewState.Line, typed: String) {
        update(viewState.appending(lines: [.prompt(typed), line]).with(input: ""))
    }

    private func showSavedSearches(typed: String) {
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await SavedSearchAPI.list(transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .success(let searches):
                update(viewState.appending(lines: [.savedSearchList(searches)]))
            case .notFound, .rejected:
                update(viewState.appending(lines: [.commandFailed(command: .gather, reason: .serverError, retry: typed)]))
            case .failed(let reason):
                update(viewState.appending(lines: [.commandFailed(command: .gather, reason: reason, retry: typed)]))
            case .sessionExpired:
                expire(restoring: typed)
            case .cancelled:
                break
            }
        }
    }

    /// 찾아둔 뒤 같은 검색어로 결과를 보인다(규칙 1·2). 0건이어도 찾아둔다(규칙 5).
    private func saveSearch(_ query: String, search: SearchQuery, pipesToHandoff: Bool, typed: String) {
        let sequence = inputSequence
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await SavedSearchAPI.save(query: query, transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .success(let saved):
                update(viewState.appending(lines: [
                    .searchSaved(query: saved.query, total: saved.count, already: saved.already),
                ]))
                if pipesToHandoff {
                    await searchThenHandOff(search, period: nil, typed: typed, sequence: sequence, accessToken: token)
                } else {
                    await showSavedResults(search, typed: typed, accessToken: token)
                }
            case .rejected:
                update(viewState.appending(lines: [.savedSearchTooLong]))
            case .notFound:
                update(viewState.appending(lines: [.commandFailed(command: .gather, reason: .serverError, retry: typed)]))
            case .failed(let reason):
                update(viewState.appending(lines: [.commandFailed(command: .gather, reason: reason, retry: typed)]))
            case .sessionExpired:
                expire(restoring: typed)
            case .cancelled:
                break
            }
        }
    }

    /// 0건이면 `searchSaved` 줄이 안내까지 맡으므로 목록을 더 찍지 않는다.
    private func showSavedResults(_ search: SearchQuery, typed: String, accessToken: String) async {
        let outcome = await BrowseAPI.search(
            search, limit: SeekCommand.pageSize, cursor: nil, transport: httpTransport, accessToken: accessToken
        )
        guard !Task.isCancelled else { return }
        switch outcome {
        case .page(let items, _, _, _, _) where items.isEmpty:
            break
        case .page(let items, let total, let nextCursor, let isSavedSearch, _):
            showList(
                .searchResult(
                    query: search, total: total, items: items, hasMore: nextCursor != nil,
                    isSavedSearch: isSavedSearch ?? true
                ),
                nextCursor: nextCursor, source: .search(search, period: nil), typed: typed
            )
        case .failed(let reason):
            update(viewState.appending(lines: [.commandFailed(command: .gather, reason: reason, retry: typed)]))
        case .sessionExpired:
            expire(restoring: typed)
        case .cancelled:
            break
        }
    }
}
