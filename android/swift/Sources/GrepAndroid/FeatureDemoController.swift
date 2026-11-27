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

/// 단독 실행 앱이 띄울 수 있는 피처. Kotlin demo 모듈이 이 문자열로 고른다.
public enum DemoFeature: String, CaseIterable, Sendable {
    case loggedOut
    case terminal
}

/// 단독 실행 앱에서 로그인 화면 시나리오를 고르기 위한 설정.
public enum DemoLoggedOutScenario: String, CaseIterable, Sendable {
    case initial
    case expired
    case signedOut
    case failDisconnected
    case failTimedOut
    case failDenied
    case cancelled
}

/// 단독 실행 앱에서 터미널 화면 시나리오를 고르기 위한 설정(iOS `TerminalExampleApp`과 1:1 대응).
public enum DemoTerminalScenario: String, CaseIterable, Sendable {
    case welcome
    case saved
    case alreadySaved
    case processing
    case recentAndSearch
    case noResults
    case picked
    case handedOff
    case handoffConfirm
    case handoffDenied
    case guide
    case expired
}

/// 피처 하나만 띄운다. 부모는 `TestParentRouter`가 맡고,
/// 부모에게 갈 이벤트는 루트 화면의 `event`로 보여 준다.
@MainActor
public final class FeatureDemoController: RibController {
    private let feature: DemoFeature
    private let scenarioName: String
    public let authService: any AuthService
    private let stack: RenderStack
    private let root: HostRootScreen
    private let parent = TestParentRouter()
    private var router: (any ViewableRouting)?

    public init(
        feature: DemoFeature,
        scenarioName: String = "initial",
        authService: (any AuthService)? = nil,
        sink: @escaping (String) -> Void
    ) {
        self.feature = feature
        self.scenarioName = scenarioName
        let loggedOutScenario = DemoLoggedOutScenario(rawValue: scenarioName) ?? .initial
        self.authService = authService ?? Self.makeAuthService(for: loggedOutScenario)
        stack = RenderStack(sink: sink)
        root = HostRootScreen(context: stack.context)
    }

    public convenience init(
        feature: DemoFeature,
        scenario: DemoLoggedOutScenario,
        authService: (any AuthService)? = nil,
        sink: @escaping (String) -> Void
    ) {
        self.init(feature: feature, scenarioName: scenario.rawValue, authService: authService, sink: sink)
    }

    public convenience init(
        feature: DemoFeature,
        terminalScenario: DemoTerminalScenario,
        sink: @escaping (String) -> Void
    ) {
        self.init(feature: feature, scenarioName: terminalScenario.rawValue, authService: nil, sink: sink)
    }

    public func start() {
        precondition(router == nil, "FeatureDemoController.start called twice without stop")
        stack.host.show(root)
        let child = build()
        parent.attach(child)
        root.showScreen(child.viewControllable)
        router = child
    }

    public func screen<Screen: AndroidScreen>(id: Int64, as type: Screen.Type) -> Screen? {
        stack.registry.screen(id: id, as: type)
    }

    public func stop() {
        guard let child = router else { return }
        parent.detach(child)
        root.hideScreen(child.viewControllable)
        stack.host.hide(root)
        router = nil
    }

    public var encodedTree: String { stack.renderer.encodedTree }

    private func build() -> any ViewableRouting {
        let context = stack.context
        switch feature {
        case .loggedOut:
            let scenario = DemoLoggedOutScenario(rawValue: scenarioName) ?? .initial
            let notice: LoggedOutViewState.Notice? = switch scenario {
            case .expired: .expired
            case .signedOut: .signedOut
            default: nil
            }
            return LoggedOutBuilder(dependency: self, viewFactory: LoggedOutAndroidViewFactory(context: context))
                .build(listener: self, notice: notice)
        case .terminal:
            let scenario = DemoTerminalScenario(rawValue: scenarioName) ?? .welcome
            let screen = TerminalAndroidViewFactory(context: context).makeTerminalView()
            let interactor = DemoTerminalInteractor(
                presenter: screen,
                scenario: scenario,
                onEvent: { [weak self] event in self?.root.showEvent(event) }
            )
            return DemoTerminalRouter(interactor: interactor, viewController: screen)
        }
    }

    private static func makeAuthService(for scenario: DemoLoggedOutScenario) -> any AuthService {
        let result: SignInResult = switch scenario {
        case .initial, .expired, .signedOut:
            .success
        case .failDisconnected:
            .failed(.disconnected)
        case .failTimedOut:
            .failed(.timedOut)
        case .failDenied:
            .failed(.denied)
        case .cancelled:
            .cancelled
        }
        return DemoAuthService(result: result)
    }
}

@MainActor
private final class DemoAuthService: AuthService {
    private let result: SignInResult
    private var token: String?

    init(result: SignInResult) {
        self.result = result
    }

    func signIn(_ provider: AuthProvider) async -> SignInResult {
        if result == .success {
            token = fakeAccessToken(subject: "demo-\(provider.rawValue)")
        }
        return result
    }

    func signOut() async {
        token = nil
    }

    func accessToken() async -> String? { token }
}

extension FeatureDemoController: LoggedOutDependency {}

extension FeatureDemoController: LoggedOutListener {
    public func didSignIn() { root.showEvent("didSignIn()") }
}

// MARK: - Terminal Demo Interactor (Testing 시나리오 12종)

@MainActor
private final class DemoTerminalRouter: ViewableRouter<DemoTerminalInteractor, any ViewControllable> {}

@MainActor
private final class DemoTerminalInteractor: PresentableInteractor<any TerminalPresentable>, TerminalPresentableListener {
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

    private static let sampleItems: [ItemSummary] = [
        ItemSummary(
            number: 131,
            kind: .link,
            title: "토스페이먼츠 웹훅 재시도 정책",
            source: "docs.tosspayments.com",
            status: .ready,
            blockedReason: nil,
            listSummary: "실패 시 1분·5분·30분 간격으로 최대 5회 재시도, 멱등키 필수",
            summarySource: .ai,
            partialNote: nil,
            tags: ["결제", "웹훅", "백엔드"],
            matchedIn: nil,
            savedAt: "2026-11-27T05:12:00Z"
        ),
        ItemSummary(
            number: 130,
            kind: .link,
            title: "Stripe Idempotency Keys 가이드",
            source: "docs.stripe.com",
            status: .ready,
            blockedReason: nil,
            listSummary: "24시간 동안 동일 키 요청의 첫 응답을 캐시해 중복 결제 방지",
            summarySource: .ai,
            partialNote: nil,
            tags: ["결제", "설계"],
            matchedIn: .imageText,
            savedAt: "2026-11-26T11:40:00Z"
        ),
        ItemSummary(
            number: 129,
            kind: .link,
            title: "사내 위키 결제 장애 회고",
            source: "wiki.internal",
            status: .blocked,
            blockedReason: .loginRequired,
            listSummary: nil,
            summarySource: nil,
            partialNote: nil,
            tags: ["결제"],
            matchedIn: nil,
            savedAt: "2026-11-25T09:05:00Z"
        ),
    ]

    private static let sampleHandoffText = """
        [131] 토스페이먼츠 웹훅 재시도 정책 (docs.tosspayments.com · 2026-11-27 14:12)
        실패 시 1분·5분·30분 간격으로 최대 5회 재시도, 멱등키 필수

        [130] Stripe Idempotency Keys 가이드 (docs.stripe.com · 2026-11-26 20:40)
        24시간 동안 동일 키 요청의 첫 응답을 캐시해 중복 결제 방지
        """

    private static func initialState(for scenario: DemoTerminalScenario) -> TerminalViewState {
        let refs = [
            ItemRef(number: 131, title: "토스페이먼츠 웹훅 재시도 정책"),
            ItemRef(number: 130, title: "Stripe Idempotency Keys 가이드"),
        ]
        switch scenario {
        case .welcome:
            return TerminalViewState(itemCount: 0, lines: [.welcome])
        case .saved:
            return TerminalViewState(
                itemCount: 14,
                lines: [
                    .prompt("담기 https://docs.tosspayments.com/webhooks"),
                    .saved(sampleItems[0]),
                ]
            )
        case .alreadySaved:
            return TerminalViewState(
                itemCount: 14,
                lines: [
                    .prompt("담기 https://docs.tosspayments.com/webhooks"),
                    .alreadySaved(sampleItems[0]),
                ]
            )
        case .processing:
            let processingItem = ItemSummary(
                number: 141,
                kind: .link,
                title: "Android Swift SDK 6.4 릴리스 노트",
                source: "swift.org",
                status: .processing,
                blockedReason: nil,
                listSummary: nil,
                summarySource: nil,
                partialNote: nil,
                tags: [],
                matchedIn: nil,
                savedAt: "2026-11-27T14:20:00Z"
            )
            return TerminalViewState(
                itemCount: 15,
                lines: [
                    .prompt("담기 https://swift.org/blog/android-6-4"),
                    .saved(processingItem),
                ],
                processingCount: 1
            )
        case .recentAndSearch:
            return TerminalViewState(
                itemCount: 23,
                lines: [
                    .prompt("최근"),
                    .recentList(items: sampleItems, hasMore: true),
                    .prompt("찾기 결제"),
                    .searchResult(
                        query: SearchQuery(text: "결제", words: "결제", tags: []),
                        total: 12,
                        items: Array(sampleItems.prefix(2)),
                        hasMore: true
                    ),
                ]
            )
        case .noResults:
            return TerminalViewState(
                itemCount: 14,
                lines: [
                    .prompt("찾기 쿠버네티스"),
                    .noResults(
                        query: SearchQuery(text: "쿠버네티스", words: "쿠버네티스", tags: []),
                        recent: Array(sampleItems.prefix(2))
                    ),
                ]
            )
        case .picked:
            return TerminalViewState(
                itemCount: 23,
                lines: [
                    .prompt("최근"),
                    .recentList(items: sampleItems, hasMore: false),
                    .prompt("고르기 131 130"),
                    .picked(refs),
                ],
                selection: refs
            )
        case .handedOff:
            return TerminalViewState(
                itemCount: 23,
                lines: [
                    .prompt("넘기기"),
                    .handedOff(HandoffResult(
                        items: refs,
                        charCount: 1248,
                        missingSummaryCount: 1,
                        text: sampleHandoffText
                    )),
                ]
            )
        case .handoffConfirm:
            return TerminalViewState(
                itemCount: 23,
                lines: [
                    .prompt("넘기기"),
                    .handoffConfirm(total: 23),
                ],
                selection: refs
            )
        case .handoffDenied:
            return TerminalViewState(
                itemCount: 23,
                lines: [
                    .prompt("넘기기"),
                    .handoffFailed(reason: .clipboardDenied, preview: sampleHandoffText),
                ],
                selection: refs
            )
        case .guide:
            return TerminalViewState(
                itemCount: 23,
                lines: [
                    .prompt("도움말"),
                    .guide,
                ]
            )
        case .expired:
            return TerminalViewState(
                itemCount: 23,
                lines: [.prompt("찾기 결제")],
                input: "찾기 결제"
            )
        }
    }
}
