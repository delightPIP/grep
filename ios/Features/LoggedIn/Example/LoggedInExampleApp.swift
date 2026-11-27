import FeatureLoggedInAdapter
import FeatureLoggedInUI
import FeatureTerminal
import FeatureTerminalAdapter
import FeatureTerminalInterface
import GrepCore
import GrepCoreTesting
import Observation
import RIBs
import RIBsSwiftUI
import SwiftUI

enum LoggedInDemoScenario: String, CaseIterable, Identifiable {
    case fullTabs = "전체 3탭 · 터미널 시작 (보관함 25건)"
    case archiveWithItems = "보관함 바로 보기 · 자료 있음 (더 보기)"
    case archiveEmpty = "보관함 · 자료 0건"
    case archiveOfflineThenRecover = "보관함 · 연결 끊김 (다시 시도 복구)"
    case settingsSignOut = "설정 바로 보기 · 로그아웃 확인"

    var id: String { rawValue }
}

/// 하단 탭(터미널·보관함·설정) 단독 Example 앱. 시나리오를 고르면 전체 화면으로 띄운다.
@main
struct LoggedInExampleApp: App {
    @State private var harness = LoggedInExampleHarness()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    Section("시나리오") {
                        ForEach(LoggedInDemoScenario.allCases) { scenario in
                            Button(scenario.rawValue) {
                                harness.launch(scenario)
                            }
                        }
                    }
                    Section("마지막 이벤트") {
                        Text(harness.lastEvent)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("loggedInExampleEvent")
                    }
                }
                .navigationTitle("LoggedIn Tabs")
            }
            .fullScreenCover(item: $harness.activeScenario, onDismiss: { harness.stop() }) { _ in
                ZStack(alignment: .topTrailing) {
                    if let tabsModel = harness.tabsModel {
                        LoggedInTabsView(
                            model: tabsModel,
                            hidesTabBar: harness.isKeyboardVisible
                        ) {
                            RIBSlotView(slot: harness.terminalSlot)
                        }
                    }
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
final class LoggedInExampleHarness: TerminalListener, TerminalDependency {
    let terminalSlot = RIBScreenSlot()
    var activeScenario: LoggedInDemoScenario?
    var tabsModel: LoggedInTabsModel?
    var isKeyboardVisible = false
    private(set) var lastEvent = "이벤트 없음"

    @ObservationIgnored let authService: any AuthService = FakeAuthService(token: fakeAccessToken(subject: "example-user"))
    @ObservationIgnored let httpTransport: any HTTPTransport = ExampleNoopTransport()
    @ObservationIgnored let clipboard: any ClipboardPort = FakeClipboard()
    @ObservationIgnored let files: any FilePort = FakeFilePort()
    @ObservationIgnored let historyStore: any HistoryStore = FakeHistoryStore()
    @ObservationIgnored let sleeper: any Sleeper = FakeSleeper()

    @ObservationIgnored private let parent = TestParentRouter()
    @ObservationIgnored private var currentRouter: (any ViewableRouting)?
    @ObservationIgnored private var pickedNumbers: Set<Int> = []

    func launch(_ scenario: LoggedInDemoScenario) {
        stop()
        pickedNumbers = []
        isKeyboardVisible = false

        let initialTab: LoggedInTab
        let loader: any ArchiveItemLoader
        let initialItemCount: Int?

        switch scenario {
        case .fullTabs:
            initialTab = .terminal
            loader = ExampleArchiveLoader(mode: .paginated(Self.sampleItems(count: 25)))
            initialItemCount = 25
        case .archiveWithItems:
            initialTab = .archive
            loader = ExampleArchiveLoader(mode: .paginated(Self.sampleItems(count: 25)))
            initialItemCount = 25
        case .archiveEmpty:
            initialTab = .archive
            loader = ExampleArchiveLoader(mode: .empty)
            initialItemCount = 0
        case .archiveOfflineThenRecover:
            initialTab = .archive
            loader = ExampleArchiveLoader(mode: .failOnceThenPaginated(.disconnected, Self.sampleItems(count: 6)))
            initialItemCount = nil
        case .settingsSignOut:
            initialTab = .settings
            loader = ExampleArchiveLoader(mode: .paginated(Self.sampleItems(count: 6)))
            initialItemCount = 6
        }

        let model = LoggedInTabsModel(
            archiveLoader: loader,
            initialTab: initialTab,
            pageLimit: 20,
            onSignOut: { [weak self] in
                self?.didRequestSignOut()
            },
            onPickItem: { [weak self] number in
                guard let self else { return }
                if pickedNumbers.contains(number) {
                    pickedNumbers.remove(number)
                } else {
                    pickedNumbers.insert(number)
                }
                tabsModel?.updateTerminalContext(itemCount: initialItemCount, pickedNumbers: pickedNumbers)
                lastEvent = "보관함 선택 토글: \(number)번 (선택 \(pickedNumbers.count)건)"
            },
            onClearPicked: { [weak self] in
                guard let self else { return }
                pickedNumbers.removeAll()
                tabsModel?.updateTerminalContext(itemCount: initialItemCount, pickedNumbers: [])
                lastEvent = "보관함 선택 모두 해제"
            },
            onSessionExpired: { [weak self] in
                self?.didExpire(input: "")
            }
        )
        model.updateTerminalContext(itemCount: initialItemCount, pickedNumbers: [])
        self.tabsModel = model

        let factory = TerminalScreenFactory { [weak self] terminalView, context in
            AnyView(
                terminalView
                    .onChange(of: context.isKeyboardVisible.wrappedValue) { _, visible in
                        self?.isKeyboardVisible = visible
                    }
                    .onChange(of: model.terminalScrollToBottomTrigger) { _, newValue in
                        context.scrollToBottomTrigger.wrappedValue = newValue
                    }
            )
        }
        let build = TerminalBuilder(dependency: self, viewFactory: factory).build(listener: self)
        parent.attach(build.router)
        terminalSlot.show(build.router.viewControllable)
        currentRouter = build.router

        activeScenario = scenario
    }

    func stop() {
        if let router = currentRouter {
            parent.detach(router)
            terminalSlot.hide(router.viewControllable)
            currentRouter = nil
        }
        tabsModel = nil
        isKeyboardVisible = false
    }

    func didRequestSignOut() {
        lastEvent = "로그아웃 완료 (didRequestSignOut 수신)"
        activeScenario = nil
    }

    func didExpire(input: String) {
        lastEvent = "로그인 만료 (didExpire 수신)"
        activeScenario = nil
    }

    private static func sampleItems(count: Int) -> [ItemSummary] {
        let base: [ItemSummary] = [
            ItemSummary(
                number: 132,
                kind: .link,
                title: "Swift 6 동시성 마이그레이션 노트",
                source: "swift.org",
                status: .processing,
                tags: [],
                savedAt: "2026-11-27T06:00:00Z"
            ),
            ItemSummary(
                number: 131,
                kind: .link,
                title: "결제위젯 연동 가이드",
                source: "tosspayments",
                status: .ready,
                listSummary: "웹·모바일 결제위젯 SDK 설치와 승인 흐름 정리",
                summarySource: .ai,
                tags: ["결제", "sdk", "가이드", "초과태그"],
                savedAt: "2026-11-26T05:03:00Z"
            ),
            ItemSummary(
                number: 118,
                kind: .file,
                title: "결제 실패 화면 모음.png",
                source: "이미지",
                status: .ready,
                listSummary: "카드 한도 초과·네트워크 오류 토스트 비교",
                summarySource: .ai,
                tags: ["결제", "에러"],
                savedAt: "2026-11-25T09:20:00Z"
            ),
            ItemSummary(
                number: 99,
                kind: .text,
                title: "발표 데모에서 보여 줄 핵심 시나리오 메모 한 줄 요약 정리",
                source: nil,
                status: .ready,
                listSummary: "담기 → 찾기 → 고르기 → 넘기기 흐름 점검",
                summarySource: .user,
                tags: ["발표", "메모"],
                savedAt: "2026-11-24T12:15:00Z"
            ),
            ItemSummary(
                number: 64,
                kind: .link,
                title: "결제 UX 스레드 모음",
                source: "threads.net",
                status: .blocked,
                blockedReason: .loginRequired,
                tags: ["결제"],
                savedAt: "2026-11-20T01:10:00Z"
            ),
            ItemSummary(
                number: 42,
                kind: .file,
                title: "2026-아키텍처-회고.pdf",
                source: "PDF",
                status: .failed,
                tags: ["아키텍처"],
                savedAt: "2026-11-18T08:00:00Z"
            ),
        ]

        guard count > base.count else {
            return Array(base.prefix(count))
        }

        var result = base
        for offset in base.count..<count {
            let number = 40 - (offset - base.count)
            result.append(
                ItemSummary(
                    number: max(1, number),
                    kind: .link,
                    title: "참고 자료 #\(max(1, number))",
                    source: "docs.example.com",
                    status: .ready,
                    listSummary: "보관함 페이지네이션 확인용 샘플 요약입니다.",
                    summarySource: .ai,
                    tags: ["샘플", "보관함"],
                    savedAt: "2026-11-10T03:00:00Z"
                )
            )
        }
        return result
    }
}

@MainActor
private final class ExampleArchiveLoader: ArchiveItemLoader {
    enum Mode {
        case empty
        case paginated([ItemSummary])
        case failOnceThenPaginated(ArchiveLoadFailure, [ItemSummary])
    }

    private let mode: Mode
    private var attempt = 0

    init(mode: Mode) {
        self.mode = mode
    }

    func loadPage(limit: Int, cursor: String?) async -> ArchivePageOutcome {
        try? await Task.sleep(for: .milliseconds(250))
        attempt += 1

        switch mode {
        case .empty:
            return .page(items: [], nextCursor: nil)
        case .paginated(let items):
            return slice(items: items, limit: limit, cursor: cursor)
        case .failOnceThenPaginated(let failure, let items):
            if attempt == 1 && cursor == nil {
                return .failed(failure)
            }
            return slice(items: items, limit: limit, cursor: cursor)
        }
    }

    private func slice(items: [ItemSummary], limit: Int, cursor: String?) -> ArchivePageOutcome {
        let start = cursor.flatMap(Int.init) ?? 0
        guard start < items.count else {
            return .page(items: [], nextCursor: nil)
        }
        let end = min(start + limit, items.count)
        let next = end < items.count ? String(end) : nil
        return .page(items: Array(items[start..<end]), nextCursor: next)
    }
}

@MainActor
private final class ExampleNoopTransport: HTTPTransport {
    func send(_ request: HTTPRequest) async throws(HTTPTransportError) -> HTTPResponse {
        HTTPResponse(status: 200, body: Array(#"{"items":[],"total":0,"nextCursor":null}"#.utf8))
    }
}
