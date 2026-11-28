import FeatureTerminalInterface
import TerminalDomain
import GrepCore
import GrepData

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
            guard let self else { return }
            await handOff(viewState.selection, typed: typed, accessToken: token, clearsSelection: true, method: .pick)
        }
    }

    /// `넘기기 <묶음>`(ARC-003). 선택은 건드리지 않는다.
    /// 이벤트 `handoff_copied`의 method에 묶음 값이 아직 없어(api `EventRequest`) 보고하지 않는다.
    func handOffBundle(_ argument: String, typed: String) {
        if let problem = BundleCommand.problem(of: argument) {
            update(viewState.appending(lines: [.prompt(typed), .bundleNameInvalid(problem)]).with(input: ""))
            return
        }
        run(typed: typed) { [weak self] token in
            guard let self else { return }
            let outcome = await HandoffAPI.compose(bundle: argument, transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            await finishHandoff(
                outcome, typed: typed, accessToken: token, clearsSelection: false, method: nil, bundle: argument
            )
        }
    }

    /// `POST /handoff`로 받은 글을 그대로 클립보드에 넣는다. 화면 글자 수는 그 글과 함께 온 값이다(AC-13).
    /// 복사한 뒤에는 요약이 새로 와도 다시 복사하지 않는다(H-05).
    /// 선택한 자료를 넘기는 데 성공하면 선택을 푼다. 이어 쓰기는 선택을 건드리지 않고, 실패하면 선택을 남긴다(COM-008 규칙 5·8·9).
    /// 복사에 성공한 뒤에만 `POST /events`로 `handoff_copied`를 보고한다(결과를 기다리지 않고 실패해도 화면 그대로, #105).
    /// 서버는 넘긴 자료의 번호·제목만 주므로, 종류·출처는 `refs`에서 찾아 채운다(ARC-003 규칙 14).
    func handOff(
        _ refs: [ItemRef],
        typed: String,
        accessToken: String,
        clearsSelection: Bool = false,
        method: EventsAPI.Method = .pipe
    ) async {
        let numbers = refs.map(\.number)
        let outcome = await HandoffAPI.compose(numbers: numbers, transport: httpTransport, accessToken: accessToken)
        guard !Task.isCancelled else { return }
        await finishHandoff(
            outcome.resolvingKinds(from: refs),
            typed: typed, accessToken: accessToken, clearsSelection: clearsSelection, method: method
        )
    }

    /// `method`가 nil이면 이벤트를 보내지 않는다. `bundle`은 `넘기기 <묶음>`의 이름.
    private func finishHandoff(
        _ outcome: HandoffAPI.Outcome,
        typed: String,
        accessToken: String,
        clearsSelection: Bool,
        method: EventsAPI.Method?,
        bundle: String? = nil
    ) async {
        switch outcome {
        case .composed(let result):
            let copied = await clipboard.copy(result.text)
            guard !Task.isCancelled else { return }
            switch copied {
            case .copied:
                let next = clearsSelection ? viewState.with(selection: []) : viewState
                update(next.appending(lines: [.handedOff(result)]))
                let copiedNumbers = result.items.map(\.number)
                guard let method, !copiedNumbers.isEmpty else { return }
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
        case .bundleNotFound:
            update(viewState.appending(lines: [.bundleNotFound(name: bundle ?? "")]))
        case .failed(let reason):
            update(viewState.appending(lines: [.handoffFailed(reason: reason, preview: nil)]))
        case .sessionExpired:
            expire(restoring: typed)
        case .cancelled:
            break
        }
    }
}
