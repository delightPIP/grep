
/// 시점(F22). label은 친 낱말 그대로(`지난달`), from·to는 한국 시간 경계의 RFC 3339(반열린 구간).
public struct Period: Equatable, Sendable, Codable {
    public let label: String
    public let from: String
    public let to: String

    public init(label: String, from: String, to: String) {
        self.label = label
        self.from = from
        self.to = to
    }
}
