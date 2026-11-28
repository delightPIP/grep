import Foundation
import FeatureTerminalInterface
import GrepCore

/// 시점(F22) 날짜 표시. 한국 시간(`Asia/Seoul`), 주는 월요일 시작(commands 3절 시점, 웹 `periodDays`·`weekStart`와 같음).
enum PeriodFormat {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }()

    /// `지난달 (10/1~10/31)`. 끝은 반열린 구간이라 1초 앞이 마지막 날이다.
    static func label(_ period: Period) -> String {
        guard let first = parse(period.from), let end = parse(period.to) else { return period.label }
        return "\(period.label) (\(monthDay(first))~\(monthDay(end.addingTimeInterval(-1))))"
    }

    /// 기간이 여러 주에 걸치면 주가 바뀌는 행마다 `── 월~일 ──` 구분선을 붙인다(웹 `ListLines`).
    static func dividers(for savedAts: [String], in period: Period) -> [String?] {
        guard spansWeeks(period) else { return savedAts.map { _ in nil } }
        var previousWeek: Date?
        return savedAts.map { savedAt in
            guard let saved = parse(savedAt), let week = weekStart(of: saved) else { return nil }
            defer { previousWeek = week }
            guard week != previousWeek else { return nil }
            let lastDay = calendar.date(byAdding: .day, value: 6, to: week) ?? week
            return "── \(monthDay(week))~\(monthDay(lastDay)) ──"
        }
    }

    private static func spansWeeks(_ period: Period) -> Bool {
        guard let first = parse(period.from), let end = parse(period.to) else { return false }
        return weekStart(of: first) != weekStart(of: end.addingTimeInterval(-1))
    }

    private static func weekStart(of date: Date) -> Date? {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start
    }

    private static func monthDay(_ date: Date) -> String {
        let parts = calendar.dateComponents([.month, .day], from: date)
        return "\(parts.month ?? 0)/\(parts.day ?? 0)"
    }

    private static func parse(_ iso8601: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return fractional.date(from: iso8601) ?? plain.date(from: iso8601)
    }
}
