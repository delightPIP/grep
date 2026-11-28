import GrepDomain


/// 이어 쓰기 `<앞 명령> | <뒤 명령>`(commands 4절). 한 줄을 `|` 앞뒤로 나눈다.
public enum PipeCommand {
    private static let bar: Character = "|"
    /// 한글 자판에서 `|` 자리에 나오는 낱자. 앞뒤를 띄어 쓴 하나일 때만 `|`로 본다(commands 5절).
    private static let barJamo = "ㅣ"

    /// `|`가 없거나 뒤가 비었으면 nil.
    public static func split(_ text: String) -> (head: String, tail: String)? {
        guard let range = barRange(in: text) else { return nil }
        let tail = String(text[range.upperBound...]).trimmingWhitespace()
        guard !tail.isEmpty else { return nil }
        return (String(text[..<range.lowerBound]).trimmingWhitespace(), tail)
    }

    private static func barRange(in text: String) -> Range<String.Index>? {
        if let index = text.firstIndex(of: bar) { return index..<text.index(after: index) }
        let jamo = text.split(whereSeparator: \.isWhitespace).first { $0 == barJamo }
        return jamo.map { $0.startIndex..<$0.endIndex }
    }
}

/// `찾기 … | 넘기기` 결과가 5건을 넘어 답을 기다리는 확인(COM-008 규칙 2·3). 한 번에 하나다(COM-007 규칙 1).
public struct PendingHandoff: Equatable {
    public enum Choice: Equatable {
        /// `전부`: N건 전부
        case all
        /// `앞10`: 앞 10건만
        case firstPage
    }

    /// 이 건수까지는 묻지 않고 바로 복사한다(COM-008 값).
    public static let instantLimit = 5
    private static let allWord = "전부"
    private static let firstPageWord = "앞10"

    public let query: SearchQuery
    public let total: Int
    /// 찾기 첫 쪽(앞 10건)의 자료, 결과 순서. 넘긴 자료 줄의 종류·출처도 여기서 채운다(ARC-003 규칙 14).
    public let firstPage: [ItemRef]
    /// 첫 쪽 뒤가 남았으면 그 쪽을 받는 값.
    public let nextCursor: String?

    public init(query: SearchQuery, total: Int, firstPage: [ItemRef], nextCursor: String?) {
        self.query = query
        self.total = total
        self.firstPage = firstPage
        self.nextCursor = nextCursor
    }

    /// 답이 실행 낱말 하나이면 그 선택지, 아니면 nil(COM-007 규칙 2~4). `앞10`은 첫 쪽보다 많을 때만 선택지다.
    public func choice(for answer: String) -> Choice? {
        switch answer.trimmingWhitespace() {
        case Self.allWord: .all
        case Self.firstPageWord where total > firstPage.count: .firstPage
        default: nil
        }
    }
}
