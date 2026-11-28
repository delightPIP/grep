import FeatureTerminalInterface
import GrepCore
import GrepData

// MARK: AI 도구 연결(#124, ACC-002)

/// `연결 끊기 <번호>` 확인 대기(COM-007). 실행 낱말은 `끊기` 하나뿐.
struct PendingDisconnect: Equatable {
    static let word = "끊기"

    let number: Int
    let client: String

    func matches(_ text: String) -> Bool {
        text.trimmingWhitespace() == Self.word
    }
}

extension TerminalInteractor {
    func handleConnections(_ argument: String, typed: String) {
        guard !argument.isEmpty else {
            showConnections(typed: typed)
            return
        }
        let tokens = argument.split(whereSeparator: \.isWhitespace).map(String.init)
        guard tokens.first == PendingDisconnect.word else {
            update(viewState.appending(lines: [.prompt(typed), .unknownCommand(typed.trimmingWhitespace())]).with(input: ""))
            return
        }
        switch PickCommand.parse(tokens.dropFirst().joined(separator: " ")) {
        case .numbers(let numbers) where numbers.count == 1:
            askDisconnect(numbers[0], typed: typed)
        case .numbers, .unpick, .clear, .missingUnpickNumbers:
            update(viewState.appending(lines: [.prompt(typed), .oneNumberOnly(.plug)]).with(input: ""))
        case .missingArgument:
            update(viewState.appending(lines: [.prompt(typed), .missingArgument(.plug)]).with(input: ""))
        case .invalidNumber(let input):
            update(viewState.appending(lines: [.prompt(typed), .invalidNumber(input)]).with(input: ""))
        }
    }

    func confirmDisconnect(_ pending: PendingDisconnect, typed: String) {
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await ConnectionsAPI.end(number: pending.number, transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .success(let ended):
                update(viewState.appending(lines: [.disconnected(client: ended.client, already: ended.already)]))
                notifyConnectionsChanged()
            case .notFound:
                update(viewState.appending(lines: [.connectionNotFound(number: pending.number)]))
            case .failed(let reason):
                update(viewState.appending(lines: [.commandFailed(command: .plug, reason: reason, retry: typed)]))
            case .sessionExpired:
                expire(restoring: typed)
            case .cancelled:
                break
            }
        }
    }

    /// `로그아웃 모든기기` 확인 줄을 바로 찍고, 끊길 연결 수를 받으면 그 줄을 고친다(ACC-002 사용자 문구).
    /// 연결 수를 받지 못해도 확인은 그대로 받는다.
    func askSignOutEverywhere(typed: String) {
        pendingSignOutEverywhere = true
        update(viewState.appending(lines: [.prompt(typed), .signOutEverywhereConfirm(connectionCount: nil)]).with(input: ""))
        let confirmIndex = viewState.lines.count - 1
        startTask { [weak self] in
            guard let self else { return }
            guard let token = await authService.accessToken(), !Task.isCancelled else { return }
            let outcome = await ConnectionsAPI.list(transport: httpTransport, accessToken: token)
            guard !Task.isCancelled, case .success(let list) = outcome,
                  viewState.lines.indices.contains(confirmIndex),
                  case .signOutEverywhereConfirm = viewState.lines[confirmIndex] else { return }
            update(viewState.replacingLine(
                at: confirmIndex, with: .signOutEverywhereConfirm(connectionCount: list.connections.count)
            ))
        }
    }

    func showConnectionNotices(_ notices: [ConnectionNotice]) {
        guard !notices.isEmpty else { return }
        update(viewState.appending(lines: notices.map { .connectionEnded(client: $0.client, reason: $0.reason) }))
    }

    private func showConnections(typed: String) {
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await ConnectionsAPI.list(transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .success(let list):
                update(viewState.appending(lines: [.connectionList(mcpUrl: list.mcpUrl, connections: list.connections)]))
            case .notFound:
                update(viewState.appending(lines: [.commandFailed(command: .plug, reason: .serverError, retry: typed)]))
            case .failed(let reason):
                update(viewState.appending(lines: [.commandFailed(command: .plug, reason: reason, retry: typed)]))
            case .sessionExpired:
                expire(restoring: typed)
            case .cancelled:
                break
            }
        }
    }

    /// 확인 줄에 AI 도구 이름을 넣으려고 목록을 먼저 받는다. 목록에 없는 번호면 묻지 않는다.
    private func askDisconnect(_ number: Int, typed: String) {
        let sequence = inputSequence
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await ConnectionsAPI.list(transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .success(let list):
                guard let connection = list.connections.first(where: { $0.number == number }) else {
                    update(viewState.appending(lines: [.connectionNotFound(number: number)]))
                    return
                }
                let confirm = TerminalViewState.Line.disconnectConfirm(number: number, client: connection.client)
                if inputSequence != sequence {
                    update(viewState.appending(lines: [confirm, .cancelled]))
                    return
                }
                pendingDisconnect = PendingDisconnect(number: number, client: connection.client)
                update(viewState.appending(lines: [confirm]))
            case .notFound:
                update(viewState.appending(lines: [.commandFailed(command: .plug, reason: .serverError, retry: typed)]))
            case .failed(let reason):
                update(viewState.appending(lines: [.commandFailed(command: .plug, reason: reason, retry: typed)]))
            case .sessionExpired:
                expire(restoring: typed)
            case .cancelled:
                break
            }
        }
    }
}
