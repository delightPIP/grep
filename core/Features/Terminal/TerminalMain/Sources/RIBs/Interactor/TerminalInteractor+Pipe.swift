import FeatureTerminalInterface
import TerminalDomain
import GrepCore
import GrepData

// MARK: 이어 쓰기 `찾기 … | 넘기기`(#66)

extension TerminalInteractor {
    /// `전부`가 남은 결과를 받을 때의 한 쪽 건수(api/openapi.yaml `Limit` 최댓값).
    private static let remainingPageSize = 50

    /// 찾기 뒤에 `|`가 있으면 이어 쓰기로 받는다. 이어 쓰기가 아니면 false.
    /// shortcut: 뒤 명령은 `넘기기`만 받는다. 다른 명령은 받을 줄이 계약에 없어 없는 명령으로 알린다.
    func pipe(seekArgument: String, typed: String) -> Bool {
        guard let (head, tail) = PipeCommand.split(seekArgument) else { return false }
        guard let next = InputCommand(tail), next.name == .handoff, next.argument.isEmpty else {
            update(viewState.appending(lines: [.prompt(typed), .unknownCommand(tail)]).with(input: ""))
            return true
        }
        switch SeekCommand.parse(head) {
        case .missingArgument:
            update(viewState.appending(lines: [.prompt(typed), .missingArgument(.seek)]).with(input: ""))
        case .missingTag:
            update(viewState.appending(lines: [.prompt(typed), .missingTag]).with(input: ""))
        case .query(let query, let period):
            searchThenHandOff(query, period: period, typed: typed)
        }
        return true
    }

    /// 결과가 5건 이하면 바로 복사하고, 넘으면 복사하지 않고 묻는다(COM-008 규칙 1~3). 0건은 찾기와 같다.
    private func searchThenHandOff(_ query: SearchQuery, period: Period?, typed: String) {
        let sequence = inputSequence
        run(typed: typed) { [weak self] token in
            await self?.searchThenHandOff(query, period: period, typed: typed, sequence: sequence, accessToken: token)
        }
    }

    /// 친 줄은 이미 찍혀 있다. `sequence`는 명령을 친 때의 입력 차례(`찾아두기 … | 넘기기`도 쓴다).
    func searchThenHandOff(
        _ query: SearchQuery,
        period: Period?,
        typed: String,
        sequence: Int,
        accessToken token: String
    ) async {
        let outcome = await BrowseAPI.search(
            query, limit: SeekCommand.pageSize, cursor: nil, period: period, transport: httpTransport, accessToken: token
        )
        guard !Task.isCancelled else { return }
        switch outcome {
        case .page(let items, _, _, _, let related) where items.isEmpty:
            await showNoResults(for: query, period: period, related: related, typed: typed, accessToken: token)
        case .page(let items, let total, _, _, _) where total <= PendingHandoff.instantLimit:
            await handOff(items.map(ItemRef.init), typed: typed, accessToken: token)
        // 기다리는 동안 다른 입력이 있었으면 그 입력이 이미 답이다. 묻자마자 취소한다(COM-007 규칙 1·3).
        case .page(_, let total, _, _, _) where inputSequence != sequence:
            update(viewState.appending(lines: [.handoffConfirm(total: total), .cancelled]))
        case .page(let items, let total, let nextCursor, _, _):
            pendingHandoff = PendingHandoff(
                query: query, total: total, firstPage: items.map(ItemRef.init), nextCursor: nextCursor
            )
            update(viewState.appending(lines: [.handoffConfirm(total: total)]))
        case .failed(let reason):
            update(viewState.appending(lines: [.commandFailed(command: .seek, reason: reason, retry: typed)]))
        case .sessionExpired:
            expire(restoring: typed)
        case .cancelled:
            break
        }
    }

    /// 기다리던 확인에 실행 낱말로 답했다. `앞10`은 첫 쪽만, `전부`는 남은 쪽까지 받아 넘긴다.
    func confirmHandoff(_ pending: PendingHandoff, choice: PendingHandoff.Choice, typed: String) {
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            var refs = pending.firstPage
            var cursor = choice == .all ? pending.nextCursor : nil
            while let next = cursor {
                let outcome = await BrowseAPI.search(
                    pending.query, limit: Self.remainingPageSize, cursor: next,
                    transport: httpTransport, accessToken: token
                )
                guard !Task.isCancelled else { return }
                switch outcome {
                case .page(let items, _, let nextCursor, _, _):
                    refs += items.map(ItemRef.init)
                    cursor = nextCursor
                case .failed(let reason):
                    update(viewState.appending(lines: [.handoffFailed(reason: reason, preview: nil)]))
                    return
                case .sessionExpired:
                    expire(restoring: typed)
                    return
                case .cancelled:
                    return
                }
            }
            await handOff(refs, typed: typed, accessToken: token)
        }
    }

    /// 확인을 기다리던 중 다른 입력이 왔다. `· 취소됨`을 찍는다(COM-007 규칙 3·5).
    func cancelPendingHandoff() {
        guard pendingHandoff != nil else { return }
        pendingHandoff = nil
        update(viewState.appending(lines: [.cancelled]).with(input: ""))
    }
}
