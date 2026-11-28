import FeatureTerminalAndroid
import FeatureTerminalInterface
import Foundation
import GrepCore
import Testing

struct TerminalEncoderFeatureTests {
    private static let item = ItemSummary(
        number: 7, kind: .link, title: "결제 가이드", source: "a.com",
        status: .ready, listSummary: "요약", summarySource: .user, tags: ["결제"], savedAt: "2026-11-26T05:03:00Z"
    )
    private static let ref = ItemRef(number: 7, title: "결제 가이드")

    /// 코어가 만드는 피처 줄 40가지. 하나라도 빠지면 Android 화면에서 사라진다.
    private static let featureLines: [TerminalViewState.Line] = [
        .dropConfirm(total: 3), .dropped([ref]), .revived([ref]),
        .binList(total: 1, items: [TrashEntry(item: item, trashedAt: "2026-11-26T05:03:00Z", daysLeft: 29)], hasMore: false),
        .binEmptyConfirm(total: 2), .binEmptied(count: 2),
        .revised(item), .tagsRemoved(item: item, tags: ["결제"]),
        .samplesSaved(firstNumber: 1, lastNumber: 8, items: [item]),
        .unpicked(items: [ref], remaining: 0), .pickCleared(count: 2),
        .signOutEverywhereConfirm(connectionCount: 2),
        .bundleList([BundleEntry(name: "발표", count: 3)]),
        .bundleAdded(name: "발표", count: 3, alreadyCount: 1),
        .bundleView(name: "발표", total: 3, items: [item], hasMore: true),
        .bundleNotFound(name: "없음"), .bundleUnpicked(name: "발표", remaining: 2),
        .notInBundle(name: "발표", numbers: [9]), .bundleDeleteConfirm(name: "발표", itemCount: 3),
        .bundleDeleted(name: "발표"), .bundleNameInvalid(.reserved), .folderHint,
        .itemDetail(
            ItemDetail(
                item: item, url: "https://a.com/x", handoffSummary: "넘길 요약", allTags: ["결제"], bundles: ["발표"],
                bodyLength: 1234, body: "본문", bodyFromImage: false, originalUrl: nil, previewUrl: nil
            )
        ),
        .oneNumberOnly(.peek),
        .searchSaved(query: "결제", total: 4, already: false),
        .savedSearchList([SavedSearchEntry(query: "결제", count: 4)]),
        .savedSearchPeriod(period: "지난달", suggestion: "찾아두기 결제"),
        .savedSearchTooLong, .savedSearchDeleteConfirm(query: "결제"), .savedSearchDeleted(query: "결제"),
        .savedSearchNotFound(query: "결제"),
        .connectionList(
            mcpUrl: "https://grep.example/mcp",
            connections: [ConnectionEntry(number: 1, client: "Claude", connectedAt: "2026-11-20T00:00:00Z", lastReadAt: nil)]
        ),
        .disconnectConfirm(number: 1, client: "Claude"), .disconnected(client: "Claude", already: false),
        .connectionNotFound(number: 9), .connectionEnded(client: "Claude", reason: .expired),
        .importPrompt, .importProgress(done: 3, total: 10),
        .importFinished(saved: 8, skipped: 1, failed: 1, overLimit: 0, failedUrls: ["https://x"]),
        .importSuggest(fileName: "bookmarks.html"),
    ]

    private func encodedLines(_ lines: [TerminalViewState.Line]) throws -> [[String: Any]] {
        let json = TerminalStateEncoder.encode(TerminalViewState(lines: lines))
        let root = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        return try #require(root["lines"] as? [[String: Any]])
    }

    @Test
    func 피처줄40가지가있을때_인코딩하면_한줄도빠지지않는지() throws {
        // given
        let lines = Self.featureLines

        // when
        let encoded = try encodedLines(lines)

        // then
        #expect(lines.count == 40)
        #expect(encoded.count == 40)
        #expect(Set(encoded.compactMap { $0["kind"] as? String }).count == 40)
    }

    @Test
    func 휴지통목록과자세히보기일때_인코딩하면_남은날과본문값이담기는지() throws {
        // given
        let lines = [Self.featureLines[3], Self.featureLines[22]]

        // when
        let encoded = try encodedLines(lines)

        // then
        let trash = try #require((encoded[0]["trash"] as? [[String: Any]])?.first)
        #expect(trash["daysLeft"] as? Int == 29)
        let detail = try #require(encoded[1]["detail"] as? [String: Any])
        #expect(detail["bodyLength"] as? Int == 1234)
        #expect(detail["url"] as? String == "https://a.com/x")
        #expect((detail["item"] as? [String: Any])?["summarySource"] as? String == "user")
    }

    @Test
    func 고르기빼기를번호없이쳤을때_인코딩하면_하위명령이담기는지() throws {
        // given
        let lines: [TerminalViewState.Line] = [.missingArgument(.pick, sub: .unpick)]

        // when
        let encoded = try encodedLines(lines)

        // then
        #expect(encoded[0]["sub"] as? String == "unpick")
    }
}
