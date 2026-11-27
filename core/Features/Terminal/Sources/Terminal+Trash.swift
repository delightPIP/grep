import FeatureTerminalInterface
import GrepCore

// MARK: 버리기·되살리기·휴지통(#93, #96, ARC-008)

/// `버리기 2건 이상` 확인 대기(COM-007). 실행 낱말은 `버리기`·`drop` 하나뿐.
struct PendingDrop: Equatable {
    let numbers: [Int]
    let typed: String

    func matches(_ text: String) -> Bool {
        let word = text.trimmingWhitespace()
        return word == "버리기" || word == "drop"
    }
}

/// `휴지통 비우기` 확인 대기(COM-007). 실행 낱말은 `비우기`·`empty` 하나뿐.
struct PendingBinEmpty: Equatable {
    let total: Int

    func matches(_ text: String) -> Bool {
        let word = text.trimmingWhitespace()
        return word == "비우기" || word == "empty"
    }
}

/// `버리기`·`되살리기` 번호 인자 파서. 단일 번호와 `a-b` 범위를 모두 받아 펼친다(ARC-001 비고, ARC-010 규칙 6).
enum TrashNumberParser {
    enum Parsed: Equatable {
        case numbers([Int])
        case missingArgument
        case invalidNumber(String)
    }

    private static let maxRangeSpan = 200

    static func parse(_ argument: String) -> Parsed {
        let tokens = argument.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return .missingArgument }
        var numbers: [Int] = []
        for token in tokens {
            if let expanded = expand(token) {
                for number in expanded where !numbers.contains(number) {
                    numbers.append(number)
                }
            } else {
                return .invalidNumber(token)
            }
        }
        return .numbers(numbers)
    }

    private static func expand(_ token: String) -> [Int]? {
        if let single = positiveInt(token) {
            return [single]
        }
        let parts = token.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let start = positiveInt(String(parts[0])),
              let end = positiveInt(String(parts[1])),
              start <= end,
              end - start + 1 <= maxRangeSpan else {
            return nil
        }
        return Array(start...end)
    }

    private static func positiveInt(_ text: String) -> Int? {
        guard !text.isEmpty, text.allSatisfy({ $0.isASCII && $0.isNumber }),
              let value = Int(text), value >= 1 else {
            return nil
        }
        return value
    }
}

extension TerminalInteractor {
    static let binPageSize = 20

    func dropItems(_ argument: String, typed: String) {
        switch TrashNumberParser.parse(argument) {
        case .missingArgument:
            update(viewState.appending(lines: [.prompt(typed), .missingArgument(.drop)]).with(input: ""))
        case .invalidNumber(let input):
            update(viewState.appending(lines: [.prompt(typed), .invalidNumber(input)]).with(input: ""))
        case .numbers(let numbers):
            if numbers.count >= 2 {
                pendingDrop = PendingDrop(numbers: numbers, typed: typed)
                update(viewState.appending(lines: [.prompt(typed), .dropConfirm(total: numbers.count)]).with(input: ""))
            } else {
                executeDrop(numbers, typed: typed)
            }
        }
    }

    func confirmDrop(_ pending: PendingDrop, typed: String) {
        executeDrop(pending.numbers, typed: typed)
    }

    func reviveItems(_ argument: String, typed: String) {
        switch TrashNumberParser.parse(argument) {
        case .missingArgument:
            update(viewState.appending(lines: [.prompt(typed), .missingArgument(.revive)]).with(input: ""))
        case .invalidNumber(let input):
            update(viewState.appending(lines: [.prompt(typed), .invalidNumber(input)]).with(input: ""))
        case .numbers(let numbers):
            executeRevive(numbers, typed: typed)
        }
    }

    func handleBin(_ argument: String, typed: String) {
        if argument.isEmpty {
            showBin(typed: typed)
        } else if argument == "비우기" || argument == "empty" {
            requestEmptyBin(typed: typed)
        } else {
            update(viewState.appending(lines: [.prompt(typed), .unknownCommand(typed.trimmingWhitespace())]).with(input: ""))
        }
    }

    func confirmBinEmpty(typed: String) {
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await TrashAPI.empty(transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .emptied(let count):
                update(viewState.appending(lines: [.binEmptied(count: count)]))
            case .failed(let reason):
                update(viewState.appending(lines: [.commandFailed(command: .bin, reason: reason, retry: typed)]))
            case .sessionExpired:
                expire(restoring: typed)
            case .cancelled:
                break
            }
        }
    }

    private func showBin(typed: String) {
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await TrashAPI.list(
                limit: Self.binPageSize, cursor: nil, transport: httpTransport, accessToken: token
            )
            guard !Task.isCancelled else { return }
            switch outcome {
            case .page(let total, let items, let nextCursor):
                showList(
                    .binList(total: total, items: items, hasMore: nextCursor != nil),
                    nextCursor: nextCursor, source: .bin, typed: typed
                )
            case .failed(let reason):
                update(viewState.appending(lines: [.commandFailed(command: .bin, reason: reason, retry: typed)]))
            case .sessionExpired:
                expire(restoring: typed)
            case .cancelled:
                break
            }
        }
    }

    private func requestEmptyBin(typed: String) {
        let sequence = inputSequence
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await TrashAPI.list(limit: 1, cursor: nil, transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .page(let total, _, _) where total == 0:
                update(viewState.appending(lines: [.binEmptied(count: 0)]))
            case .page(let total, _, _) where inputSequence != sequence:
                update(viewState.appending(lines: [.binEmptyConfirm(total: total), .cancelled]))
            case .page(let total, _, _):
                pendingBinEmpty = PendingBinEmpty(total: total)
                update(viewState.appending(lines: [.binEmptyConfirm(total: total)]))
            case .failed(let reason):
                update(viewState.appending(lines: [.commandFailed(command: .bin, reason: reason, retry: typed)]))
            case .sessionExpired:
                expire(restoring: typed)
            case .cancelled:
                break
            }
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
