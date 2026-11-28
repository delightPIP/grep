#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// `찾기 <검색어> [시점]`(commands 3절, #114). 검색어와 `#태그`, 마지막 낱말 시점을 나눈다(ARC-002 규칙 5~7).
public enum SeekCommand {
    public enum Parsed: Equatable {
        case query(SearchQuery, period: Period?)
        /// 인자가 없다. `✗ 검색어 없음`
        case missingArgument
        /// `#` 뒤에 태그 이름이 없다. `✗ 태그 없음  예: 찾기 #결제`(ARC-002)
        case missingTag
    }

    /// 한 쪽 건수(commands 3절: 10건 초과 시 앞 10건과 전체 건수).
    public static let pageSize = 10
    /// 0건일 때 함께 보이는 최근 저장 건수(commands 6절).
    public static let noResultsRecentCount = 3
    private static let tagPrefix: Character = "#"

    public static func parse(_ argument: String, now: Date = Date()) -> Parsed {
        var tokens = argument.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return .missingArgument }

        var period: Period?
        if let last = tokens.last, last.first != tagPrefix, let parsed = PeriodParser.parse(last, now: now) {
            period = parsed
            tokens.removeLast()
        }

        let tags = tokens.filter { $0.first == tagPrefix }.map { String($0.dropFirst()) }
        guard !tags.contains("") else { return .missingTag }
        let words = tokens.filter { $0.first != tagPrefix }.joined(separator: " ")
        return .query(SearchQuery(text: argument, words: words, tags: tags), period: period)
    }
}
