import ArchiveDomain
import GrepCore
import GrepData

/// `ArchiveRepository`를 서버 API로 채운다. 날짜 묶음 경계는 기기 시간대로 나눈다(ARC-007 값).
@MainActor
public final class ArchiveRepositoryImpl: ArchiveRepository {
    private let authService: any AuthService
    private let httpTransport: any HTTPTransport
    private let deviceTime: DeviceTime

    public init(authService: any AuthService, httpTransport: any HTTPTransport, deviceTime: DeviceTime) {
        self.authService = authService
        self.httpTransport = httpTransport
        self.deviceTime = deviceTime
    }

    public func page(filter: ArchiveFilter, cursor: String?) async -> FetchOutcome<ArchivePage> {
        guard let request = ArchiveQuery.request(for: filter, now: deviceTime.now(), timeZone: deviceTime.timeZone) else {
            return .failed
        }
        return await withToken { [httpTransport] token in
            await ArchiveAPI.page(request, cursor: cursor, transport: httpTransport, accessToken: token)
                .map { ArchivePage(items: $0.items, nextCursor: $0.nextCursor) }
        }
    }

    public func autoGroups() async -> FetchOutcome<[AutoGroupEntry]> {
        await withToken { [httpTransport, deviceTime] token in
            await ArchiveAPI.groups(timeZone: deviceTime.timeZoneID, transport: httpTransport, accessToken: token)
        }
    }

    public func bundles() async -> FetchOutcome<[BundleEntry]> {
        await withToken { [httpTransport] token in
            await BundleAPI.list(transport: httpTransport, accessToken: token).fetchOutcome
        }
    }

    public func savedSearches() async -> FetchOutcome<[SavedSearchEntry]> {
        await withToken { [httpTransport] token in
            await SavedSearchAPI.list(transport: httpTransport, accessToken: token).fetchOutcome
                .map { $0.filter { $0.count > 0 } }
        }
    }

    private func withToken<Value>(
        _ request: @MainActor (_ accessToken: String) async -> FetchOutcome<Value>
    ) async -> FetchOutcome<Value> {
        guard let token = await authService.accessToken() else { return .sessionExpired }
        return await request(token)
    }
}
