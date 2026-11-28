import GrepCore
import TerminalCommandKit
import TerminalDomain

/// `묶음`·`버리기`·`되살리기`·`휴지통`·`고치기`(ARC-003, ARC-008, ARC-004). 기능별 코드는 같은 이름의 확장 파일에 있다.
public final class TerminalCollectionCommands: TerminalCommandBase, TerminalCommand {
    /// 답을 기다리는 `버리기` 2건 이상 확인(ARC-008 규칙 1, COM-007).
    var pendingDrop: PendingDrop?
    /// 답을 기다리는 `휴지통 비우기` 확인(ARC-008 규칙 6, COM-007).
    var pendingBinEmpty: PendingBinEmpty?
    /// 답을 기다리는 `묶음 <이름> 지우기` 확인(ARC-003 규칙 8, COM-007).
    var pendingBundleDelete: PendingBundleDelete?

    public var hasPendingAnswer: Bool { pendingDrop != nil || pendingBinEmpty != nil || pendingBundleDelete != nil }

    public func answer(_ text: String) -> Bool {
        if let pending = pendingDrop, pending.matches(text) {
            pendingDrop = nil
            confirmDrop(pending, typed: text)
            return true
        }
        if let pending = pendingBinEmpty, pending.matches(text) {
            pendingBinEmpty = nil
            confirmBinEmpty(typed: text)
            return true
        }
        if let pending = pendingBundleDelete, pending.matches(text) {
            pendingBundleDelete = nil
            confirmBundleDelete(pending, typed: text)
            return true
        }
        return false
    }

    public func cancelPendingAnswer() {
        pendingDrop = nil
        pendingBinEmpty = nil
        pendingBundleDelete = nil
    }
}
