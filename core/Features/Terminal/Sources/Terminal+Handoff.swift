import FeatureTerminalInterface
import GrepCore

// MARK: 넘기기(#64), 실패(#65), 측정 이벤트(#105)

extension TerminalInteractor {
    /// `넘기기`. 고른 자료를 고른 순서대로 넘긴다. 고른 자료가 없으면 `✗ 선택한 자료 없음`.
    func handOffSelection(typed: String) {
        let numbers = viewState.selection.map(\.number)
        guard !numbers.isEmpty else {
            update(viewState.appending(lines: [.prompt(typed), .missingArgument(.handoff)]).with(input: ""))
            return
        }
        run(typed: typed) { [weak self] token in
            await self?.handOff(numbers, typed: typed, accessToken: token, clearsSelection: true, method: .pick)
        }
    }

    /// `POST /handoff`로 받은 글을 그대로 클립보드에 넣는다. 화면 글자 수는 그 글과 함께 온 값이다(AC-13).
    /// 복사한 뒤에는 요약이 새로 와도 다시 복사하지 않는다(H-05).
    /// 선택한 자료를 넘기는 데 성공하면 선택을 푼다. 이어 쓰기는 선택을 건드리지 않고, 실패하면 선택을 남긴다(COM-008 규칙 5·8·9).
    /// 복사에 성공한 뒤에만 `POST /events`로 `handoff_copied`를 보고한다(결과를 기다리지 않고 실패해도 화면 그대로, #105).
    func handOff(
        _ numbers: [Int],
        typed: String,
        accessToken: String,
        clearsSelection: Bool = false,
        method: EventsAPI.Method = .pipe
    ) async {
        let outcome = await HandoffAPI.compose(numbers: numbers, transport: httpTransport, accessToken: accessToken)
        guard !Task.isCancelled else { return }
        switch outcome {
        case .composed(let result):
            let copied = await clipboard.copy(result.text)
            guard !Task.isCancelled else { return }
            switch copied {
            case .copied:
                let next = clearsSelection ? viewState.with(selection: []) : viewState
                update(next.appending(lines: [.handedOff(result)]))
                let copiedNumbers = result.items.map(\.number)
                startTask { [weak self] in
                    guard let self else { return }
                    await EventsAPI.reportHandoffCopied(
                        numbers: copiedNumbers,
                        method: method,
                        transport: rawTransport,
                        accessToken: accessToken
                    )
                }
            // 넘길 글을 펼쳐 직접 복사하게 한다(COM-008 규칙 6).
            case .denied:
                update(viewState.appending(lines: [.handoffFailed(reason: .clipboardDenied, preview: result.text)]))
            }
        case .notFound(let missing):
            update(viewState.appending(lines: [.notFound(numbers: missing)]))
        case .failed(let reason):
            update(viewState.appending(lines: [.handoffFailed(reason: reason, preview: nil)]))
        case .sessionExpired:
            expire(restoring: typed)
        case .cancelled:
            break
        }
    }
}
