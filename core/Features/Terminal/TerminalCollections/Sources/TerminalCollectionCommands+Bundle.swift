import TerminalDomain
import GrepCore
import GrepData
import TerminalCommandKit
import TerminalDomain

// MARK: 묶음(#121, ARC-003)

/// `묶음 <이름> 지우기` 확인 대기(COM-007). 실행 낱말은 `지우기` 하나뿐.
struct PendingBundleDelete: Equatable {
    let name: String

    func matches(_ text: String) -> Bool {
        text.trimmingWhitespace() == BundleCommand.deleteWord
    }
}

extension TerminalCollectionCommands {
    public func handleBundle(_ argument: String, typed: String) {
        switch BundleCommand.parse(argument) {
        case .list:
            showBundles(typed: typed)
        case .named(let name) where viewState.selection.isEmpty:
            showBundle(name, typed: typed)
        case .named(let name):
            addSelection(to: name, typed: typed)
        case .remove(let name, let numbers):
            removeFromBundle(name, numbers: numbers, typed: typed)
        case .delete(let name):
            requestBundleDelete(name, typed: typed)
        case .invalidName(let problem):
            update(viewState.appending(lines: [.prompt(typed), .bundleNameInvalid(problem)]).with(input: ""))
        case .missingNumbers:
            update(viewState.appending(lines: [.prompt(typed), .missingArgument(.pack)]).with(input: ""))
        case .invalidNumber(let input):
            update(viewState.appending(lines: [.prompt(typed), .invalidNumber(input)]).with(input: ""))
        }
    }

    func confirmBundleDelete(_ pending: PendingBundleDelete, typed: String) {
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await BundleAPI.delete(name: pending.name, transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            show(outcome, name: pending.name, typed: typed) { _ in .bundleDeleted(name: pending.name) }
        }
    }

    /// 묶음 안 자료의 다음 쪽(`→ 더 보기`).
    private func showBundles(typed: String) {
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await BundleAPI.list(transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            show(outcome, name: "", typed: typed) { .bundleList($0) }
        }
    }

    private func showBundle(_ name: String, typed: String) {
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await BundleAPI.page(
                name: name, limit: TerminalPageSize.bundle, cursor: nil, transport: httpTransport, accessToken: token
            )
            guard !Task.isCancelled else { return }
            guard case .success(let page) = outcome else {
                show(outcome, name: name, typed: typed) { _ in nil }
                return
            }
            showList(
                .bundleView(name: page.name, total: page.total, items: page.items, hasMore: page.nextCursor != nil),
                nextCursor: page.nextCursor, source: .bundle(page.name), typed: typed
            )
        }
    }

    /// 선택한 자료를 넣고 선택을 비운다(ARC-003 규칙 4). 거절되면 선택을 남긴다.
    private func addSelection(to name: String, typed: String) {
        let numbers = viewState.selection.map(\.number)
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await BundleAPI.add(name: name, numbers: numbers, transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            if case .success(let added) = outcome {
                update(viewState.with(selection: []).appending(lines: [
                    .bundleAdded(name: added.name, count: added.count, alreadyCount: added.alreadyCount),
                ]))
                notifyItemsChanged()
                return
            }
            show(outcome, name: name, typed: typed) { _ in nil }
        }
    }

    private func removeFromBundle(_ name: String, numbers: [Int], typed: String) {
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await BundleAPI.remove(
                name: name, numbers: numbers, transport: httpTransport, accessToken: token
            )
            guard !Task.isCancelled else { return }
            show(outcome, name: name, typed: typed) { .bundleUnpicked(name: name, remaining: $0) }
        }
    }

    /// 지우기 전에 자료 수를 받아 확인 줄에 넣는다(ARC-003 사용자 문구). 기다리는 동안 다른 입력을 쳤으면 묻지 않고 취소한다.
    private func requestBundleDelete(_ name: String, typed: String) {
        let sequence = inputSequence
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await BundleAPI.page(
                name: name, limit: 1, cursor: nil, transport: httpTransport, accessToken: token
            )
            guard !Task.isCancelled else { return }
            guard case .success(let page) = outcome else {
                show(outcome, name: name, typed: typed) { _ in nil }
                return
            }
            let confirm = TerminalViewState.Line.bundleDeleteConfirm(name: page.name, itemCount: page.total)
            if inputSequence != sequence {
                update(viewState.appending(lines: [confirm, .cancelled]))
                return
            }
            pendingBundleDelete = PendingBundleDelete(name: page.name)
            update(viewState.appending(lines: [confirm]))
        }
    }

    /// 성공이면 `line(value)`를 찍는다. nil을 주면 성공은 부른 쪽이 처리한 것으로 본다.
    private func show<Value>(
        _ outcome: BundleAPI.Outcome<Value>,
        name: String,
        typed: String,
        line: (Value) -> TerminalViewState.Line?
    ) {
        switch outcome {
        case .success(let value):
            if let line = line(value) { update(viewState.appending(lines: [line])) }
        case .rejected(let rejection):
            update(viewState.appending(lines: [Self.line(for: rejection, name: name)]))
        case .failed(let reason):
            update(viewState.appending(lines: [.commandFailed(command: .pack, reason: reason, retry: typed)]))
        case .sessionExpired:
            expire(restoring: typed)
        case .cancelled:
            break
        }
    }

    private static func line(for rejection: BundleAPI.Rejection, name: String) -> TerminalViewState.Line {
        switch rejection {
        case .bundleNotFound: .bundleNotFound(name: name)
        case .notFound(let numbers): .notFound(numbers: numbers)
        case .invalidName(let problem): .bundleNameInvalid(problem)
        case .notInBundle(let numbers): .notInBundle(name: name, numbers: numbers)
        }
    }
}
