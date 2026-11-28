import FeatureTerminalInterface
import TerminalDomain
import GrepCore
import GrepData

// MARK: 터미널 기록(#68, COM-009)

extension TerminalInteractor {
    /// 남긴 기록을 되살린다. 같은 계정의 기록만 쓰고, 다른 계정의 기록은 지운다(규칙 3·4).
    /// 계정을 알기 전에는 남기지도 되살리지도 않는다.
    func restoreHistory() {
        startTask { [weak self] in
            guard let self else { return }
            let token = await authService.accessToken()
            guard !Task.isCancelled else { return }
            defer {
                isHistoryLoaded = true
                showWelcomeIfNeeded()
            }
            guard !isHistoryForgotten, let token, let subject = AccessTokenSubject.read(from: token) else { return }
            historySubject = subject
            guard let record = historyStore.load() else { return }
            guard record.subject == subject else {
                historyStore.clear()
                return
            }
            guard let saved = TerminalHistory.decode(record.payload) else { return }
            restore(saved)
            await dropMissingSelection(accessToken: token)
        }
    }

    /// 되살린 줄을 앞에 둔다. 기다리는 동안 사용자가 친 것이 있으면 덮지 않는다.
    private func restore(_ saved: TerminalHistory.Snapshot) {
        // 끊기기 전에 기다리던 확인은 취소된 것이다(COM-009 규칙 4, COM-007 규칙 7).
        // 다음 쪽을 받는 값은 남기지 않으므로 되살린 목록의 `→ 더 보기`는 뺀다.
        let closed = saved.lines.indices.reduce(TerminalViewState(lines: saved.lines)) { $0.closingList(at: $1) }
        let lines = closed.lines + (Self.isWaitingForAnswer(saved.lines) ? [.cancelled] : []) + viewState.lines
        update(
            TerminalViewState(
                itemCount: viewState.itemCount,
                lines: lines,
                input: viewState.input.isEmpty ? saved.input : viewState.input,
                selection: viewState.selection.isEmpty ? saved.selection : viewState.selection,
                isOffline: viewState.isOffline,
                mole: viewState.mole
            )
        )
    }

    /// 마지막 확인 줄 뒤에 답(명령 줄)도 취소도 없으면 아직 기다리던 것이다.
    private static func isWaitingForAnswer(_ lines: [TerminalViewState.Line]) -> Bool {
        guard let asked = lines.lastIndex(where: { if case .handoffConfirm = $0 { true } else { false } }) else {
            return false
        }
        return !lines[asked...].contains { line in
            switch line {
            case .prompt, .cancelled: true
            default: false
            }
        }
    }

    /// 되살린 선택에서 그새 지워진 자료(휴지통 포함)를 뺀다. 출력은 찍힌 그대로 둔다(규칙 6).
    /// 확인하지 못하면 그대로 둔다. 넘길 때 서버가 다시 거른다.
    private func dropMissingSelection(accessToken: String) async {
        let numbers = viewState.selection.map(\.number)
        guard !numbers.isEmpty else { return }
        let outcome = await BrowseAPI.statuses(of: numbers, transport: httpTransport, accessToken: accessToken)
        guard !Task.isCancelled, case .found(_, let missing) = outcome, !missing.isEmpty else { return }
        update(viewState.with(selection: viewState.selection.filter { !missing.contains($0.number) }))
    }

    /// 자료 0건이고 되살린 기록도 찍힌 줄도 없으면 첫 화면을 보인다(규칙 5).
    func showWelcomeIfNeeded() {
        guard isHistoryLoaded, viewState.itemCount == 0, viewState.lines.isEmpty else { return }
        update(viewState.appending(lines: [.welcome]))
    }

    /// 출력·치던 글·선택을 이 기기에 남긴다(규칙 1). 줄이 그대로면 줄의 JSON은 다시 만들지 않는다.
    func saveHistory() {
        guard let subject = historySubject else { return }
        let lines = viewState.lines
        let linesJSON = encodedLines.flatMap { $0.lines == lines ? $0.json : nil } ?? TerminalHistory.encodeLines(lines)
        encodedLines = (lines, linesJSON)
        let payload = TerminalHistory.payload(linesJSON: linesJSON, input: viewState.input, selection: viewState.selection)
        historyStore.save(HistoryRecord(subject: subject, payload: payload))
    }

    /// 로그아웃하면 이 기기의 기록을 지우고 더 남기지 않는다(규칙 2).
    func forgetHistory() {
        isHistoryForgotten = true
        historySubject = nil
        historyStore.clear()
    }
}
