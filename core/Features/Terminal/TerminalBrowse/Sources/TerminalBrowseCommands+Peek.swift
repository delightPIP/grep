import TerminalDomain
import GrepCore
import GrepData
import TerminalCommandKit
import TerminalDomain

// MARK: 열기(#131, ARC-011)

extension TerminalBrowseCommands {
    /// `열기 <번호>`. 번호는 하나만 받는다(규칙 2). 선택은 바꾸지 않는다(규칙 12).
    /// 터미널 출력 블록은 연 때 모습 그대로 두므로 폴링으로 고치지 않는다(규칙 9).
    public func peek(_ argument: String, typed: String) {
        switch PickCommand.parse(argument) {
        case .numbers(let numbers) where numbers.count == 1:
            openDetail(numbers[0], typed: typed)
        case .numbers, .unpick, .clear, .missingUnpickNumbers:
            update(viewState.appending(lines: [.prompt(typed), .oneNumberOnly(.peek)]).with(input: ""))
        case .missingArgument:
            update(viewState.appending(lines: [.prompt(typed), .missingArgument(.peek)]).with(input: ""))
        case .invalidNumber(let input):
            update(viewState.appending(lines: [.prompt(typed), .invalidNumber(input)]).with(input: ""))
        }
    }

    private func openDetail(_ number: Int, typed: String) {
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await ItemDetailAPI.fetch(number: number, transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .detail(let detail):
                update(viewState.appending(lines: [.itemDetail(detail)]))
            case .notFound(let numbers):
                update(viewState.appending(lines: [.notFound(numbers: numbers)]))
            case .failed(let reason):
                update(viewState.appending(lines: [.commandFailed(command: .peek, reason: reason, retry: typed)]))
            case .sessionExpired:
                expire(restoring: typed)
            case .cancelled:
                break
            }
        }
    }
}
