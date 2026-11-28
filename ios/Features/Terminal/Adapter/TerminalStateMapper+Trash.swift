import FeatureTerminalInterface
import FeatureTerminalUI
import Foundation
import GrepCore

// 버리기·되살리기·휴지통(ARC-008).
extension TerminalStateMapper {
    /// 빈 휴지통. 정책 문구가 없어 웹과 같은 문구를 쓴다.
    private static let emptyBinLine = TerminalOutputBlockLine.status(tone: .info, boldPrefix: nil, body: "휴지통 비어 있음")

    static func mapTrashLine(_ line: TerminalViewState.Line) -> [TerminalOutputBlockLine] {
        switch line {
        case .dropConfirm(let total):
            // ARC-008 사용자 문구. 답은 확인 시트의 낱말 버튼으로 받는다(MOB-002 규칙 4, 시안 M9).
            return [.status(tone: .warn, boldPrefix: "버리기?", body: " \(total)건 (휴지통으로)")]
        case .dropped(let items):
            // ARC-008 사용자 문구. 되살리기는 `<번호...>`를 받으므로 옮긴 번호를 모두 적는다.
            let numbers = items.map { String($0.number) }.joined(separator: " ")
            return [.status(tone: .ok, boldPrefix: "휴지통 \(items.count)건", body: " (30일 뒤 삭제, 되살리기 \(numbers))")]
        case .revived(let items):
            // ARC-008 사용자 문구.
            return [.status(tone: .ok, boldPrefix: "되살림 \(items.count)건", body: "")]
        case .binList(let total, let items, let hasMore):
            // ARC-008 규칙 5. 순서는 서버가 지운 날 최신순으로 준다.
            guard total > 0 else { return [emptyBinLine] }
            return [.trashList(header: TerminalTextFormat.countHeader(total: total, shown: items.count), rows: items.map(mapTrashRow), hasMore: hasMore)]
        case .binEmptyConfirm(let total):
            // ARC-008 사용자 문구. 답은 확인 시트의 낱말 버튼으로 받는다(MOB-002 규칙 4, 시안 M11 ②).
            return [.status(tone: .warn, boldPrefix: "비우기?", body: " \(total)건 (되돌릴 수 없음)")]
        case .binEmptied(let count):
            // 빈 휴지통을 비우면 `0건 영구 삭제` 대신 비어 있다고만 알린다(웹과 같음).
            guard count > 0 else { return [emptyBinLine] }
            // ARC-008 사용자 문구.
            return [.status(tone: .ok, boldPrefix: "비움", body: "  \(count)건 영구 삭제")]
        default:
            return []
        }
    }

    /// 휴지통 행. 시각 칸에 영구 삭제까지 남은 날(ARC-008 규칙 10).
    private static func mapTrashRow(_ entry: TrashEntry) -> TerminalTrashRow {
        let item = entry.item
        let title = item.kind == .text ? TerminalTextFormat.textTitle(item.title) : item.title
        let metaParts = [item.source, "\(entry.daysLeft)일 남음"].compactMap { $0 }.filter { !$0.isEmpty }
        return TerminalTrashRow(number: item.number, title: title, meta: metaParts.joined(separator: " · "))
    }
}
