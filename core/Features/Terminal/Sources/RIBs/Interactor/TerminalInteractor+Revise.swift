import FeatureTerminalInterface
import GrepCore
import GrepData

// MARK: 고치기(#99, ARC-002·004)

enum ReviseCommand {
    enum Parsed: Equatable {
        case openEditor(number: Int)
        case removeTags(number: Int, tags: [String])
        case missingArgument
        case invalidNumber(String)
    }

    static func parse(_ argument: String) -> Parsed {
        let tokens = argument.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let first = tokens.first else { return .missingArgument }
        guard first.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(first), number >= 1 else {
            return .invalidNumber(first)
        }
        let rest = tokens.dropFirst()
        guard !rest.isEmpty else { return .openEditor(number: number) }
        var tags: [String] = []
        for token in rest {
            guard token.hasPrefix("-#"), token.count > 2 else {
                return .invalidNumber(token)
            }
            let tag = String(token.dropFirst(2))
            if !tags.contains(tag) { tags.append(tag) }
        }
        return .removeTags(number: number, tags: tags)
    }
}

extension TerminalInteractor {
    func reviseItem(_ argument: String, typed: String) {
        switch ReviseCommand.parse(argument) {
        case .missingArgument:
            update(viewState.appending(lines: [.prompt(typed), .missingArgument(.revise)]).with(input: ""))
        case .invalidNumber(let token):
            update(viewState.appending(lines: [.prompt(typed), .invalidNumber(token)]).with(input: ""))
        case .openEditor(let number):
            openReviseEditor(number: number, typed: typed)
        case .removeTags(let number, let tags):
            removeTags(number: number, tags: tags, typed: typed)
        }
    }

    func submitRevise(number: Int, title: String, summary: String) {
        let trimmedTitle = title.trimmingWhitespace()
        let trimmedSummary = summary.trimmingWhitespace()
        guard !trimmedTitle.isEmpty || !trimmedSummary.isEmpty else {
            cancelRevise()
            return
        }
        let retry = "고치기 \(number)"
        update(viewState.with(revising: nil))
        startTask { [weak self] in
            guard let self else { return }
            let token = await authService.accessToken()
            guard !Task.isCancelled else { return }
            guard let token else {
                expire(restoring: retry)
                return
            }
            let outcome = await ReviseAPI.revise(
                number: number,
                title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                summary: trimmedSummary.isEmpty ? nil : trimmedSummary,
                transport: httpTransport,
                accessToken: token
            )
            guard !Task.isCancelled else { return }
            switch outcome {
            case .revised(let item):
                let nextSelection = viewState.selection.map {
                    $0.number == item.number ? ItemRef(item) : $0
                }
                update(
                    viewState
                        .replacingItems(with: [item])
                        .with(selection: nextSelection)
                        .appending(lines: [.revised(item)])
                )
            case .notFound:
                update(viewState.appending(lines: [.notFound(numbers: [number])]))
            case .failed(let reason):
                update(viewState.appending(lines: [.commandFailed(command: .revise, reason: reason, retry: retry)]))
            case .sessionExpired:
                expire(restoring: retry)
            case .cancelled:
                break
            }
        }
    }

    func cancelRevise() {
        guard viewState.revising != nil else { return }
        update(viewState.with(revising: nil).appending(lines: [.cancelled]))
    }

    private func openReviseEditor(number: Int, typed: String) {
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await BrowseAPI.statuses(of: [number], transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .found(let items, _):
                guard let item = items.first(where: { $0.number == number }) else {
                    update(viewState.appending(lines: [.notFound(numbers: [number])]))
                    return
                }
                update(viewState.with(revising: Revising(
                    number: item.number,
                    title: item.title,
                    summary: item.listSummary ?? ""
                )))
            case .failed(let reason):
                update(viewState.appending(lines: [.commandFailed(command: .revise, reason: reason, retry: typed)]))
            case .unauthorized:
                update(viewState.appending(lines: [.commandFailed(command: .revise, reason: .serverError, retry: typed)]))
            case .sessionExpired:
                expire(restoring: typed)
            case .cancelled:
                break
            }
        }
    }

    private func removeTags(number: Int, tags: [String], typed: String) {
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await ReviseAPI.revise(
                number: number,
                removeTags: tags,
                transport: httpTransport,
                accessToken: token
            )
            guard !Task.isCancelled else { return }
            switch outcome {
            case .revised(let item):
                update(viewState.replacingItems(with: [item]).appending(lines: [.tagsRemoved(item: item, tags: tags)]))
            case .notFound:
                update(viewState.appending(lines: [.notFound(numbers: [number])]))
            case .failed(let reason):
                update(viewState.appending(lines: [.commandFailed(command: .revise, reason: reason, retry: typed)]))
            case .sessionExpired:
                expire(restoring: typed)
            case .cancelled:
                break
            }
        }
    }
}
