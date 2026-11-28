import Foundation
import GrepCore

/// 보관함 한 행의 표시 값. 고른 상태는 Kotlin 쪽이 선택과 맞춰 붙인다.
public struct ArchiveRowValue: Equatable, Sendable, Encodable {
    public let number: Int
    public let title: String
    public let meta: String
    public let summary: String?
    public let summaryIsWarning: Bool
    public let tags: [String]
}

/// `ItemSummary`와 보관함 오류를 화면 값과 정책 문구로 바꾼다. 행 글자 규칙은 코어 `ItemRowText`가 정한다(iOS와 같다).
public enum ArchiveItemMapper {
    public static func mapRow(_ item: ItemSummary) -> ArchiveRowValue {
        ArchiveRowValue(
            number: item.number,
            title: ItemRowText.title(item),
            meta: ItemRowText.meta(item),
            summary: ItemRowText.summary(item),
            summaryIsWarning: ItemRowText.isWarning(item),
            tags: ItemRowText.tags(item)
        )
    }

    /// COM-010 연결 오류 문구.
    public static func errorMessage(_ reason: ArchiveLoadFailure) -> String {
        switch reason {
        case .disconnected: "연결 끊김"
        case .timedOut: "응답 없음"
        case .serverError: "서버 오류"
        }
    }

    static func textTitle(_ title: String) -> String { ItemRowText.textTitle(title) }

    static func formatSavedAt(_ iso8601: String) -> String { ItemRowText.savedAt(iso8601) }
}

/// 보관함 한 쪽 결과를 Kotlin 어댑터가 읽는 JSON으로 바꾼다.
/// `{"type":"page","items":[...],"nextCursor":"..."}` · `{"type":"sessionExpired"}` · `{"type":"failed","message":"연결 끊김"}` · `{"type":"cancelled"}`
public enum ArchivePageEncoder {
    private struct PageDTO: Encodable {
        let type: String
        let items: [ArchiveRowValue]?
        let nextCursor: String?
        let message: String?
    }

    public static func encode(_ outcome: ArchivePageOutcome) -> String {
        let dto: PageDTO
        switch outcome {
        case .page(let items, let nextCursor):
            dto = PageDTO(type: "page", items: items.map(ArchiveItemMapper.mapRow), nextCursor: nextCursor, message: nil)
        case .sessionExpired:
            dto = PageDTO(type: "sessionExpired", items: nil, nextCursor: nil, message: nil)
        case .failed(let reason):
            dto = PageDTO(type: "failed", items: nil, nextCursor: nil, message: ArchiveItemMapper.errorMessage(reason))
        case .cancelled:
            dto = PageDTO(type: "cancelled", items: nil, nextCursor: nil, message: nil)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(dto), let json = String(data: data, encoding: .utf8) else {
            return #"{"type":"failed","message":"서버 오류"}"#
        }
        return json
    }
}
