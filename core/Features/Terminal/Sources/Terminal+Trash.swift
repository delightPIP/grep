import FeatureTerminalInterface
import GrepCore

// MARK: 버리기·되살리기(#93, ARC-008)

extension TerminalInteractor {
    func dropItems(_ argument: String, typed: String) {
        switch PickCommand.parse(argument) {
        case .missingArgument:
            update(viewState.appending(lines: [.prompt(typed), .missingArgument(.drop)]).with(input: ""))
        case .invalidNumber(let input):
            update(viewState.appending(lines: [.prompt(typed), .invalidNumber(input)]).with(input: ""))
        case .numbers(let numbers):
            executeDrop(numbers, typed: typed)
        }
    }

    func reviveItems(_ argument: String, typed: String) {
        switch PickCommand.parse(argument) {
        case .missingArgument:
            update(viewState.appending(lines: [.prompt(typed), .missingArgument(.revive)]).with(input: ""))
        case .invalidNumber(let input):
            update(viewState.appending(lines: [.prompt(typed), .invalidNumber(input)]).with(input: ""))
        case .numbers(let numbers):
            executeRevive(numbers, typed: typed)
        }
    }

    private func executeDrop(_ numbers: [Int], typed: String) {
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await TrashAPI.trash(numbers: numbers, transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .moved(let items):
                let droppedNumbers = Set(items.map(\.number))
                let remainingSelection = viewState.selection.filter { !droppedNumbers.contains($0.number) }
                let nextCount = viewState.itemCount.map { max(0, $0 - items.count) }
                update(
                    viewState
                        .with(itemCount: nextCount)
                        .with(selection: remainingSelection)
                        .appending(lines: [.dropped(items)])
                )
            case .notFound(let missing):
                update(viewState.appending(lines: [.notFound(numbers: missing)]))
            case .failed(let reason):
                update(viewState.appending(lines: [.commandFailed(command: .drop, reason: reason, retry: typed)]))
            case .sessionExpired:
                expire(restoring: typed)
            case .cancelled:
                break
            }
        }
    }

    private func executeRevive(_ numbers: [Int], typed: String) {
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await TrashAPI.restore(numbers: numbers, transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .moved(let items):
                let nextCount = viewState.itemCount.map { $0 + items.count }
                update(
                    viewState
                        .with(itemCount: nextCount)
                        .appending(lines: [.revived(items)])
                )
            case .notFound(let missing):
                update(viewState.appending(lines: [.notFound(numbers: missing)]))
            case .failed(let reason):
                update(viewState.appending(lines: [.commandFailed(command: .revive, reason: reason, retry: typed)]))
            case .sessionExpired:
                expire(restoring: typed)
            case .cancelled:
                break
            }
        }
    }
}
