import FeatureTerminalInterface
import TerminalDomain
import GrepCore
import GrepData

// MARK: 샘플 8건 저장(#102, ARC-010)

extension TerminalInteractor {
    func saveSamples() {
        guard !isSavingSamples else { return }
        isSavingSamples = true
        startTask { [weak self] in
            guard let self else { return }
            defer { isSavingSamples = false }
            let token = await authService.accessToken()
            guard !Task.isCancelled else { return }
            guard let token else {
                expire()
                return
            }
            let outcome = await SamplesAPI.save(transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .saved(let firstNumber, let lastNumber, let created):
                let count = max(1, lastNumber - firstNumber + 1)
                let recentOutcome = await BrowseAPI.recent(
                    limit: count, cursor: nil, transport: httpTransport, accessToken: token
                )
                guard !Task.isCancelled else { return }
                let items: [ItemSummary]
                switch recentOutcome {
                case .page(let fetched, _, _): items = fetched
                case .sessionExpired:
                    expire()
                    return
                case .failed, .cancelled: items = []
                }
                let nextCount: Int?
                if created {
                    nextCount = (viewState.itemCount ?? 0) + count
                } else {
                    nextCount = viewState.itemCount.map { max($0, count) } ?? count
                }
                update(
                    viewState
                        .with(itemCount: nextCount)
                        .appending(lines: [.samplesSaved(firstNumber: firstNumber, lastNumber: lastNumber, items: items)])
                )
            case .failed(let reason):
                update(viewState.appending(lines: [.commandFailed(command: .keep, reason: reason, retry: "샘플")]))
            case .sessionExpired:
                expire()
            case .cancelled:
                break
            }
        }
    }
}
