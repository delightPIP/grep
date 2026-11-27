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
    case welcome = "첫 화면 (자료 0건 · 샘플 8건으로 해 보기)"
    case saved = "저장 완료 (링크)"
    case alreadySaved = "이미 저장됨 (중복)"
    case processing = "처리 중 (요약 생성 중)"
    case recentAndSearch = "최근·찾기 결과 (더 보기)"
    case noResults = "검색 0건 (최근 저장 안내)"
    case picked = "고르기 완료 (선택 2건)"
    case handedOff = "넘기기 완료 (미리보기 · 공유)"
    case handoffConfirm = "넘기기 5건 초과 확인 (23건)"
    case handoffDenied = "넘기기 실패 (클립보드 거부)"
    case guide = "도움말 (명령 16줄)"
    case droppedAndRevived = "버리기 1건 · 되살리기 결과"
    case dropConfirm = "버리기 2건 확인 시트 (실제 입력)"
    case binList = "휴지통 목록 (남은 날 · 다음 명령)"
    case pickThenUnpick = "고르기 3건 → 칩 빼기·모두 해제 (실제 입력)"
    case revise = "고치기 131 편집 칸 (실제 입력)"
    case removeTags = "고치기 131 -#가이드 태그 지우기 (실제 입력)"
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
        case .droppedAndRevived:
            currentScreen?.render(TerminalViewState(
                itemCount: 130,
                lines: [
                    .prompt("버리기 131"),
                    .dropped([ItemRef(number: 131, title: "결제위젯 연동 가이드")]),
                    .prompt("되살리기 131"),
                    .revived([ItemRef(number: 131, title: "결제위젯 연동 가이드")]),
                ]
            ))
        case .dropConfirm:
            // 코어가 확인 대기를 잡도록 실제 입력으로 보낸다. 시트의 `버리기`는 가짜 서버가 받는다.
            currentScreen?.listener?.handle(.submitted("버리기 131 118"))
        case .pickThenUnpick:
            // 선택 줄의 `×` 칩은 `고르기 빼기 <번호>`, `모두 해제`는 `고르기 비우기`를 친 것과 같다.
            currentScreen?.listener?.handle(.submitted("고르기 131 118 64"))
        case .revise:
            // 코어가 `/items/status`로 지금 값을 받아 편집 칸을 연다. 저장하면 가짜 서버가 `PATCH /items/131`을 받는다.
            currentScreen?.listener?.handle(.submitted("고치기 131"))
        case .removeTags:
            currentScreen?.listener?.handle(.submitted("고치기 131 -#가이드"))
        case .binList:
            let trashed = [(29, "주간 업무 메모.md", "md", 30), (21, "사무실 비품 주문 목록.txt", "txt", 12)]
            currentScreen?.render(TerminalViewState(
                itemCount: 129,
                lines: [
                    .prompt("휴지통"),
                    .binList(
                        total: 12,
                        items: trashed.map { number, title, source, daysLeft in
                            TrashEntry(
                                item: ItemSummary(
                                    number: number,
                                    kind: .file,
                                    title: title,
                                    source: source,
                                    status: .ready,
                                    tags: [],
                                    savedAt: "2026-11-20T01:00:00Z"
                                ),
                                trashedAt: "2026-11-27T01:00:00Z",
                                daysLeft: daysLeft
                            )
                        },
                        hasMore: true
                    ),
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
    private static let titles = [131: "결제위젯 연동 가이드", 118: "결제 실패 화면 모음.png"]

    func send(_ request: HTTPRequest) async throws(HTTPTransportError) -> HTTPResponse {
        switch (request.method, request.path) {
        case (.post, "/items/trash"), (.post, "/items/restore"):
            return HTTPResponse(status: 200, body: Array(Self.movedBody(for: request).utf8))
        case (.post, "/samples"):
            return HTTPResponse(status: 201, body: Array(#"{"firstNumber":1,"lastNumber":8}"#.utf8))
        case (.get, "/items?limit=8"):
            return HTTPResponse(status: 200, body: Self.encoded(SamplePage(items: Self.sampleItems(), total: 8, nextCursor: nil)))
        case (.get, "/items/status?numbers=131,118,64"):
            let picked = [(131, "결제위젯 연동 가이드"), (118, "결제 실패 화면 모음.png"), (64, "결제 UX 스레드 모음")].map {
                ItemSummary(number: $0.0, kind: .link, title: $0.1, source: nil, status: .ready, tags: [], savedAt: "2026-11-26T05:03:00Z")
            }
            return HTTPResponse(status: 200, body: Self.encoded(LookupBody(items: picked, missing: [])))
        case (.get, "/items/status?numbers=131"):
            return HTTPResponse(status: 200, body: Self.encoded(LookupBody(items: [Self.reviseItem()], missing: [])))
        case (.patch, "/items/131"):
            return HTTPResponse(status: 200, body: Self.encoded(Self.revisedItem(for: request)))
        default:
            return HTTPResponse(status: 200, body: Array(#"{"items":[],"total":0,"nextCursor":null}"#.utf8))
        }
    }

    private struct SamplePage: Encodable {
        let items: [ItemSummary]
        let total: Int
        let nextCursor: String?
    }

    /// 시안 15 Sample ①의 마케터 캠페인 이야기 7건과 사용법 1건(제목은 시안용 예시).
    private static func sampleItems() -> [ItemSummary] {
        let rows: [(String, String)] = [
            ("그렙 사용법: 담기 → 찾기 → 넘기기", "그렙"),
            ("카페 텀블러 할인, 올겨울 캠페인 늘었다", "가상 기사"),
            ("파란컵 텀블러 캠페인 캡처.png", "이미지"),
            ("겨울 음료 트렌드 보고서.pdf", "PDF"),
            ("경쟁사 굿즈 이벤트 정리", "메모"),
            ("인스타 캠페인 반응 모음", "가상 기사"),
            ("텀블러 지참 할인 매장 목록", "가상 기사"),
            ("캠페인 카피 초안", "글"),
        ]
        return rows.enumerated().map { index, row in
            ItemSummary(
                number: 8 - index,
                kind: .link,
                title: row.0,
                source: row.1,
                status: .ready,
                tags: [],
                savedAt: "2026-11-27T01:00:00Z"
            )
        }
    }

    private struct LookupBody: Encodable {
        let items: [ItemSummary]
        let missing: [Int]
    }

    private struct ReviseBody: Decodable {
        let title: String?
        let summary: String?
        let removeTags: [String]?
    }

    private static func reviseItem(
        title: String = "결제위젯 연동 가이드",
        summary: String = "웹·모바일 결제위젯 SDK 설치와 승인 흐름 정리",
        summarySource: SummarySource = .ai,
        tags: [String] = ["결제", "sdk", "가이드"]
    ) -> ItemSummary {
        ItemSummary(
            number: 131,
            kind: .link,
            title: title,
            source: "tosspayments",
            status: .ready,
            listSummary: summary,
            summarySource: summarySource,
            tags: tags,
            savedAt: "2026-11-26T05:03:00Z"
        )
    }

    /// `PATCH /items/131`을 받은 값대로 고친 자료. 요약을 고치면 `summarySource`가 `user`가 된다(ARC-004 규칙 1).
    private static func revisedItem(for request: HTTPRequest) -> ItemSummary {
        let body = request.body.flatMap { try? JSONDecoder().decode(ReviseBody.self, from: Data($0.utf8)) }
        let base = reviseItem()
        let removed = Set(body?.removeTags ?? [])
        return reviseItem(
            title: body?.title ?? base.title,
            summary: body?.summary ?? base.listSummary ?? "",
            summarySource: body?.summary == nil ? .ai : .user,
            tags: base.tags.filter { !removed.contains($0) }
        )
    }

    private static func encoded(_ value: some Encodable) -> [UInt8] {
        Array((try? JSONEncoder().encode(value)) ?? Data())
    }

    /// 받은 번호를 그대로 옮겼다고 답한다(api `ItemRefList`).
    private static func movedBody(for request: HTTPRequest) -> String {
        struct Numbers: Decodable { let numbers: [Int] }
        let numbers = request.body
            .flatMap { try? JSONDecoder().decode(Numbers.self, from: Data($0.utf8)) }?
            .numbers ?? []
        let items = numbers.map { number in
            let title = titles[number] ?? "자료 \(number)"
            return #"{"number":\#(number),"title":"\#(title)"}"#
        }
        return #"{"items":[\#(items.joined(separator: ","))]}"#
    }
}
