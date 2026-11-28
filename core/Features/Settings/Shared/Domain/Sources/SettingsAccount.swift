import GrepDomain

/// 계정 칸. `GET /me`에 있는 값만 쓴다.
public struct SettingsAccount: Equatable, Sendable {
    public let authProvider: AuthProvider
    public let itemCount: Int

    public init(authProvider: AuthProvider, itemCount: Int) {
        self.authProvider = authProvider
        self.itemCount = itemCount
    }
}
