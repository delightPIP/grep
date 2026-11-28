import GrepCore

/// 설정 탭의 상태(#168). 설정을 처음 열 때 채운다.
public struct SettingsState: Equatable, Sendable {
    public let account: SettingsAccount?
    public let connections: [ConnectionEntry]

    public init(account: SettingsAccount? = nil, connections: [ConnectionEntry] = []) {
        self.account = account
        self.connections = connections
    }
}

/// 계정 칸. `GET /me`에 있는 값만 쓴다.
public struct SettingsAccount: Equatable, Sendable {
    public let authProvider: AuthProvider
    public let itemCount: Int

    public init(authProvider: AuthProvider, itemCount: Int) {
        self.authProvider = authProvider
        self.itemCount = itemCount
    }
}
