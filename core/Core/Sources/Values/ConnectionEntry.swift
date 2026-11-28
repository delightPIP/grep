
/// `<번호>  <AI 도구>  연결 <날짜>  읽음 <날짜>`(ACC-002). 날짜는 RFC 3339, `lastReadAt`은 없으면 nil.
public struct ConnectionEntry: Equatable, Sendable, Codable {
    public let number: Int
    public let client: String
    public let connectedAt: String
    public let lastReadAt: String?

    public init(number: Int, client: String, connectedAt: String, lastReadAt: String?) {
        self.number = number
        self.client = client
        self.connectedAt = connectedAt
        self.lastReadAt = lastReadAt
    }
}
