import FeatureTerminalInterface
import FeatureTerminalUI
import Foundation
import GrepCore

/// `TerminalViewState`를 순수 뷰 모델(`TerminalPresentation`)로 변환한다.
/// 정책 원문과 포맷 규칙은 `web/features/logged-in/view.tsx`와 동일하다.
public enum TerminalStateMapper {
    private static let listTagLimit = 3
    private static let textTitleLimit = 24
    private static let bytesPerMB = 1024.0 * 1024.0
    private static let handoffDirectLimit = 5
    private static let handoffFirstLimit = 10

    private static let guideRows: [TerminalGuideRow] = [
        TerminalGuideRow(name: "담기", english: "keep", meaning: "자료 저장"),
        TerminalGuideRow(name: "최근", english: "recent", meaning: "최근 자료 목록"),
        TerminalGuideRow(name: "찾기", english: "seek", meaning: "검색"),
        TerminalGuideRow(name: "고르기", english: "pick", meaning: "번호로 선택"),
        TerminalGuideRow(name: "넘기기", english: "handoff", meaning: "AI 도구용 글 복사"),
        TerminalGuideRow(name: "묶음", english: "pack", meaning: "선택에 이름 붙이기"),
        TerminalGuideRow(name: "고치기", english: "revise", meaning: "제목·요약 수정"),
        TerminalGuideRow(name: "버리기", english: "drop", meaning: "삭제"),
        TerminalGuideRow(name: "가져오기", english: "bring", meaning: "북마크 파일 가져오기"),
        TerminalGuideRow(name: "연결", english: "plug", meaning: "AI 도구 연결"),
        TerminalGuideRow(name: "로그아웃", english: "signout", meaning: "로그아웃"),
        TerminalGuideRow(name: "도움말", english: "guide", meaning: "명령 목록"),
        TerminalGuideRow(name: "설명", english: "about", meaning: "명령 설명"),
    ]

    public static func map(_ state: TerminalViewState) -> TerminalPresentation {
        let pickedNumbers = Set(state.selection.map(\.number))
        return TerminalPresentation(
            title: windowTitle(lines: state.lines),
            statusText: statusText(
                itemCount: state.itemCount,
                selectionCount: state.selection.count,
                processingCount: state.processingCount,
                isOffline: state.isOffline
            ),
            blocks: mapBlocks(lines: state.lines, pickedNumbers: pickedNumbers),
            selection: state.selection.map { TerminalItemRef(number: $0.number, title: $0.title) },
            input: state.input,
            isOffline: state.isOffline
        )
    }

    private static func windowTitle(lines: [TerminalViewState.Line]) -> String {
        for line in lines.reversed() {
            if case .prompt(let text) = line {
                let firstWord = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    .split(whereSeparator: \.isWhitespace)
                    .first
                    .map(String.init)
                if let firstWord, !firstWord.isEmpty {
                    return firstWord
                }
            }
        }
        return "처음"
    }

    private static func statusText(
        itemCount: Int?,
        selectionCount: Int,
        processingCount: Int,
        isOffline: Bool
    ) -> String {
        var parts: [String] = []
        if let itemCount {
            parts.append("자료 \(itemCount)")
        } else {
            parts.append("자료")
        }
        parts.append("선택 \(selectionCount)")
        if processingCount > 0 {
            parts.append("요약 생성 중 \(processingCount)")
        }
        if isOffline {
            parts.append("연결 끊김")
        }
        return parts.joined(separator: " · ")
    }

    private static func mapBlocks(
        lines: [TerminalViewState.Line],
        pickedNumbers: Set<Int>
    ) -> [TerminalOutputBlock] {
        var grouped: [[TerminalViewState.Line]] = []
        for line in lines {
            if case .prompt = line {
                grouped.append([line])
            } else if grouped.isEmpty {
                grouped.append([line])
            } else {
                grouped[grouped.count - 1].append(line)
            }
        }

        return grouped.enumerated().map { index, blockLines in
            let failed = blockLines.contains { line in
                if case .unknownCommand = line { return true }
                return false
            }
            let mapped = blockLines.flatMap { mapLine($0, failed: failed, pickedNumbers: pickedNumbers) }
            return TerminalOutputBlock(id: index, lines: mapped)
        }
    }

    private static func mapLine(
        _ line: TerminalViewState.Line,
        failed: Bool,
        pickedNumbers: Set<Int>
    ) -> [TerminalOutputBlockLine] {
        switch line {
        case .prompt(let text):
            return [.prompt(command: text, failed: failed)]
        case .unknownCommand(let name, _):
            return [.status(tone: .error, boldPrefix: "없는 명령:", body: " \(name)")]
        case .missingArgument(let command):
            switch command {
            case .keep:
                return [.status(tone: .error, boldPrefix: nil, body: "저장할 것 없음  예: 담기 https://…")]
            case .seek:
                return [.status(tone: .error, boldPrefix: nil, body: "검색어 없음  예: 찾기 결제")]
            case .pick:
                return [.status(tone: .error, boldPrefix: nil, body: "번호 없음  예: 고르기 131")]
            default:
                return []
            }
        case .missingTag:
            return [.status(tone: .error, boldPrefix: nil, body: "태그 없음  예: 찾기 #결제")]
        case .saved(let item):
            let headline = item.kind == .text
                ? "저장됨 (글)  \(textTitle(item.title))"
                : "저장됨  \(withSource(item))"
            var result: [TerminalOutputBlockLine] = [.status(tone: .ok, boldPrefix: nil, body: headline)]
            if isProcessing(item) {
                result.append(.plain(text: "· 요약 생성 중", dim: true))
            }
            return result
        case .alreadySaved(let item):
            return [
                .status(tone: .warn, boldPrefix: nil, body: "이미 저장됨 → \(item.number)번 (새로 만들지 않음)"),
                .itemRow(mapRow(item, isPicked: pickedNumbers.contains(item.number))),
                .commandHint(prefix: "→ ", command: "고르기 \(item.number)", suffix: ""),
            ]
        case .inTrash(let number):
            return [.status(tone: .warn, boldPrefix: nil, body: "휴지통에 있음 → \(number)번. 되살리기 \(number)")]
        case .saveFailed(let reason, let recovery):
            let headline = "저장 안 됨: \(failureText(reason))\(recoverySuffix(reason, recovery))"
            var result: [TerminalOutputBlockLine] = [.status(tone: .error, boldPrefix: nil, body: headline)]
            if case .retry(let command) = recovery {
                result.append(.commandHint(prefix: "→ 다시: ", command: command, suffix: ""))
            }
            return result
        case .recentList(let items, let hasMore, _, _):
            return [.list(
                header: nil,
                items: items.map { mapRow($0, isPicked: pickedNumbers.contains($0.number)) },
                hasMore: hasMore
            )]
        case .searchResult(_, let total, let items, let hasMore, _):
            let header = items.count < total ? "\(total)건 중 \(items.count)건" : "\(total)건"
            return [.list(
                header: header,
                items: items.map { mapRow($0, isPicked: pickedNumbers.contains($0.number)) },
                hasMore: hasMore
            )]
        case .noResults(let query, let recent, _):
            var result: [TerminalOutputBlockLine] = [
                .status(tone: .info, boldPrefix: nil, body: #"0건: "\#(query.text)""#),
            ]
            if !recent.isEmpty {
                result.append(.status(tone: .info, boldPrefix: nil, body: "최근 저장 \(recent.count)건 (검색 결과 아님)"))
                result.append(.list(
                    header: nil,
                    items: recent.map { mapRow($0, isPicked: pickedNumbers.contains($0.number)) },
                    hasMore: false
                ))
            }
            return result
        case .picked(let items):
            let titleList = items.map(\.title).joined(separator: " · ")
            return [
                .status(tone: .ok, boldPrefix: nil, body: "선택 \(items.count)건  \(titleList)"),
                .commandHint(prefix: "→ ", command: "넘기기", suffix: " 또는 묶음 <이름>"),
            ]
        case .notFound(let numbers):
            let list = numbers.map(String.init).joined(separator: ", ")
            return [.status(tone: .error, boldPrefix: nil, body: "없는 번호: \(list)")]
        case .invalidNumber(let input):
            return [.status(tone: .error, boldPrefix: nil, body: "잘못된 번호: \(input)  예: 고르기 131 140")]
        case .handedOff(let result):
            return [.handedOff(TerminalHandoffPresentation(
                items: result.items.map { TerminalItemRef(number: $0.number, title: $0.title) },
                charCountText: formatCharCount(result.charCount),
                missingSummaryCount: result.missingSummaryCount,
                text: result.text
            ))]
        case .handoffFailed(let reason, let preview):
            return [.handoffFailed(
                reasonLabel: commandFailureLabel(reason),
                preview: preview,
                isClipboardDenied: reason == .clipboardDenied
            )]
        case .handoffConfirm(let total):
            var choices: [TerminalChoiceItem] = []
            if total > handoffFirstLimit {
                choices.append(TerminalChoiceItem(command: "앞\(handoffFirstLimit)", label: "앞 \(handoffFirstLimit)건만"))
            }
            choices.append(TerminalChoiceItem(command: "전부", label: "\(total)건 전부"))
            choices.append(TerminalChoiceItem(command: "취소", label: "그 외 입력"))
            return [.handoffConfirm(total: total, choices: choices)]
        case .cancelled:
            return [.status(tone: .info, boldPrefix: nil, body: "취소됨")]
        case .commandFailed(let command, let reason, let retry):
            return [
                .status(tone: .error, boldPrefix: nil, body: "\(commandLabel(command)) 안 됨: \(commandFailureLabel(reason))"),
                .commandHint(prefix: "→ 다시: ", command: retry, suffix: ""),
            ]
        case .welcome:
            return [.welcome]
        case .guide:
            return [.guide(rows: guideRows)]
        case .about(let command):
            return [.status(tone: .info, boldPrefix: "\(commandLabel(command))", body: "  \(aboutDescription(command))")]
        case .reconnected:
            return [.status(tone: .ok, boldPrefix: nil, body: "연결됨")]
        case .dropConfirm, .dropped, .revived, .binList, .binEmptyConfirm, .binEmptied,
             .revised, .tagsRemoved, .samplesSaved, .unpicked, .pickCleared, .signOutEverywhereConfirm:
            // 후속 iOS 이슈(#94~)에서 정책 원문으로 추가한다.
            return []
        }
    }

    private static func mapRow(_ item: ItemSummary, isPicked: Bool) -> TerminalItemRow {
        let title = item.kind == .text ? textTitle(item.title) : item.title
        let savedAt = formatSavedAt(item.savedAt)
        let metaParts = [item.source, savedAt].compactMap { $0 }.filter { !$0.isEmpty }
        let matchLabel: String? = item.matchedIn == .imageText ? "이미지 속 글자" : nil
        return TerminalItemRow(
            number: item.number,
            title: title,
            meta: metaParts.joined(separator: " · "),
            summary: rowSummary(item),
            summaryIsWarning: item.status == .blocked || item.status == .failed,
            matchLabel: matchLabel,
            tags: Array(item.tags.prefix(listTagLimit)),
            isPicked: isPicked
        )
    }

    private static func isProcessing(_ item: ItemSummary) -> Bool {
        item.status == .received || item.status == .processing
    }

    private static func withSource(_ item: ItemSummary) -> String {
        if let source = item.source, !source.isEmpty {
            return "\(item.title) (\(source))"
        }
        return item.title
    }

    private static func textTitle(_ title: String) -> String {
        let firstLine = title.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        return String(firstLine.prefix(textTitleLimit)).replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
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

    private static func failureText(_ reason: SaveFailure) -> String {
        switch reason {
        case .disconnected: "연결 끊김"
        case .timedOut: "응답 없음"
        case .serverError: "서버 오류"
        case .unsupportedFormat(let ext): "받지 않는 형식 (.\(ext))"
        case .tooLarge(let fileName, let bytes): "20MB 넘음 (\(fileName) · \(formatMegabytes(bytes)))"
        }
    }

    private static func recoverySuffix(_ reason: SaveFailure, _ recovery: SaveRecovery) -> String {
        switch recovery {
        case .inputKept:
            return "  입력은 남겨 둠"
        case .file(let name):
            switch reason {
            case .disconnected, .timedOut, .serverError:
                return " (\(name))"
            case .unsupportedFormat, .tooLarge:
                return ""
            }
        case .retry:
            return ""
        }
    }

    private static func formatMegabytes(_ bytes: Int) -> String {
        let rounded = (Double(bytes) / bytesPerMB * 10).rounded() / 10
        return rounded.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(rounded))MB"
            : String(format: "%.1fMB", rounded)
    }

    private static func formatCharCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ko_KR")
        let formatted = formatter.string(from: NSNumber(value: count)) ?? String(count)
        return "\(formatted)자"
    }

    private static func commandLabel(_ command: CommandName) -> String {
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
        }
    }

    private static func aboutDescription(_ command: CommandName) -> String {
        switch command {
        case .keep: "링크·글 저장  예: 담기 https://…"
        case .recent: "최근 자료 목록  예: 최근"
        case .seek: "검색어·#태그 검색  예: 찾기 결제 #sdk"
        case .pick: "번호로 자료 선택  예: 고르기 131 140"
        case .handoff: "선택한 자료를 AI 도구용 글로 복사  예: 넘기기"
        case .guide: "전체 명령 목록  예: 도움말"
        case .about: "명령 사용법 안내  예: 설명 찾기"
        case .signOut: "이 기기의 세션 종료  예: 로그아웃"
        }
    }

    private static func commandFailureLabel(_ reason: CommandFailure) -> String {
        switch reason {
        case .disconnected: "연결 끊김"
        case .timedOut: "응답 없음"
        case .serverError: "서버 오류"
        case .clipboardDenied: "클립보드 거부"
        }
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
