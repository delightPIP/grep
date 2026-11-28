import GrepCore
import RIBs

/// 자료를 가리키는 최소 값. 선택 줄·넘긴 자료 줄에 쓴다.
/// `kind`·`source`는 선택 칩의 종류 낱말(ARC-003 규칙 14)에 쓴다. 고를 때 받은 `ItemSummary`에서 채운다.
public struct ItemRef: Equatable, Sendable {
    public let number: Int
    public let title: String
    public let kind: ItemKind
    /// 링크는 호스트, 파일은 형식. 없을 수 있다.
    public let source: String?

    public init(number: Int, title: String, kind: ItemKind = .text, source: String? = nil) {
        self.number = number
        self.title = title
        self.kind = kind
        self.source = source
    }

    public init(_ item: ItemSummary) {
        self.init(number: item.number, title: item.title, kind: item.kind, source: item.source)
    }
}
