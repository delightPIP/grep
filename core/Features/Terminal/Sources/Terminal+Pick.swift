import FeatureTerminalInterface
import GrepCore

// MARK: 고르기(#62)

extension TerminalInteractor {
    func pick(_ parsed: PickCommand.Parsed, typed: String) {
        switch parsed {
        case .missingArgument:
            update(viewState.appending(lines: [.prompt(typed), .missingArgument(.pick)]).with(input: ""))
        case .invalidNumber(let input):
            update(viewState.appending(lines: [.prompt(typed), .invalidNumber(input)]).with(input: ""))
        case .numbers(let numbers):
            select(numbers, typed: typed)
        }
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
        let titles = Dictionary(items.map { ($0.number, $0.title) }) { first, _ in first }
        let missing = numbers.filter { titles[$0] == nil }
        guard missing.isEmpty else {
            update(viewState.appending(lines: [.notFound(numbers: missing)]))
            return
        }
        let selected = Set(viewState.selection.map(\.number))
        let added = numbers
            .filter { !selected.contains($0) }
            .compactMap { number in titles[number].map { ItemRef(number: number, title: $0) } }
        let selection = viewState.selection + added
        update(viewState.with(selection: selection).appending(lines: [.picked(selection)]))
    }
}
