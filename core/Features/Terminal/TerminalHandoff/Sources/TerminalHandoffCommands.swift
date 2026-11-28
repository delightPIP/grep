import GrepCore
import TerminalCommandKit
import TerminalDomain

/// `고르기`·`넘기기`·`찾기 … | 넘기기`(commands 3절, COM-008). 기능별 코드는 같은 이름의 확장 파일에 있다.
public final class TerminalHandoffCommands: TerminalCommandBase, TerminalCommand {
    /// 답을 기다리는 `찾기 … | 넘기기` 확인. 다음 입력 한 번이 답이다(COM-007 규칙 1).
    var pendingHandoff: PendingHandoff?

    public var hasPendingAnswer: Bool { pendingHandoff != nil }

    public func answer(_ text: String) -> Bool {
        guard let pending = pendingHandoff, let choice = pending.choice(for: text) else { return false }
        pendingHandoff = nil
        confirmHandoff(pending, choice: choice, typed: text)
        return true
    }

    public func cancelPendingAnswer() {
        pendingHandoff = nil
    }
}
