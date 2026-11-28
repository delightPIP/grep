import Foundation
import GrepAndroid
import GrepCore
import GrepCoreTesting
import Testing

struct ArchiveItemMapperTests {
    @Test
    func 처리완료링크자료일때_매핑하면_출처와한국시각과태그3개를채우는지() {
        // given
        let item = ItemSummary(
            number: 131,
            kind: .link,
            title: "결제위젯 연동 가이드",
            source: "tosspayments",
            status: .ready,
            listSummary: "SDK 설치와 승인 흐름",
            partialNote: "앞 5쪽만",
            tags: ["결제", "sdk", "가이드", "초과태그"],
            savedAt: "2026-11-26T05:03:00Z"
        )

        // when
        let row = ArchiveItemMapper.mapRow(item)

        // then
        #expect(row.number == 131)
        #expect(row.title == "결제위젯 연동 가이드")
        #expect(row.meta == "tosspayments · 2026-11-26 14:03")
        #expect(row.summary == "SDK 설치와 승인 흐름 (앞 5쪽만)")
        #expect(!row.summaryIsWarning)
        #expect(row.tags == ["결제", "sdk", "가이드"])
    }

    @Test
    func 글자료제목이24자를넘을때_매핑하면_첫줄24자로자르는지() {
        // given
        let item = ItemSummary(
            number: 12,
            kind: .text,
            title: "아주 긴 메모 첫 줄은 스물네 글자까지만 잘라서 제목으로 쓴다\n둘째 줄",
            source: nil,
            status: .ready,
            tags: [],
            savedAt: "2026-11-26T05:03:00Z"
        )

        // when
        let row = ArchiveItemMapper.mapRow(item)

        // then
        #expect(row.title == "아주 긴 메모 첫 줄은 스물네 글자까지만 잘")
        #expect(row.meta == "2026-11-26 14:03")
    }

    @Test
    func 처리중차단실패상태일때_매핑하면_정책요약문구와경고여부를설정하는지() {
        // given
        let processing = ItemSummary(
            number: 1, kind: .link, title: "처리 중", source: "example.com",
            status: .processing, tags: [], savedAt: "2026-11-26T05:03:00Z"
        )
        let blocked = ItemSummary(
            number: 2, kind: .link, title: "차단됨", source: "threads.net",
            status: .blocked, blockedReason: .loginRequired, tags: [], savedAt: "2026-11-26T05:03:00Z"
        )
        let failed = ItemSummary(
            number: 3, kind: .file, title: "실패.pdf", source: "PDF",
            status: .failed, tags: [], savedAt: "2026-11-26T05:03:00Z"
        )

        // when
        let processingRow = ArchiveItemMapper.mapRow(processing)
        let blockedRow = ArchiveItemMapper.mapRow(blocked)
        let failedRow = ArchiveItemMapper.mapRow(failed)

        // then
        #expect(processingRow.summary == "· 요약 생성 중")
        #expect(!processingRow.summaryIsWarning)
        #expect(blockedRow.summary == "! 본문 못 가져옴 → 고치기 2")
        #expect(blockedRow.summaryIsWarning)
        #expect(failedRow.summary == "! 요약 못 만듦  제목·출처만 넘김")
        #expect(failedRow.summaryIsWarning)
    }
}

@MainActor
struct HTTPArchiveItemLoaderTests {
    private static let pageJson = """
    {"items":[{"number":7,"kind":"link","title":"가이드","source":"example.com","status":"ready",\
    "listSummary":"요약","tags":["a"],"savedAt":"2026-11-26T05:03:00Z"}],"nextCursor":"c 1"}
    """

    @Test
    func 다음커서가있을때_목록을부르면_커서를인코딩해보내고자료와커서를돌려주는지() async {
        // given
        let transport = FakeHTTPTransport()
        let loader = HTTPArchiveItemLoader(authService: FakeAuthService(token: "tok"), httpTransport: transport)

        // when
        async let outcome = loader.loadPage(limit: 20, cursor: "a/b")
        await runCurrent()
        transport.respond(json: Self.pageJson)
        let result = await outcome

        // then
        #expect(transport.requests.first?.path == "/items?limit=20&cursor=a%2Fb")
        #expect(transport.requests.first?.headers["Authorization"] == "Bearer tok")
        guard case .page(let items, let next) = result else {
            Issue.record("page가 아님: \(result)")
            return
        }
        #expect(items.map(\.number) == [7])
        #expect(next == "c 1")
    }

    @Test
    func 토큰이없을때_목록을부르면_세션만료를돌려주는지() async {
        // given
        let loader = HTTPArchiveItemLoader(authService: FakeAuthService(token: nil), httpTransport: FakeHTTPTransport())

        // when
        let result = await loader.loadPage(limit: 20, cursor: nil)

        // then
        #expect(result == .sessionExpired)
    }

    @Test
    func 서버가401session_expired를줄때_목록을부르면_세션만료인지() async {
        // given
        let transport = FakeHTTPTransport()
        let loader = HTTPArchiveItemLoader(authService: FakeAuthService(token: "tok"), httpTransport: transport)

        // when
        async let outcome = loader.loadPage(limit: 20, cursor: nil)
        await runCurrent()
        transport.respond(status: 401, json: #"{"code":"session_expired"}"#)

        // then
        #expect(await outcome == .sessionExpired)
    }

    @Test
    func 연결이끊겼을때_목록을부르면_연결끊김실패인지() async {
        // given
        let transport = FakeHTTPTransport()
        let loader = HTTPArchiveItemLoader(authService: FakeAuthService(token: "tok"), httpTransport: transport)

        // when
        async let outcome = loader.loadPage(limit: 20, cursor: nil)
        await runCurrent()
        transport.respond(.failure(.unreachable))

        // then
        #expect(await outcome == .failed(.disconnected))
    }
}

struct ArchivePageEncoderTests {
    @Test
    func 실패결과일때_인코딩하면_정책문구가담기는지() {
        // given
        let outcome = ArchivePageOutcome.failed(.timedOut)

        // when
        let json = ArchivePageEncoder.encode(outcome)

        // then
        #expect(json == #"{"message":"응답 없음","type":"failed"}"#)
    }

    @Test
    func 쪽결과일때_인코딩하면_행값과다음커서가담기는지() throws {
        // given
        let item = ItemSummary(
            number: 5, kind: .link, title: "제목", source: "a.com",
            status: .ready, listSummary: "요약", tags: ["t"], savedAt: "2026-11-26T05:03:00Z"
        )

        // when
        let json = ArchivePageEncoder.encode(.page(items: [item], nextCursor: "n"))

        // then
        let object = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        #expect(object["type"] as? String == "page")
        #expect(object["nextCursor"] as? String == "n")
        let rows = try #require(object["items"] as? [[String: Any]])
        #expect(rows.first?["number"] as? Int == 5)
        #expect(rows.first?["meta"] as? String == "a.com · 2026-11-26 14:03")
        #expect(rows.first?["summaryIsWarning"] as? Bool == false)
    }
}
