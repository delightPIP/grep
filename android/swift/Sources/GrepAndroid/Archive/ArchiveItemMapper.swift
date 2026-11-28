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

/// `ItemSummary`와 보관함 오류를 화면 값과 정책 문구로 바꾼다. iOS `ArchiveItemMapper`(#91)와 같은 규칙이다.
public enum ArchiveItemMapper {
    private static let listTagLimit = 3
    private static let textTitleLimit = 24

    public static func mapRow(_ item: ItemSummary) -> ArchiveRowValue {
        let title = item.kind == .text ? textTitle(item.title) : item.title
        let savedAt = formatSavedAt(item.savedAt)
        let metaParts = [item.source, savedAt].compactMap { $0 }.filter { !$0.isEmpty }
        return ArchiveRowValue(
            number: item.number,
            title: title,
            meta: metaParts.joined(separator: " · "),
            summary: rowSummary(item),
            summaryIsWarning: item.status == .blocked || item.status == .failed,
            tags: Array(item.tags.prefix(listTagLimit))
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

    static func textTitle(_ title: String) -> String {
        let firstLine = title.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        return String(firstLine.prefix(textTitleLimit))
            .replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
    }

    private static func isProcessing(_ item: ItemSummary) -> Bool {
        item.status == .received || item.status == .processing
    }

    private static func rowSummary(_ item: ItemSummary) -> String? {
        if isProcessing(item) { return "· 요약 생성 중" }
        if item.status == .blocked { return "! 본문 못 가져옴 → 고치기 \(item.number)" }
        if item.status == .failed { return "! 요약 못 만듦  제목·출처만 넘김" }
        guard let summary = item.listSummary else { return nil }
        if let partial = item.partialNote, !partial.isEmpty {
            return "\(summary) (\(partial))"
        }
        return summary
    }

    /// ARC-004 규칙 7: 저장 시각은 한국 시간(`Asia/Seoul`) `yyyy-MM-dd HH:mm`.
    static func formatSavedAt(_ iso8601: String) -> String {
        let parserWithFractional = ISO8601DateFormatter()
        parserWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let parserPlain = ISO8601DateFormatter()
        parserPlain.formatOptions = [.withInternetDateTime]

        guard let date = parserWithFractional.date(from: iso8601) ?? parserPlain.date(from: iso8601) else {
            return iso8601
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
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
