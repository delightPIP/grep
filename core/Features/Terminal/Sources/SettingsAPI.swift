import FeatureTerminalInterface
import GrepCore

/// 설정 탭의 계정 칸(api/openapi.yaml `getMe`). `/me`에 있는 값만 쓴다.
enum SettingsAPI {
    private static let mePath = "/me"

    private struct MeBody: Decodable {
        let authProvider: String
        let itemCount: Int
    }

    @MainActor
    static func account(transport: any HTTPTransport, accessToken: String) async -> ArchiveAPI.Outcome<SettingsAccount> {
        switch await BrowseAPI.get(mePath, as: MeBody.self, transport: transport, accessToken: accessToken) {
        case .body(let me):
            guard let provider = AuthProvider(rawValue: me.authProvider) else { return .failed }
            return .success(SettingsAccount(authProvider: provider, itemCount: me.itemCount))
        case .sessionExpired: return .sessionExpired
        case .unauthorized, .failed: return .failed
        case .cancelled: return .cancelled
        }
    }
}
