import GrepDomain

/// 사용자가 모르는 사이 끊긴 연결 하나(api `ConnectionNotices.ended`).
public struct ConnectionNotice: Equatable, Sendable, Codable {
    public let client: String
    public let reason: ConnectionEndReason

    public init(client: String, reason: ConnectionEndReason) {
        self.client = client
        self.reason = reason
    }
}
