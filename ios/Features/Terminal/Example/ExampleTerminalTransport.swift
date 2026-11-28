import FeatureTerminalInterface
import Foundation
import GrepCore

/// Example 앱 전용 가짜 `HTTPTransport`. 시나리오가 부르는 경로만 고정 응답을 준다.
@MainActor
final class ExampleTerminalTransport: HTTPTransport {
    private static let titles = [131: "결제위젯 연동 가이드", 118: "결제 실패 화면 모음.png"]

    func send(_ request: HTTPRequest) async throws(HTTPTransportError) -> HTTPResponse {
        switch (request.method, request.path) {
        case (.post, "/items/trash"), (.post, "/items/restore"):
            return HTTPResponse(status: 200, body: Array(Self.movedBody(for: request).utf8))
        case (.post, "/samples"):
            return HTTPResponse(status: 201, body: Array(#"{"firstNumber":1,"lastNumber":8}"#.utf8))
        case (.get, "/items?limit=8"):
            return HTTPResponse(status: 200, body: Self.encoded(SamplePage(items: Self.sampleItems(), total: 8, nextCursor: nil)))
        case (.get, "/items/status?numbers=131,118,64"):
            let picked = [(131, "결제위젯 연동 가이드"), (118, "결제 실패 화면 모음.png"), (64, "결제 UX 스레드 모음")].map {
                ItemSummary(number: $0.0, kind: .link, title: $0.1, source: nil, status: .ready, tags: [], savedAt: "2026-11-26T05:03:00Z")
            }
            return HTTPResponse(status: 200, body: Self.encoded(LookupBody(items: picked, missing: [])))
        case (.get, "/items/status?numbers=131"):
            return HTTPResponse(status: 200, body: Self.encoded(LookupBody(items: [Self.reviseItem()], missing: [])))
        case (.patch, "/items/131"):
            return HTTPResponse(status: 200, body: Self.encoded(Self.revisedItem(for: request)))
        default:
            return HTTPResponse(status: 200, body: Array(#"{"items":[],"total":0,"nextCursor":null}"#.utf8))
        }
    }

    private struct SamplePage: Encodable {
        let items: [ItemSummary]
        let total: Int
        let nextCursor: String?
    }

    /// 시안 15 Sample ①의 마케터 캠페인 이야기 7건과 사용법 1건(제목은 시안용 예시).
    private static func sampleItems() -> [ItemSummary] {
        let rows: [(String, String)] = [
            ("그렙 사용법: 담기 → 찾기 → 넘기기", "그렙"),
            ("카페 텀블러 할인, 올겨울 캠페인 늘었다", "가상 기사"),
            ("파란컵 텀블러 캠페인 캡처.png", "이미지"),
            ("겨울 음료 트렌드 보고서.pdf", "PDF"),
            ("경쟁사 굿즈 이벤트 정리", "메모"),
            ("인스타 캠페인 반응 모음", "가상 기사"),
            ("텀블러 지참 할인 매장 목록", "가상 기사"),
            ("캠페인 카피 초안", "글"),
        ]
        return rows.enumerated().map { index, row in
            ItemSummary(
                number: 8 - index,
                kind: .link,
                title: row.0,
                source: row.1,
                status: .ready,
                tags: [],
                savedAt: "2026-11-27T01:00:00Z"
            )
        }
    }

    private struct LookupBody: Encodable {
        let items: [ItemSummary]
        let missing: [Int]
    }

    private struct ReviseBody: Decodable {
        let title: String?
        let summary: String?
        let removeTags: [String]?
    }

    private static func reviseItem(
        title: String = "결제위젯 연동 가이드",
        summary: String = "웹·모바일 결제위젯 SDK 설치와 승인 흐름 정리",
        summarySource: SummarySource = .ai,
        tags: [String] = ["결제", "sdk", "가이드"]
    ) -> ItemSummary {
        ItemSummary(
            number: 131,
            kind: .link,
            title: title,
            source: "tosspayments",
            status: .ready,
            listSummary: summary,
            summarySource: summarySource,
            tags: tags,
            savedAt: "2026-11-26T05:03:00Z"
        )
    }

    /// `PATCH /items/131`을 받은 값대로 고친 자료. 요약을 고치면 `summarySource`가 `user`가 된다(ARC-004 규칙 1).
    private static func revisedItem(for request: HTTPRequest) -> ItemSummary {
        let body = request.body.flatMap { try? JSONDecoder().decode(ReviseBody.self, from: Data($0.utf8)) }
        let base = reviseItem()
        let removed = Set(body?.removeTags ?? [])
        return reviseItem(
            title: body?.title ?? base.title,
            summary: body?.summary ?? base.listSummary ?? "",
            summarySource: body?.summary == nil ? .ai : .user,
            tags: base.tags.filter { !removed.contains($0) }
        )
    }

    private static func encoded(_ value: some Encodable) -> [UInt8] {
        Array((try? JSONEncoder().encode(value)) ?? Data())
    }

    /// 받은 번호를 그대로 옮겼다고 답한다(api `ItemRefList`).
    private static func movedBody(for request: HTTPRequest) -> String {
        struct Numbers: Decodable { let numbers: [Int] }
        let numbers = request.body
            .flatMap { try? JSONDecoder().decode(Numbers.self, from: Data($0.utf8)) }?
            .numbers ?? []
        let items = numbers.map { number in
            let title = titles[number] ?? "자료 \(number)"
            return #"{"number":\#(number),"title":"\#(title)"}"#
        }
        return #"{"items":[\#(items.joined(separator: ","))]}"#
    }
}
