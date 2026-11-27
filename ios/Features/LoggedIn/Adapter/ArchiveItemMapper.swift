import FeatureLoggedInUI
import Foundation
import GrepCore

/// `ItemSummary`와 보관함 오류를 순수 뷰 모델(`ArchiveItemRow`, 정책 문구)로 변환한다.
public enum ArchiveItemMapper {
    private static let listTagLimit = 3
    private static let textTitleLimit = 24

    public static func mapRow(_ item: ItemSummary, isPicked: Bool) -> ArchiveItemRow {
        let title = item.kind == .text ? textTitle(item.title) : item.title
        let savedAt = formatSavedAt(item.savedAt)
        let metaParts = [item.source, savedAt].compactMap { $0 }.filter { !$0.isEmpty }
        return ArchiveItemRow(
            number: item.number,
            title: title,
            meta: metaParts.joined(separator: " · "),
            summary: rowSummary(item),
            summaryIsWarning: item.status == .blocked || item.status == .failed,
            tags: Array(item.tags.prefix(listTagLimit)),
            isPicked: isPicked
        )
    }

    public static func errorMessage(_ reason: ArchiveLoadFailure) -> String {
        switch reason {
        case .disconnected: "연결 끊김"
        case .timedOut: "응답 없음"
        case .serverError: "서버 오류"
        }
    }

    private static func isProcessing(_ item: ItemSummary) -> Bool {
        item.status == .received || item.status == .processing
    }

    private static func textTitle(_ title: String) -> String {
        let firstLine = title.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        return String(firstLine.prefix(textTitleLimit))
            .replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
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
