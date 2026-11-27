import FeatureTerminal
import FeatureTerminalAdapter
import FeatureTerminalInterface
import GrepCore
import GrepCoreTesting
import Observation
import RIBs
import RIBsSwiftUI
import SwiftUI

enum TerminalDemoScenario: String, CaseIterable, Identifiable {
    case welcome = "첫 화면 (자료 0건)"
    case saved = "저장 완료 (링크)"
    case alreadySaved = "이미 저장됨 (중복)"
    case processing = "처리 중 (요약 생성 중)"
    case recentAndSearch = "최근·찾기 결과 (더 보기)"
    case noResults = "검색 0건 (최근 저장 안내)"
    case picked = "고르기 완료 (선택 2건)"
    case handedOff = "넘기기 완료 (미리보기 · 공유)"
    case handoffConfirm = "넘기기 5건 초과 확인 (23건)"
    case handoffDenied = "넘기기 실패 (클립보드 거부)"
    case guide = "도움말 (명령 13줄)"
    case expired = "로그인 만료 이벤트"

    var id: String { rawValue }
}

/// 터미널 피처 단독 Example 앱. 시나리오 목록에서 항목을 고르면 전체 화면으로 피처를 띄운다.
@main
struct TerminalExampleApp: App {
    @State private var harness = TerminalExampleHarness()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    Section("시나리오") {
                        ForEach(TerminalDemoScenario.allCases) { scenario in
                            Button(scenario.rawValue) {
                                harness.launch(scenario)
                            }
                        }
                    }
                    Section("마지막 부모 이벤트") {
                        Text(harness.lastEvent)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("terminalExampleEvent")
                    }
                }
                .navigationTitle("Terminal Scenarios")
            }
            .fullScreenCover(item: $harness.activeScenario, onDismiss: { harness.stop() }) { _ in
                ZStack(alignment: .topTrailing) {
                    RIBSlotView(slot: harness.slot)
                    Button("닫기") {
                        harness.activeScenario = nil
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 54)
                    .padding(.trailing, 12)
                    .accessibilityIdentifier("closeScenarioButton")
                }
            }
        }
    }
}

@MainActor @Observable
final class TerminalExampleHarness: TerminalListener, TerminalDependency {
    let slot = RIBScreenSlot()
    var activeScenario: TerminalDemoScenario?
    private(set) var lastEvent = "부모 이벤트 없음"

    @ObservationIgnored let authService: any AuthService = FakeAuthService(token: fakeAccessToken(subject: "example-user"))
    @ObservationIgnored let httpTransport: any HTTPTransport = ExampleTerminalTransport()
    @ObservationIgnored let clipboard: any ClipboardPort = FakeClipboard()
    @ObservationIgnored let files: any FilePort = FakeFilePort()
    @ObservationIgnored let historyStore: any HistoryStore = FakeHistoryStore()
    @ObservationIgnored let sleeper: any Sleeper = FakeSleeper()

    @ObservationIgnored private let parent = TestParentRouter()
    @ObservationIgnored private var currentRouter: (any ViewableRouting)?
    @ObservationIgnored private var currentScreen: (any TerminalViewContract)?

    func launch(_ scenario: TerminalDemoScenario) {
        stop()
        let factory = CapturingTerminalFactory { [weak self] screen in
            self?.currentScreen = screen
        }
        let build = TerminalBuilder(dependency: self, viewFactory: factory).build(listener: self)
        parent.attach(build.router)
        slot.show(build.router.viewControllable)
        currentRouter = build.router
        apply(scenario)
        activeScenario = scenario
    }

    func stop() {
        if let router = currentRouter {
            parent.detach(router)
            slot.hide(router.viewControllable)
            currentRouter = nil
        }
        currentScreen = nil
    }

    private func apply(_ scenario: TerminalDemoScenario) {
        let readyItem = ItemSummary(
            number: 131,
            kind: .link,
            title: "결제위젯 연동 가이드",
            source: "tosspayments",
            status: .ready,
            listSummary: "웹·모바일 결제위젯 SDK 설치와 승인 흐름 정리",
            summarySource: .ai,
            tags: ["결제", "sdk", "가이드"],
            savedAt: "2026-11-26T05:03:00Z"
        )
        let imageItem = ItemSummary(
            number: 118,
            kind: .file,
            title: "결제 실패 화면 모음.png",
            source: "이미지",
            status: .ready,
            listSummary: "카드 한도 초과·네트워크 오류 토스트 비교",
            summarySource: .ai,
            tags: ["결제", "에러"],
            matchedIn: .imageText,
            savedAt: "2026-11-25T09:20:00Z"
        )
        let processingItem = ItemSummary(
            number: 132,
            kind: .link,
            title: "Swift 6 동시성 마이그레이션 노트",
            source: "swift.org",
            status: .processing,
            tags: [],
            savedAt: "2026-11-27T06:00:00Z"
        )
        let blockedItem = ItemSummary(
            number: 64,
            kind: .link,
            title: "결제 UX 스레드 모음",
            source: "threads.net",
            status: .blocked,
            blockedReason: .loginRequired,
            tags: ["결제"],
            savedAt: "2026-11-20T01:10:00Z"
        )

        switch scenario {
        case .welcome:
            currentScreen?.render(TerminalViewState(itemCount: 0, lines: [.welcome]))
        case .saved:
            currentScreen?.render(TerminalViewState(
                itemCount: 132,
                lines: [.prompt("담기 https://docs.tosspayments.com"), .saved(readyItem)]
            ))
        case .alreadySaved:
            currentScreen?.render(TerminalViewState(
                itemCount: 131,
                lines: [.prompt("담기 https://docs.tosspayments.com"), .alreadySaved(readyItem)]
            ))
        case .processing:
            currentScreen?.render(TerminalViewState(
                itemCount: 132,
                lines: [.prompt("담기 https://swift.org"), .saved(processingItem)],
                processingCount: 1
            ))
        case .recentAndSearch:
            currentScreen?.render(TerminalViewState(
                itemCount: 131,
                lines: [
                    .prompt("찾기 결제"),
                    .searchResult(
                        query: SearchQuery(text: "결제", words: "결제", tags: []),
                        total: 23,
                        items: [readyItem, imageItem, blockedItem],
                        hasMore: true
                    ),
                ]
            ))
        case .noResults:
            currentScreen?.render(TerminalViewState(
                itemCount: 131,
                lines: [
                    .prompt("찾기 없는키워드"),
                    .noResults(
                        query: SearchQuery(text: "없는키워드", words: "없는키워드", tags: []),
                        recent: [readyItem, imageItem]
                    ),
                ]
            ))
        case .picked:
            let refs = [
                ItemRef(number: 131, title: "결제위젯 연동 가이드"),
                ItemRef(number: 118, title: "결제 실패 화면 모음.png"),
            ]
            currentScreen?.render(TerminalViewState(
                itemCount: 131,
                lines: [
                    .prompt("찾기 결제"),
                    .searchResult(
                        query: SearchQuery(text: "결제", words: "결제", tags: []),
                        total: 3,
                        items: [readyItem, imageItem, blockedItem],
                        hasMore: false
                    ),
                    .prompt("고르기 131 118"),
                    .picked(refs),
                ],
                selection: refs
            ))
        case .handedOff:
            let refs = [
                ItemRef(number: 131, title: "결제위젯 연동 가이드"),
                ItemRef(number: 64, title: "결제 UX 스레드 모음"),
            ]
            let previewText = """
            [그렙 넘기기 · 2건]

            1. 결제위젯 연동 가이드 (tosspayments · 2026-11-26 14:03)
            요약: 웹·모바일 결제위젯 SDK 설치와 승인 흐름 정리

            2. 결제 UX 스레드 모음 (threads.net · 2026-11-20 10:10)
            요약: 없음 (본문 못 가져옴)
            """
            currentScreen?.render(TerminalViewState(
                itemCount: 131,
                lines: [
                    .prompt("넘기기"),
                    .handedOff(HandoffResult(
                        items: refs,
                        charCount: 1240,
                        missingSummaryCount: 1,
                        text: previewText
                    )),
                ]
            ))
        case .handoffConfirm:
            currentScreen?.render(TerminalViewState(
                itemCount: 131,
                lines: [
                    .prompt("찾기 디자인 | 넘기기"),
                    .handoffConfirm(total: 23),
                ]
            ))
        case .handoffDenied:
            currentScreen?.render(TerminalViewState(
                itemCount: 131,
                lines: [
                    .prompt("넘기기"),
                    .handoffFailed(
                        reason: .clipboardDenied,
                        preview: "1. 결제위젯 연동 가이드 (tosspayments)\n요약: 웹·모바일 결제위젯 SDK 설치와 승인 흐름 정리"
                    ),
                ],
                selection: [ItemRef(number: 131, title: "결제위젯 연동 가이드")]
            ))
        case .guide:
            currentScreen?.render(TerminalViewState(
                itemCount: 131,
                lines: [
                    .prompt("도움말"),
                    .guide,
                ]
            ))
        case .expired:
            didExpire(input: "찾기 결제")
        }
    }

    func didRequestSignOut() {
        lastEvent = "didRequestSignOut() 수신"
        activeScenario = nil
    }

    func didExpire(input: String) {
        lastEvent = "didExpire(input: \"\(input)\") 수신"
        activeScenario = nil
    }
}

@MainActor
private final class CapturingTerminalFactory: TerminalViewFactory {
    private let base = TerminalScreenFactory()
    private let onCreated: @MainActor (any TerminalViewContract) -> Void

    init(onCreated: @escaping @MainActor (any TerminalViewContract) -> Void) {
        self.onCreated = onCreated
    }

    func makeTerminalView() -> any TerminalViewContract {
        let screen = base.makeTerminalView()
        onCreated(screen)
        return screen
    }
}

@MainActor
private final class ExampleTerminalTransport: HTTPTransport {
    func send(_ request: HTTPRequest) async throws(HTTPTransportError) -> HTTPResponse {
        HTTPResponse(status: 200, body: Array(#"{"items":[],"total":0,"nextCursor":null}"#.utf8))
    }
}
