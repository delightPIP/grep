import FeatureTerminalInterface
import Foundation
import GrepCore

/// 터미널 문구 공용 형식기: 날짜, 건수, MB, 글자 수, 명령 이름, 실패 문구.
enum TerminalTextFormat {
    private static let textTitleLimit = 24
    private static let bytesPerMB = 1024.0 * 1024.0

    /// ARC-004 규칙 7: 저장 시각은 한국 시간(`Asia/Seoul`) `yyyy-MM-dd HH:mm`.
    static func savedAt(_ iso8601: String) -> String {
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

    /// 웹 `toLocaleString("ko-KR")`과 같은 천 단위 쉼표.
    static func groupedCount(_ count: Int) -> String {
        count.formatted(.number.grouping(.automatic).locale(Locale(identifier: "ko_KR")))
    }

    /// 목록 머리 줄. 다음 쪽이 남았으면 `12건 중 1건`(commands 6절).
    static func countHeader(total: Int, shown: Int) -> String {
        shown < total ? "\(total)건 중 \(shown)건" : "\(total)건"
    }

    /// 글 자료 제목: 첫 줄을 24자로 자르고 끝 공백을 뗀다.
    static func textTitle(_ title: String) -> String {
        let firstLine = title.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        return String(firstLine.prefix(textTitleLimit)).replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
    }

    static func megabytes(_ bytes: Int) -> String {
        let rounded = (Double(bytes) / bytesPerMB * 10).rounded() / 10
        return rounded.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(rounded))MB"
            : String(format: "%.1fMB", rounded)
    }

    static func charCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ko_KR")
        let formatted = formatter.string(from: NSNumber(value: count)) ?? String(count)
        return "\(formatted)자"
    }

    static func commandLabel(_ command: CommandName) -> String {
        switch command {
        case .keep: "담기"
        case .recent: "최근"
        case .seek: "찾기"
        case .pick: "고르기"
        case .handoff: "넘기기"
        case .guide: "도움말"
        case .about: "설명"
        case .signOut: "로그아웃"
        case .revise: "고치기"
        case .drop: "버리기"
        case .revive: "되살리기"
        case .bin: "휴지통"
        case .pack: "묶음"
        case .peek: "열기"
        case .gather: "찾아두기"
        case .bring: "가져오기"
        case .plug: "연결"
        }
    }

    static func commandFailureLabel(_ reason: CommandFailure) -> String {
        switch reason {
        case .disconnected: "연결 끊김"
        case .timedOut: "응답 없음"
        case .serverError: "서버 오류"
        case .clipboardDenied: "클립보드 거부"
        }
    }
}
