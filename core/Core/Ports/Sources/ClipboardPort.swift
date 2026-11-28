/// 클립보드에 글을 넣는다. 플랫폼이 구현한다(웹: navigator.clipboard).
@MainActor
public protocol ClipboardPort: AnyObject {
    /// 넣었으면 `.copied`, 브라우저·OS가 막았으면 `.denied`(COM-008 `클립보드 거부`).
    func copy(_ text: String) async -> ClipboardResult
}

public enum ClipboardResult: Equatable, Sendable {
    case copied
    case denied
}
