#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FeatureArchiveInterface
import GrepCore
import Testing

@testable import FeatureArchive

/// #168 보관함 거르기를 요청으로 바꾸기(ARC-007).
struct ArchiveQueryTests {
    /// 2026-11-28(토) 13:00 한국 시간.
    private static let now = Date(timeIntervalSince1970: 1_795_838_400)
    private static let seoul = TimeZone(identifier: "Asia/Seoul")!

    private func request(_ filter: ArchiveFilter, timeZone: TimeZone = seoul) -> ArchiveRequest? {
        ArchiveQuery.request(for: filter, now: Self.now, timeZone: timeZone)
    }

    @Test(arguments: [
        (ArchiveFilter.all, ArchiveRequest.items(conditions: [])),
        (.auto(group: .format, value: "image"), .items(conditions: ["kind=image"])),
        (.auto(group: .source, value: "direct"), .items(conditions: ["source=direct"])),
        (.auto(group: .source, value: "docs.toss.im"), .items(conditions: ["source=docs.toss.im"])),
        (.auto(group: .tag, value: "결제"), .items(conditions: ["tag=%EA%B2%B0%EC%A0%9C"])),
        (.bundle(name: "결제"), .bundle(name: "결제")),
    ])
    func 거르기를골랐을때_요청으로바꾸면_서버조건이되는지(filter: ArchiveFilter, expected: ArchiveRequest) {
        // given, when
        let built = request(filter)

        // then
        #expect(built == expected)
    }

    @Test(arguments: [
        ("today", "from=2026-11-27T15%3A00%3A00Z"),
        ("week", "from=2026-11-22T15%3A00%3A00Z"),
        ("month", "from=2026-10-31T15%3A00%3A00Z"),
        ("earlier", "to=2026-10-31T15%3A00%3A00Z"),
    ])
    func 날짜묶음을골랐을때_요청으로바꾸면_기기시간대의시작시각을보내는지(value: String, condition: String) {
        // given, when
        let built = request(.auto(group: .date, value: value))

        // then: 서버 날짜 묶음은 각 구간 시작 0시 이상을 센다. 그 전은 이번 달 1일 0시 미만(ARC-007 값).
        #expect(built == .items(conditions: [condition]))
    }

    @Test func 기기시간대가UTC일때_오늘을고르면_UTC0시를보내는지() {
        // given, when
        let built = request(.auto(group: .date, value: "today"), timeZone: TimeZone(identifier: "UTC")!)

        // then
        #expect(built == .items(conditions: ["from=2026-11-28T00%3A00%3A00Z"]))
    }

    @Test func 찾아둔검색을골랐을때_요청으로바꾸면_찾기조건이되는지() {
        // given, when
        let built = request(.savedSearch(query: "결제 #swift"))

        // then
        #expect(built == .search(SearchQuery(text: "결제 #swift", words: "결제", tags: ["swift"]), period: nil))
    }

    @Test(arguments: [
        ArchiveFilter.auto(group: .date, value: "yesterday"),
        .auto(group: .format, value: "video"),
        .savedSearch(query: "#"),
    ])
    func 모르는값일때_요청으로바꾸면_nil인지(filter: ArchiveFilter) {
        // given, when
        let built = request(filter)

        // then
        #expect(built == nil)
    }
}
