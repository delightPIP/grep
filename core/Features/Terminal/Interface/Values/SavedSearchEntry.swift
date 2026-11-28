import GrepCore

/// `찾아두기` 목록 한 줄(ARC-012).
public struct SavedSearchEntry: Equatable, Sendable, Codable {
    public let query: String
    public let count: Int

    public init(query: String, count: Int) {
        self.query = query
        self.count = count
    }
}
