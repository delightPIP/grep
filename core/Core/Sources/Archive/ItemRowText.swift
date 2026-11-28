#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// 보관함 목록 한 행의 글자(ARC-004, ARC-005, #91). iOS·Android 보관함 화면이 같은 규칙을 쓴다.
public enum ItemRowText {
    private static let listTagLimit = 3
    private static let textTitleLimit = 24
    private static let kstOffsetSeconds = 9 * 3600

    /// 글 자료는 첫 줄 24자까지(끝 공백은 뺀다), 나머지는 제목 그대로.
    public static func title(_ item: ItemSummary) -> String {
        item.kind == .text ? textTitle(item.title) : item.title
    }

    /// `<출처> · <저장 시각>`. 출처가 없으면 시각만.
    public static func meta(_ item: ItemSummary) -> String {
        [item.source, savedAt(item.savedAt)].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// 흐린 요약 줄. 처리 중·막힘·실패는 상태 문구(ARC-005), 요약이 없으면 nil.
    public static func summary(_ item: ItemSummary) -> String? {
        if item.status == .received || item.status == .processing { return "· 요약 생성 중" }
        if item.status == .blocked { return "! 본문 못 가져옴 → 고치기 \(item.number)" }
        if item.status == .failed { return "! 요약 못 만듦  제목·출처만 넘김" }
        guard let summary = item.listSummary else { return nil }
        if let partial = item.partialNote, !partial.isEmpty {
            return "\(summary) (\(partial))"
        }
        return summary
    }

    /// 요약 줄을 경고 색으로 그릴지.
    public static func isWarning(_ item: ItemSummary) -> Bool {
        item.status == .blocked || item.status == .failed
    }

    /// 목록은 태그 앞 3개만(ARC-002 규칙 4).
    public static func tags(_ item: ItemSummary) -> [String] {
        Array(item.tags.prefix(listTagLimit))
    }

    public static func textTitle(_ title: String) -> String {
        let firstLine = title.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        var clipped = String(firstLine.prefix(textTitleLimit))
        while let last = clipped.last, last.isWhitespace { clipped.removeLast() }
        return clipped
    }

    /// ARC-004 규칙 7: 저장 시각은 한국 시간 `yyyy-MM-dd HH:mm`. 읽지 못하면 받은 글 그대로.
    public static func savedAt(_ rfc3339: String) -> String {
        let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let plain = Date.ISO8601FormatStyle()
        guard let date = (try? withFraction.parse(rfc3339)) ?? (try? plain.parse(rfc3339)),
              let kst = TimeZone(secondsFromGMT: kstOffsetSeconds) else {
            return rfc3339
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = kst
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return "\(pad(c.year, 4))-\(pad(c.month))-\(pad(c.day)) \(pad(c.hour)):\(pad(c.minute))"
    }

    private static func pad(_ value: Int?, _ width: Int = 2) -> String {
        let text = String(value ?? 0)
        return String(repeating: "0", count: max(0, width - text.count)) + text
    }
}
