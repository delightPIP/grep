import GrepCore
import Testing

/// 보관함 한 행 글자 규칙(ARC-004 규칙 7, ARC-005, #91).
struct ItemRowTextTests {
    private func item(
        kind: ItemKind = .link, title: String = "결제 가이드", source: String? = "docs.toss.im",
        status: ItemStatus = .ready, summary: String? = "요약", partial: String? = nil,
        tags: [String] = [], savedAt: String = "2026-11-27T01:05:00Z"
    ) -> ItemSummary {
        ItemSummary(
            number: 7, kind: kind, title: title, source: source, status: status, listSummary: summary,
            partialNote: partial, tags: tags, savedAt: savedAt
        )
    }

    @Test(arguments: [
        ("2026-11-27T01:05:00Z", "2026-11-27 10:05"),
        ("2026-11-27T15:30:00.123Z", "2026-11-28 00:30"),
        ("2026-11-27T10:05:00+09:00", "2026-11-27 10:05"),
        ("읽을 수 없음", "읽을 수 없음"),
    ])
    func 저장시각이있을때_글로바꾸면_한국시간분까지인지(raw: String, expected: String) {
        // given, when
        let text = ItemRowText.savedAt(raw)

        // then
        #expect(text == expected)
    }

    @Test func 글자료일때_제목을바꾸면_첫줄24자에서끝공백을빼는지() {
        // given
        let note = item(kind: .text, title: "가나다라마바사아자차카타파하 가나다라마바사아 자차\n둘째 줄")

        // when
        let title = ItemRowText.title(note)

        // then
        #expect(title == "가나다라마바사아자차카타파하 가나다라마바사아")
    }

    @Test func 링크자료일때_메타를만들면_출처와시각을점으로잇는지() {
        // given, when
        let meta = ItemRowText.meta(item())

        // then
        #expect(meta == "docs.toss.im · 2026-11-27 10:05")
    }

    @Test(arguments: [
        (ItemStatus.processing, "· 요약 생성 중", false),
        (.blocked, "! 본문 못 가져옴 → 고치기 7", true),
        (.failed, "! 요약 못 만듦  제목·출처만 넘김", true),
        (.ready, "요약", false),
    ])
    func 처리상태마다_요약줄을만들면_상태문구와경고여부가맞는지(status: ItemStatus, text: String, warning: Bool) {
        // given
        let row = item(status: status)

        // when, then
        #expect(ItemRowText.summary(row) == text)
        #expect(ItemRowText.isWarning(row) == warning)
    }

    @Test func 일부만읽은자료일때_요약줄을만들면_끝에괄호로덧붙이는지() {
        // given, when
        let summary = ItemRowText.summary(item(partial: "앞 2만 자만 읽음"))

        // then
        #expect(summary == "요약 (앞 2만 자만 읽음)")
    }

    @Test func 태그가넷일때_목록태그를고르면_앞세개만인지() {
        // given, when
        let tags = ItemRowText.tags(item(tags: ["a", "b", "c", "d"]))

        // then
        #expect(tags == ["a", "b", "c"])
    }
}
