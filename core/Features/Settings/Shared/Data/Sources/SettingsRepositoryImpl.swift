import GrepCore
import GrepData
import SettingsDomain

/// `SettingsRepository`를 서버 API로 채운다.
@MainActor
public final class SettingsRepositoryImpl: SettingsRepository {
    private let authService: any AuthService
    private let httpTransport: any HTTPTransport

    public init(authService: any AuthService, httpTransport: any HTTPTransport) {
        self.authService = authService
        self.httpTransport = httpTransport
    }

    public func account() async -> FetchOutcome<SettingsAccount> {
        guard let token = await authService.accessToken() else { return .sessionExpired }
        return await SettingsAPI.account(transport: httpTransport, accessToken: token)
    }

    public func connections() async -> FetchOutcome<[ConnectionEntry]> {
        guard let token = await authService.accessToken() else { return .sessionExpired }
        return await ConnectionsAPI.list(transport: httpTransport, accessToken: token).fetchOutcome.map(\.connections)
    }
}
