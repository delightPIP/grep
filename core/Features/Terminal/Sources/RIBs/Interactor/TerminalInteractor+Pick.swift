import FeatureTerminalInterface
import GrepCore
import GrepData

// MARK: 고르기(#62)

extension TerminalInteractor {
    func pick(_ parsed: PickCommand.Parsed, typed: String) {
        switch parsed {
        case .missingArgument:
            update(viewState.appending(lines: [.prompt(typed), .missingArgument(.pick)]).with(input: ""))
        case .missingUnpickNumbers:
            update(viewState.appending(lines: [.prompt(typed), .missingArgument(.pick, sub: .unpick)]).with(input: ""))
        case .invalidNumber(let input):
            update(viewState.appending(lines: [.prompt(typed), .invalidNumber(input)]).with(input: ""))
        case .numbers(let numbers):
            select(numbers, typed: typed)
        case .unpick(let numbers):
            unpick(numbers, typed: typed)
        case .clear:
            clearSelection(typed: typed)
        }
    }

    /// `고르기 빼기 <번호…>`(#108). 남은 선택이 0건이면 `unpicked` 대신 `pickCleared`를 찍는다(통합 전달 1).
    private func unpick(_ numbers: [Int], typed: String) {
        let byNumber = Dictionary(viewState.selection.map { ($0.number, $0) }) { first, _ in first }
        let missing = numbers.filter { byNumber[$0] == nil }
        guard missing.isEmpty else {
            update(viewState.appending(lines: [.prompt(typed), .notFound(numbers: missing)]).with(input: ""))
            return
        }
        let removing = Set(numbers)
        let removed = numbers.compactMap { byNumber[$0] }
        let remaining = viewState.selection.filter { !removing.contains($0.number) }
        let line: TerminalViewState.Line = remaining.isEmpty
            ? .pickCleared(count: removed.count)
            : .unpicked(items: removed, remaining: remaining.count)
        update(viewState.with(selection: remaining).appending(lines: [.prompt(typed), line]).with(input: ""))
    }

    /// `고르기 비우기`(#108).
    private func clearSelection(typed: String) {
        let count = viewState.selection.count
        update(viewState.with(selection: []).appending(lines: [.prompt(typed), .pickCleared(count: count)]).with(input: ""))
    }

    /// `GET /items/status`로 번호를 확인한 뒤 선택에 더한다. 바로 앞 목록에 없던 번호도 받는다(ARC-001 규칙 9).
    /// 하나라도 없으면 아무것도 고르지 않는다(규칙 10). 실패는 `✗ 고르기 안 됨`(COM-010 규칙 1).
    private func select(_ numbers: [Int], typed: String) {
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await BrowseAPI.statuses(of: numbers, transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .found(let items, _):
                showPicked(numbers, found: items)
            case .failed(let reason):
                update(viewState.appending(lines: [.commandFailed(command: .pick, reason: reason, retry: typed)]))
            // 명령 실패 이유는 COM-010의 셋뿐이다.
            case .unauthorized:
                update(viewState.appending(lines: [.commandFailed(command: .pick, reason: .serverError, retry: typed)]))
            case .sessionExpired:
                expire(restoring: typed)
            case .cancelled:
                break
            }
        }
    }

    /// 서버가 돌려주지 않은 번호는 없는 번호다. 고른 자료는 선택 뒤에 친 순서로 붙인다.
    private func showPicked(_ numbers: [Int], found items: [ItemSummary]) {
        let found = Dictionary(items.map { ($0.number, $0) }) { first, _ in first }
        let missing = numbers.filter { found[$0] == nil }
        guard missing.isEmpty else {
            update(viewState.appending(lines: [.notFound(numbers: missing)]))
            return
        }
        let selected = Set(viewState.selection.map(\.number))
        let added = numbers
            .filter { !selected.contains($0) }
            .compactMap { found[$0].map(ItemRef.init) }
        let selection = viewState.selection + added
        update(viewState.with(selection: selection).appending(lines: [.picked(selection)]))
    }
}
