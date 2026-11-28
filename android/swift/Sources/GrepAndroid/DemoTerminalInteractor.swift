import FeatureLoggedOut
import FeatureLoggedOutAndroid
import FeatureLoggedOutInterface
import FeatureTerminalAndroid
import FeatureTerminalInterface
import GrepAndroidSupport
import GrepCore
import GrepCoreTesting
import RIBs
import RIBsAndroid

// MARK: - Terminal Demo Interactor (Testing 시나리오 12종)

@MainActor
final class DemoTerminalInteractor: PresentableInteractor<any TerminalPresentable>, TerminalPresentableListener {
    private let scenario: DemoTerminalScenario
    private let onEvent: (String) -> Void
    private var state: TerminalViewState
    private var nextNumber: Int = 142

    init(presenter: any TerminalPresentable, scenario: DemoTerminalScenario, onEvent: @escaping (String) -> Void) {
        self.scenario = scenario
        self.onEvent = onEvent
        self.state = Self.initialState(for: scenario)
        super.init(presenter: presenter)
        presenter.listener = self
    }

    override func didBecomeActive() {
        super.didBecomeActive()
        presenter.render(state)
        if scenario == .expired {
            onEvent("didExpire(input: \"찾기 결제\")")
        }
    }

    func handle(_ action: TerminalViewAction) {
        switch action {
        case .inputChanged(let text):
            state.input = text
        case .pasted(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            appendSave(trimmed)
            state.input = ""
        case .submitted(let raw):
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            state.input = ""
            runDemoCommand(text)
        case .moreRequested:
            state.lines.append(.recentList(items: [Self.sampleItems[2]], hasMore: false))
        case .samplesRequested, .reviseSubmitted, .reviseCancelled, .filesDropped:
            break
        }
        presenter.render(state)
    }

    private func runDemoCommand(_ text: String) {
        if text == "로그아웃" || text == "signout" {
            onEvent("didRequestSignOut()")
            return
        }
        state.lines.append(.prompt(text))
        if text == "앞10" || text == "전부" {
            let count = text == "앞10" ? 10 : max(state.selection.count, 23)
            let refs = (1...min(count, 3)).map { ItemRef(number: 130 + $0, title: "선택 자료 \($0)") }
            state.lines.append(.handedOff(HandoffResult(
                items: refs,
                charCount: count * 180,
                missingSummaryCount: 0,
                text: "# 그렙 넘기기 (\(count)건)\n\n요약 본문 미리보기"
            )))
            state.selection = []
        } else if text == "취소" {
            state.lines.append(.cancelled)
        } else if text == "최근" || text == "recent" {
            state.lines.append(.recentList(items: Self.sampleItems, hasMore: true))
        } else if text.hasPrefix("찾기 ") || text.hasPrefix("seek ") {
            let keyword = text.split(separator: " ", maxSplits: 1).dropFirst().first.map(String.init) ?? ""
            let query = SearchQuery(text: keyword, words: keyword, tags: [])
            let matched = Self.sampleItems.filter { $0.title.contains(keyword) || ($0.listSummary?.contains(keyword) ?? false) }
            if matched.isEmpty {
                state.lines.append(.noResults(query: query, recent: Array(Self.sampleItems.prefix(2))))
            } else {
                state.lines.append(.searchResult(query: query, total: matched.count, items: matched, hasMore: false))
            }
        } else if text.hasPrefix("고르기 ") || text.hasPrefix("pick ") {
            let tokens = text.split(separator: " ").dropFirst().map(String.init)
            var refs: [ItemRef] = []
            for token in tokens {
                guard let num = Int(token) else {
                    state.lines.append(.invalidNumber(token))
                    return
                }
                if let item = Self.sampleItems.first(where: { $0.number == num }) {
                    refs.append(ItemRef(number: item.number, title: item.title))
                } else {
                    state.lines.append(.notFound(numbers: [num]))
                    return
                }
            }
            for ref in refs where !state.selection.contains(ref) {
                state.selection.append(ref)
            }
            state.lines.append(.picked(state.selection))
        } else if text == "넘기기" || text == "handoff" {
            if state.selection.count > 5 {
                state.lines.append(.handoffConfirm(total: state.selection.count))
            } else if !state.selection.isEmpty {
                state.lines.append(.handedOff(HandoffResult(
                    items: state.selection,
                    charCount: 842,
                    missingSummaryCount: 0,
                    text: Self.sampleHandoffText
                )))
                state.selection = []
            } else {
                state.lines.append(.missingArgument(.pick))
            }
        } else if text == "도움말" || text == "guide" {
            state.lines.append(.guide)
        } else if text.hasPrefix("담기 ") || text.hasPrefix("keep ") || text.hasPrefix("http://") || text.hasPrefix("https://") {
            let payload = text.hasPrefix("담기 ") ? String(text.dropFirst(3))
                : (text.hasPrefix("keep ") ? String(text.dropFirst(5)) : text)
            appendSave(payload)
        } else {
            let first = text.split(separator: " ").first.map(String.init) ?? text
            state.lines.append(.unknownCommand(first))
        }
    }

    private func appendSave(_ payload: String) {
        let isLink = payload.hasPrefix("http://") || payload.hasPrefix("https://")
        let item = ItemSummary(
            number: nextNumber,
            kind: isLink ? .link : .text,
            title: isLink ? "새로 저장한 자료 #\(nextNumber)" : payload,
            source: isLink ? "example.com" : nil,
            status: .processing,
            blockedReason: nil,
            listSummary: nil,
            summarySource: nil,
            partialNote: nil,
            tags: [],
            matchedIn: nil,
            savedAt: "2026-11-27T14:30:00Z"
        )
        nextNumber += 1
        state.itemCount = (state.itemCount ?? 0) + 1
        state.processingCount += 1
        state.lines.append(.saved(item))
    }
}
