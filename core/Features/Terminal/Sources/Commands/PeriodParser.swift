#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FeatureTerminalInterface

/// 한국 시간(`UTC+9`, 주는 월요일 시작) 기준으로 시점 낱말을 반열린 구간 `[from, to)`으로 바꾼다(#114, F22).
enum PeriodParser {
    private static let kstOffsetSeconds = 9 * 3600
    private static let maxWeeksAgo = 52

    static func parse(_ token: String, now: Date = Date()) -> Period? {
        guard let timeZone = TimeZone(secondsFromGMT: kstOffsetSeconds) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let comps = calendar.dateComponents([.year, .month, .day, .weekday], from: now)
        guard let year = comps.year, let month = comps.month, let day = comps.day, let weekday = comps.weekday,
              let todayStart = calendar.date(from: DateComponents(timeZone: timeZone, year: year, month: month, day: day)) else {
            return nil
        }

        // Gregorian weekday: 1=일, 2=월, ..., 7=토 → 월요일=0 오프셋.
        let daysSinceMonday = (weekday + 5) % 7
        guard let thisMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: todayStart) else {
            return nil
        }

        let range: (start: Date, end: Date)?
        switch token {
        case "오늘":
            range = dayRange(from: todayStart, days: 1, calendar: calendar)
        case "어제":
            range = calendar.date(byAdding: .day, value: -1, to: todayStart).map { ($0, todayStart) }
        case "이번주":
            range = dayRange(from: thisMonday, days: 7, calendar: calendar)
        case "지난주":
            range = calendar.date(byAdding: .day, value: -7, to: thisMonday).map { ($0, thisMonday) }
        case "이번달":
            range = monthRange(year: year, month: month, calendar: calendar, timeZone: timeZone)
        case "지난달":
            let (prevYear, prevMonth) = month == 1 ? (year - 1, 12) : (year, month - 1)
            range = monthRange(year: prevYear, month: prevMonth, calendar: calendar, timeZone: timeZone)
        default:
            if let weeks = parseWeeksAgo(token) {
                if let start = calendar.date(byAdding: .day, value: -7 * weeks, to: thisMonday),
                   let end = calendar.date(byAdding: .day, value: 7, to: start) {
                    range = (start, end)
                } else {
                    range = nil
                }
            } else if let targetMonth = parseMonth(token) {
                let targetYear = targetMonth > month ? year - 1 : year
                range = monthRange(year: targetYear, month: targetMonth, calendar: calendar, timeZone: timeZone)
            } else {
                range = nil
            }
        }

        guard let range else { return nil }
        return Period(
            label: token,
            from: formatRFC3339KST(range.start, calendar: calendar),
            to: formatRFC3339KST(range.end, calendar: calendar)
        )
    }

    private static func dayRange(from start: Date, days: Int, calendar: Calendar) -> (Date, Date)? {
        calendar.date(byAdding: .day, value: days, to: start).map { (start, $0) }
    }

    private static func monthRange(
        year: Int,
        month: Int,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> (Date, Date)? {
        guard let start = calendar.date(from: DateComponents(timeZone: timeZone, year: year, month: month, day: 1)),
              let end = calendar.date(byAdding: .month, value: 1, to: start) else {
            return nil
        }
        return (start, end)
    }

    private static func parseWeeksAgo(_ token: String) -> Int? {
        guard token.hasSuffix("주전") else { return nil }
        let prefix = String(token.dropLast(2))
        guard !prefix.isEmpty, prefix.allSatisfy({ $0.isASCII && $0.isNumber }),
              let value = Int(prefix), (1...maxWeeksAgo).contains(value) else {
            return nil
        }
        return value
    }

    private static func parseMonth(_ token: String) -> Int? {
        guard token.hasSuffix("월") else { return nil }
        let prefix = String(token.dropLast(1))
        guard !prefix.isEmpty, prefix.allSatisfy({ $0.isASCII && $0.isNumber }),
              let value = Int(prefix), (1...12).contains(value) else {
            return nil
        }
        return value
    }

    private static func formatRFC3339KST(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let y = pad4(c.year ?? 0)
        let m = pad2(c.month ?? 0)
        let d = pad2(c.day ?? 0)
        let h = pad2(c.hour ?? 0)
        let min = pad2(c.minute ?? 0)
        let s = pad2(c.second ?? 0)
        return "\(y)-\(m)-\(d)T\(h):\(min):\(s)+09:00"
    }

    private static func pad2(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    private static func pad4(_ value: Int) -> String {
        let s = "\(value)"
        return s.count < 4 ? String(repeating: "0", count: 4 - s.count) + s : s
    }
}
