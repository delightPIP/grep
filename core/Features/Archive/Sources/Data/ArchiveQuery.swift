#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FeatureArchiveInterface
import GrepCore
import GrepData

/// 보관함 목록을 받을 곳(#168).
enum ArchiveRequest: Equatable {
    /// `GET /items?<조건>`. 조건은 퍼센트 인코딩한 `이름=값`.
    case items(conditions: [String])
    /// `GET /bundles/{name}`
    case bundle(name: String)
    /// `GET /items/search`. 찾아둔 검색어를 `찾기`처럼 읽은 값.
    case search(SearchQuery, period: Period?)
}

/// 보관함 거르기를 요청으로 바꾼다(ARC-007). 서버 값과 계약 값이 다른 곳은 여기서 맞춘다.
enum ArchiveQuery {
    /// 서버 `/groups` 날짜 키 → 계약 값.
    static let periodValues = ["today": "today", "thisWeek": "week", "thisMonth": "month", "earlier": "earlier"]
    private static let formatValues: Set = ["link", "text", "image", "file"]

    /// 모르는 값이면 nil.
    static func request(for filter: ArchiveFilter, now: Date, timeZone: TimeZone) -> ArchiveRequest? {
        switch filter {
        case .all:
            return .items(conditions: [])
        case .auto(.format, let value):
            return formatValues.contains(value) ? .items(conditions: ["kind=\(encoded(value))"]) : nil
        case .auto(.source, let value):
            return .items(conditions: ["source=\(encoded(value))"])
        case .auto(.tag, let value):
            return .items(conditions: ["tag=\(encoded(value))"])
        case .auto(.date, let value):
            return dateCondition(value, now: now, timeZone: timeZone).map { .items(conditions: [$0]) }
        case .bundle(let name):
            return .bundle(name: name)
        case .savedSearch(let query):
            guard case .query(let search, let period) = SeekCommand.parse(query, now: now) else { return nil }
            return .search(search, period: period)
        }
    }

    /// 서버 날짜 묶음은 각 구간 시작 0시 이상을 센다. `그 전`은 이번 달 1일 0시 미만이다. 주는 월요일에 시작한다.
    private static func dateCondition(_ value: String, now: Date, timeZone: TimeZone) -> String? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2
        let today = calendar.startOfDay(for: now)
        let start: Date?
        switch value {
        case "today": start = today
        case "week": start = calendar.dateInterval(of: .weekOfYear, for: today)?.start
        case "month", "earlier": start = calendar.dateInterval(of: .month, for: today)?.start
        default: return nil
        }
        guard let start else { return nil }
        return (value == "earlier" ? "to=" : "from=") + encoded(rfc3339UTC(start))
    }

    private static func rfc3339UTC(_ date: Date) -> String {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0) ?? utc.timeZone
        let c = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        func pad(_ value: Int?, _ width: Int = 2) -> String {
            let text = String(value ?? 0)
            return String(repeating: "0", count: max(0, width - text.count)) + text
        }
        return "\(pad(c.year, 4))-\(pad(c.month))-\(pad(c.day))T\(pad(c.hour)):\(pad(c.minute)):\(pad(c.second))Z"
    }

    private static func encoded(_ value: String) -> String { BrowseAPI.percentEncoded(value) }
}
