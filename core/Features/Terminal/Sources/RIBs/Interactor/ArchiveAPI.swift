import FeatureTerminalInterface
import GrepCore
import GrepData

/// 보관함 API(api/openapi.yaml `listAutoGroups`·`listRecentItems`·`getBundle`·`searchItems`). 응답 해석까지만 한다.
enum ArchiveAPI {
    enum Outcome<Value: Equatable>: Equatable {
        case success(Value)
        case sessionExpired
        case failed
        case cancelled
    }

    struct Page: Equatable {
        let items: [ItemSummary]
        let nextCursor: String?
    }

    static let pageSize = 20
    private static let groupsPath = "/groups"

    private struct GroupsBody: Decodable {
        struct Count: Decodable {
            let key: String
            let count: Int
        }

        let kinds: [Count]
        let sources: [Count]
        let periods: [Count]
        let tags: [Count]
    }

    /// 자동 묶음. 0건은 뺀다(ARC-007). `tz`는 기기 시간대(IANA).
    @MainActor
    static func groups(timeZone: String, transport: any HTTPTransport, accessToken: String) async -> Outcome<[AutoGroupEntry]> {
        let path = "\(groupsPath)?tz=\(BrowseAPI.percentEncoded(timeZone))"
        switch await BrowseAPI.get(path, as: GroupsBody.self, transport: transport, accessToken: accessToken) {
        case .body(let body):
            let entries = body.kinds.map { AutoGroupEntry(group: .format, value: $0.key, count: $0.count) }
                + body.sources.map { AutoGroupEntry(group: .source, value: $0.key, count: $0.count) }
                + body.periods.compactMap { period in
                    ArchiveQuery.periodValues[period.key].map { AutoGroupEntry(group: .date, value: $0, count: period.count) }
                }
                + body.tags.map { AutoGroupEntry(group: .tag, value: $0.key, count: $0.count) }
            return .success(entries.filter { $0.count > 0 })
        case .sessionExpired: return .sessionExpired
        case .unauthorized, .failed: return .failed
        case .cancelled: return .cancelled
        }
    }

    /// 목록 한 쪽. `cursor`는 앞 응답의 `nextCursor`다.
    @MainActor
    static func page(
        _ request: ArchiveRequest,
        cursor: String?,
        transport: any HTTPTransport,
        accessToken: String
    ) async -> Outcome<Page> {
        switch request {
        case .items(let conditions):
            let params = conditions + ["limit=\(pageSize)"] + (cursor.map { ["cursor=\(BrowseAPI.percentEncoded($0))"] } ?? [])
            switch await BrowseAPI.items(params, transport: transport, accessToken: accessToken) {
            case .page(let items, _, let next): return .success(Page(items: items, nextCursor: next))
            case .sessionExpired: return .sessionExpired
            case .failed: return .failed
            case .cancelled: return .cancelled
            }
        case .bundle(let name):
            let outcome = await BundleAPI.page(
                name: name, limit: pageSize, cursor: cursor, transport: transport, accessToken: accessToken
            )
            switch outcome {
            case .success(let page): return .success(Page(items: page.items, nextCursor: page.nextCursor))
            case .sessionExpired: return .sessionExpired
            case .rejected, .failed: return .failed
            case .cancelled: return .cancelled
            }
        case .search(let query, let period):
            let outcome = await BrowseAPI.search(
                query, limit: pageSize, cursor: cursor, period: period, transport: transport, accessToken: accessToken
            )
            switch outcome {
            case .page(let items, _, let next, _, _): return .success(Page(items: items, nextCursor: next))
            case .sessionExpired: return .sessionExpired
            case .failed: return .failed
            case .cancelled: return .cancelled
            }
        }
    }
}
