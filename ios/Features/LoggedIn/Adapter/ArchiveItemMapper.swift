import FeatureLoggedInUI
import Foundation
import GrepCore

/// `ItemSummary`와 보관함 오류를 순수 뷰 모델(`ArchiveItemRow`, 정책 문구)로 변환한다.
/// 행 글자 규칙은 코어 `ItemRowText`가 정한다(Android와 같다).
public enum ArchiveItemMapper {
    public static func mapRow(_ item: ItemSummary, isPicked: Bool) -> ArchiveItemRow {
        ArchiveItemRow(
            number: item.number,
            title: ItemRowText.title(item),
            meta: ItemRowText.meta(item),
            summary: ItemRowText.summary(item),
            summaryIsWarning: ItemRowText.isWarning(item),
            tags: ItemRowText.tags(item),
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

    /// 고른 것 줄의 `<종류 낱말> <번호>`(ARC-003 규칙 14). 터미널 `PickWord`와 같은 규칙이다(모듈이 달라 따로 둔다).
    static func pickTag(_ item: ItemSummary) -> String {
        let word: String
        switch item.kind {
        case .link:
            word = item.source.flatMap { $0.isEmpty ? nil : $0 } ?? "링크"
        case .text:
            word = "글"
        case .file:
            let fromTitle = item.title.range(of: #"\.([A-Za-z0-9]+)$"#, options: .regularExpression)
                .map { String(item.title[$0].dropFirst()) }
            word = (item.source.flatMap { $0.isEmpty ? nil : $0 } ?? fromTitle)?.uppercased() ?? "파일"
        }
        return "\(word) \(item.number)"
    }

    static func textTitle(_ title: String) -> String { ItemRowText.textTitle(title) }

    static func formatSavedAt(_ iso8601: String) -> String { ItemRowText.savedAt(iso8601) }
}
