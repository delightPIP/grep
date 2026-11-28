import Foundation
import GrepCore

/// 선택 칩·선택 줄의 `<종류 낱말> <번호>`(ARC-003 규칙 14, 웹 `pick-word.ts`와 같은 규칙).
/// 링크는 호스트, 글은 `글`, 파일은 형식(없으면 제목의 확장자)을 대문자로 쓴다.
/// 보관함(`FeatureLoggedInAdapter`)은 이 모듈에 기대지 않으므로 같은 규칙을 `ArchiveItemMapper.pickTag`가 따로 갖는다.
enum PickWord {
    static func tag(kind: ItemKind, source: String?, title: String, number: Int) -> String {
        "\(word(kind: kind, source: source, title: title)) \(number)"
    }

    private static func word(kind: ItemKind, source: String?, title: String) -> String {
        switch kind {
        case .link:
            // 호스트가 없는 링크는 정책에 낱말이 없어 웹처럼 `링크`로 둔다.
            return nonEmpty(source) ?? "링크"
        case .text:
            return "글"
        case .file:
            // 둘 다 없는 파일은 정책에 낱말이 없어 웹처럼 `파일`로 둔다.
            return (nonEmpty(source) ?? fileExtension(of: title))?.uppercased() ?? "파일"
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private static func fileExtension(of title: String) -> String? {
        guard let dot = title.lastIndex(of: "."), dot != title.index(before: title.endIndex) else { return nil }
        let ext = title[title.index(after: dot)...]
        return ext.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) } ? String(ext) : nil
    }
}
