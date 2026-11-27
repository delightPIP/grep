import FeatureTerminalInterface

/// `찾기 <검색어>`(commands 3절). 검색어와 `#태그`를 나눈다(ARC-002 규칙 5~7).
enum SeekCommand {
    enum Parsed: Equatable {
        case query(SearchQuery)
        /// 인자가 없다. `✗ 검색어 없음`
        case missingArgument
        /// `#` 뒤에 태그 이름이 없다. `✗ 태그 없음  예: 찾기 #결제`(ARC-002)
        case missingTag
    }

    /// 한 쪽 건수(commands 3절: 10건 초과 시 앞 10건과 전체 건수).
    static let pageSize = 10
    /// 0건일 때 함께 보이는 최근 저장 건수(commands 6절).
    static let noResultsRecentCount = 3
    private static let tagPrefix: Character = "#"

    /// shortcut: 마지막 낱말의 시점(`찾기 결제 3주전`, F22)은 아직 가르지 않고 검색어로 본다. 시점을 구현하는 이슈에서 나눈다.
    static func parse(_ argument: String) -> Parsed {
        let tokens = argument.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return .missingArgument }
        let tags = tokens.filter { $0.first == tagPrefix }.map { String($0.dropFirst()) }
        guard !tags.contains("") else { return .missingTag }
        let words = tokens.filter { $0.first != tagPrefix }.joined(separator: " ")
        return .query(SearchQuery(text: argument, words: words, tags: tags))
    }
}
