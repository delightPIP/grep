import GrepCore
import RIBs

/// 저장에 실패한 뒤 사용자가 다시 넣는 길(ARC-005 규칙 2, #57 사용자 결정 2026-11-27).
public enum SaveRecovery: Equatable, Sendable {
    /// 넣으려던 줄을 입력줄에 되돌렸다. `  입력은 남겨 둠`
    case inputKept
    /// 그새 친 새 글이 있어 입력줄을 덮지 않았다. 다음 줄 `→ 다시: <명령>`
    case retry(String)
    /// 끌어다 놓은 파일. 원본은 사용자의 기기에 그대로 있다. ` (<파일 이름>)`
    case file(name: String)
}
