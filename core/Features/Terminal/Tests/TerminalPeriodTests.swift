#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import FeatureTerminal
import FeatureTerminalInterface
import GrepCore
import GrepCoreTesting
import Testing

@MainActor
struct TerminalPeriodTests {
    @Test func 기준일이목요일일때_시점낱말을파싱하면_한국시간월요일시작반열린구간을돌려주는지() throws {
        // given: 2026-11-26(목) 15:00 KST
        let tz = try #require(TimeZone(secondsFromGMT: 9 * 3600))
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let now = try #require(cal.date(from: DateComponents(timeZone: tz, year: 2026, month: 11, day: 26, hour: 15)))

        // when
        let thisWeek = PeriodParser.parse("이번주", now: now)
        let lastWeek = PeriodParser.parse("지난주", now: now)
        let threeWeeksAgo = PeriodParser.parse("3주전", now: now)
        let lastMonth = PeriodParser.parse("지난달", now: now)
        let nov = PeriodParser.parse("11월", now: now)
        let dec = PeriodParser.parse("12월", now: now)

        // then
        #expect(thisWeek == Period(label: "이번주", from: "2026-11-23T00:00:00+09:00", to: "2026-11-30T00:00:00+09:00"))
        #expect(lastWeek == Period(label: "지난주", from: "2026-11-16T00:00:00+09:00", to: "2026-11-23T00:00:00+09:00"))
        #expect(threeWeeksAgo == Period(label: "3주전", from: "2026-11-02T00:00:00+09:00", to: "2026-11-09T00:00:00+09:00"))
        #expect(lastMonth == Period(label: "지난달", from: "2026-10-01T00:00:00+09:00", to: "2026-11-01T00:00:00+09:00"))
        #expect(nov == Period(label: "11월", from: "2026-11-01T00:00:00+09:00", to: "2026-12-01T00:00:00+09:00"))
        #expect(dec == Period(label: "12월", from: "2025-12-01T00:00:00+09:00", to: "2026-01-01T00:00:00+09:00"))
    }

    @Test func 최근시점으로조회할때_서버가total을주면_recentList에total과period를채우는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach(itemCount: 30)
        let item = TerminalFixture.item(1)

        // when
        await fixture.submit("최근 지난달")
        await fixture.respond(json: #"{"items":[\#(TerminalFixture.json(item))],"total":23,"nextCursor":"c2"}"#)

        // then
        #expect(fixture.transport.requests.last?.path.contains("from=") == true)
        #expect(fixture.transport.requests.last?.path.contains("to=") == true)
        guard case .recentList(let items, let hasMore, let total, let period) = fixture.state.lines.last else {
            Issue.record("Expected recentList")
            return
        }
        #expect(items == [item])
        #expect(hasMore)
        #expect(total == 23)
        #expect(period?.label == "지난달")
    }

    @Test func 시점찾기가0건일때_noResults에period를채우는지() async {
        // given
        let fixture = TerminalFixture()
        await fixture.attach(itemCount: 10)

        // when
        await fixture.submit("찾기 결제 지난달")
        await fixture.respond(json: #"{"items":[],"total":0,"nextCursor":null}"#)
        await fixture.respond(json: #"{"items":[],"nextCursor":null}"#)

        // then
        guard case .noResults(let query, _, let period) = fixture.state.lines.last else {
            Issue.record("Expected noResults")
            return
        }
        #expect(query.words == "결제")
        #expect(period?.label == "지난달")
    }
}
