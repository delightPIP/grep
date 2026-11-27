#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FeatureTerminalInterface

/// `찾아두기`·`찾아두기 <검색어>`·`찾아두기 <검색어> 지우기`(commands 3절, ARC-012). 이어 쓰기는 부르는 쪽이 먼저 나눈다.
enum GatherCommand {
    enum Parsed: Equatable {
        case list
        /// `query`는 공백을 정리한 검색어(규칙 2). 결과는 `search`로 찾는다.
        case save(query: String, search: SearchQuery)
        case delete(String)
        case missingArgument
        case missingTag
        /// `✗ 시점은 찾아두지 않음: <시점>` 다음 줄 `→ <suggestion>`(규칙 4)
        case period(String, suggestion: String)
        case tooLong
    }

    static let deleteWord = "지우기"
    private static let maxQueryLength = 40
    private static let tagPrefix: Character = "#"

    static func parse(_ argument: String, now: Date = Date()) -> Parsed {
        var tokens = argument.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return .list }
        if tokens.count >= 2 && tokens.last == deleteWord {
            tokens.removeLast()
            return .delete(tokens.joined(separator: " "))
        }
        if let last = tokens.last, last.first != tagPrefix, PeriodParser.parse(last, now: now) != nil {
            let rest = tokens.dropLast().joined(separator: " ")
            return .period(last, suggestion: "찾아두기 " + (rest.isEmpty ? "\"\(last)\"" : rest))
        }
        let query = tokens.joined(separator: " ")
        guard query.count <= maxQueryLength else { return .tooLong }
        switch SeekCommand.parse(query, now: now) {
        case .query(let search, _): return .save(query: query, search: search)
        case .missingTag: return .missingTag
        case .missingArgument: return .missingArgument
        }
    }
}
