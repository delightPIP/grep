import FeatureTerminalInterface
import FeatureTerminalUI
import Foundation
import GrepCore

/// `TerminalViewState`를 순수 뷰 모델(`TerminalPresentation`)로 변환한다.
/// 정책 원문과 포맷 규칙은 `web/features/logged-in/view.tsx`와 동일하다.
/// 줄 종류별 변환은 명령 묶음마다 `TerminalStateMapper+<묶음>.swift`에 있고, 공용 형식기는 `TerminalTextFormat`이다.
public enum TerminalStateMapper {
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
            selection: state.selection.map {
                TerminalItemRef(number: $0.number, title: $0.title, tag: PickWord.tag(kind: $0.kind, source: $0.source, title: $0.title, number: $0.number))
            },
            input: state.input,
            isOffline: state.isOffline,
            pendingConfirm: pendingConfirm(lines: state.lines),
            revising: state.revising.map {
                TerminalRevisePresentation(number: $0.number, title: $0.title, summary: $0.summary)
            },
            offersSamples: state.itemCount == 0,
            itemCountLine: state.itemCount.map { "자료 \(TerminalTextFormat.groupedCount($0))건" }
        )
    }

    /// 마지막 확인 줄 뒤에 답(명령 줄)도 취소도 없으면 아직 기다리는 것이다(코어 `isWaitingForAnswer`와 같은 기준).
    private static func pendingConfirm(lines: [TerminalViewState.Line]) -> TerminalConfirmPrompt? {
        guard let askedIndex = lines.lastIndex(where: { confirmPrompt(for: $0) != nil }),
              let prompt = confirmPrompt(for: lines[askedIndex]) else {
            return nil
        }
        let answered = lines[askedIndex...].contains { line in
            switch line {
            case .prompt, .cancelled: true
            default: false
            }
        }
        return answered ? nil : prompt
    }

    /// 확인 질문 줄의 시트 문구와 실행 낱말(ARC-008 사용자 문구, COM-007).
    private static func confirmPrompt(for line: TerminalViewState.Line) -> TerminalConfirmPrompt? {
        switch line {
        case .dropConfirm(let total):
            TerminalConfirmPrompt(question: "버리기? \(total)건 (휴지통으로)", answer: "버리기")
        case .binEmptyConfirm(let total):
            TerminalConfirmPrompt(question: "비우기? \(total)건 (되돌릴 수 없음)", answer: "비우기")
        case .signOutEverywhereConfirm(let connectionCount):
            TerminalConfirmPrompt(question: "로그아웃?\(signOutEverywhereBody(connectionCount))", answer: "로그아웃")
        default:
            nil
        }
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

    /// 줄 종류를 명령 묶음별 변환으로 보낸다. 새 줄 종류가 생기면 여기서 컴파일 오류가 난다.
    private static func mapLine(
        _ line: TerminalViewState.Line,
        failed: Bool,
        pickedNumbers: Set<Int>
    ) -> [TerminalOutputBlockLine] {
        switch line {
        case .prompt, .unknownCommand, .missingArgument, .missingTag, .cancelled, .commandFailed,
             .welcome, .guide, .about, .reconnected:
            return mapIntroLine(line, failed: failed)
        case .saved, .alreadySaved, .inTrash, .saveFailed:
            return mapKeepLine(line, pickedNumbers: pickedNumbers)
        case .recentList, .searchResult, .noResults:
            return mapPeriodLine(line, pickedNumbers: pickedNumbers)
        case .picked, .notFound, .invalidNumber, .unpicked, .pickCleared:
            return mapPickLine(line)
        case .handedOff, .handoffFailed, .handoffConfirm:
            return mapHandoffLine(line)
        case .dropConfirm, .dropped, .revived, .binList, .binEmptyConfirm, .binEmptied:
            return mapTrashLine(line)
        case .revised, .tagsRemoved:
            return mapReviseLine(line)
        case .samplesSaved:
            return mapSamplesLine(line, pickedNumbers: pickedNumbers)
        case .signOutEverywhereConfirm:
            return mapSignOutEverywhereLine(line)
        case .bundleList, .bundleAdded, .bundleView, .bundleNotFound, .bundleUnpicked, .notInBundle,
             .bundleDeleteConfirm, .bundleDeleted, .bundleNameInvalid, .folderHint, .itemDetail, .oneNumberOnly,
             .searchSaved, .savedSearchList, .savedSearchPeriod, .savedSearchTooLong, .savedSearchDeleteConfirm,
             .savedSearchDeleted, .savedSearchNotFound, .connectionList, .disconnectConfirm, .disconnected,
             .connectionNotFound, .connectionEnded, .importPrompt, .importProgress, .importFinished,
             .importSuggest:
            // 후속 iOS 이슈(#109~)에서 정책 원문으로 추가한다.
            return []
        }
    }
}
