
/// `찾기`의 조건. 태그는 `#` 없이(ARC-002 규칙 5~8).
public struct SearchQuery: Equatable, Sendable {
    /// 사용자가 친 검색어 그대로. `· 0건: "<text>"`에 쓴다.
    public let text: String
    public let words: String
    public let tags: [String]

    public init(text: String, words: String, tags: [String]) {
        self.text = text
        self.words = words
        self.tags = tags
    }
}
