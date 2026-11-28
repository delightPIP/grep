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

extension DemoTerminalInteractor {
    static let sampleItems: [ItemSummary] = [
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

    static let sampleHandoffText = """
        [131] 토스페이먼츠 웹훅 재시도 정책 (docs.tosspayments.com · 2026-11-27 14:12)
        실패 시 1분·5분·30분 간격으로 최대 5회 재시도, 멱등키 필수

        [130] Stripe Idempotency Keys 가이드 (docs.stripe.com · 2026-11-26 20:40)
        24시간 동안 동일 키 요청의 첫 응답을 캐시해 중복 결제 방지
        """

    static func initialState(for scenario: DemoTerminalScenario) -> TerminalViewState {
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
        case .cleanupLines:
            return TerminalViewState(itemCount: 23, lines: cleanupLines(refs: refs))
        case .bundleLines:
            return TerminalViewState(itemCount: 23, lines: bundleLines)
        case .detailLines:
            return TerminalViewState(itemCount: 23, lines: detailLines)
        }
    }

    static func cleanupLines(refs: [ItemRef]) -> [TerminalViewState.Line] {
        let trash = [TrashEntry(item: sampleItems[1], trashedAt: "2026-11-27T00:00:00Z", daysLeft: 29)]
        return [
            .prompt("버리기 131 130"), .dropConfirm(total: 2),
            .prompt("버리기"), .dropped(refs),
            .prompt("휴지통"), .binList(total: 1, items: trash, hasMore: false),
            .prompt("되살리기 131"), .revived([refs[0]]),
            .prompt("휴지통 비우기"), .binEmptyConfirm(total: 1),
            .prompt("비우기"), .binEmptied(count: 1),
            .prompt("고치기 131"), .revised(sampleItems[0]),
            .tagsRemoved(item: sampleItems[0], tags: ["웹훅"]),
            .prompt("고르기 빼기 131"), .unpicked(items: [refs[0]], remaining: 1),
            .prompt("고르기 비우기"), .pickCleared(count: 1),
            .prompt("로그아웃 모든기기"), .signOutEverywhereConfirm(connectionCount: 2),
        ]
    }

    static let bundleLines: [TerminalViewState.Line] = [
        .prompt("묶음"), .bundleList([BundleEntry(name: "결제", count: 3), BundleEntry(name: "발표", count: 5)]),
        .prompt("묶음 결제"), .bundleAdded(name: "결제", count: 3, alreadyCount: 1),
        .prompt("묶음 결제 보기"), .bundleView(name: "결제", total: 3, items: Array(sampleItems.prefix(2)), hasMore: true),
        .prompt("묶음 없는것"), .bundleNotFound(name: "없는것"),
        .prompt("묶음 결제 빼기 131"), .bundleUnpicked(name: "결제", remaining: 2), .notInBundle(name: "결제", numbers: [99]),
        .prompt("묶음 결제 지우기"), .bundleDeleteConfirm(name: "결제", itemCount: 3), .bundleDeleted(name: "결제"),
        .prompt("묶음 123"), .bundleNameInvalid(.reserved),
        .prompt("폴더"), .folderHint,
        .prompt("찾아두기 결제"), .searchSaved(query: "결제", total: 4, already: false),
        .prompt("찾아두기"), .savedSearchList([SavedSearchEntry(query: "결제", count: 4)]),
        .prompt("찾아두기 결제 지난달"), .savedSearchPeriod(period: "지난달", suggestion: "찾아두기 결제"),
        .prompt("찾아두기 결제 지우기"), .savedSearchDeleteConfirm(query: "결제"), .savedSearchDeleted(query: "결제"),
    ]

    static var detailLines: [TerminalViewState.Line] {
        let detail = ItemDetail(
            item: sampleItems[0], url: "https://docs.tosspayments.com/webhooks", handoffSummary: "웹훅 재시도 간격과 횟수 정리",
            allTags: ["결제", "웹훅"], bundles: ["결제"], bodyLength: 4210, body: "웹훅은 실패하면 최대 7회 재시도한다…",
            bodyFromImage: false, originalUrl: nil, previewUrl: nil
        )
        return [
            .prompt("열기 131"), .itemDetail(detail),
            .prompt("열기 131 130"), .oneNumberOnly(.peek),
            .prompt("연결"), .connectionList(
                mcpUrl: "https://grep.example/mcp",
                connections: [ConnectionEntry(number: 1, client: "Claude", connectedAt: "2026-11-20T00:00:00Z", lastReadAt: nil)]
            ),
            .prompt("연결 끊기 1"), .disconnectConfirm(number: 1, client: "Claude"), .disconnected(client: "Claude", already: false),
            .connectionEnded(client: "ChatGPT", reason: .expired),
            .prompt("가져오기"), .importPrompt, .importProgress(done: 40, total: 120),
            .importFinished(saved: 110, skipped: 8, failed: 2, overLimit: 0, failedUrls: ["https://old.example/a"]),
        ]
    }
}
