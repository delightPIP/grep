import GrepCore

/// `묶음` 목록 한 줄(ARC-003).
public struct BundleEntry: Equatable, Sendable, Codable {
    public let name: String
    public let count: Int

    public init(name: String, count: Int) {
        self.name = name
        self.count = count
    }
}
