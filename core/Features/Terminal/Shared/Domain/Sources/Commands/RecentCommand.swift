#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import GrepDomain


/// `최근 [개수] [시점]`(commands 3절, #114). 한 쪽에 받을 건수와 시점 조건을 읽는다.
public enum RecentCommand {
    public struct Parsed: Equatable {
        public let limit: Int
        public let period: Period?
    }

    /// 개수를 생략했을 때(commands 3절).
    private static let defaultLimit = 10
    /// 서버가 한 쪽에 주는 최대 건수(api/openapi.yaml `Limit`).
    private static let maxLimit = 50

    public static func parse(_ argument: String, now: Date = Date()) -> Parsed {
        let tokens = argument.split(whereSeparator: \.isWhitespace).map(String.init)
        var limit = defaultLimit
        var period: Period?
        for token in tokens {
            if let count = Int(token), count >= 1 {
                limit = min(count, maxLimit)
            } else if period == nil, let parsed = PeriodParser.parse(token, now: now) {
                period = parsed
            }
        }
        return Parsed(limit: limit, period: period)
    }

    public static func limit(for argument: String) -> Int {
        parse(argument).limit
    }
}
