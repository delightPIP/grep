import GrepCore
import RIBs

@MainActor
public protocol LoggedInDependency: Dependency {
    var authService: any AuthService { get }
    var httpTransport: any HTTPTransport { get }
    /// `넘기기`가 넘길 글을 넣는다(COM-008).
    var clipboard: any ClipboardPort { get }
    /// 끌어다 놓은 파일을 올린다(COM-004).
    var files: any FilePort { get }
    /// 터미널 기록을 이 기기에 남긴다(COM-009).
    var historyStore: any HistoryStore { get }
}

/// 만료 때 입력줄에 치던 줄과, 그 줄을 친 계정(접근 토큰의 `sub`).
/// 같은 계정으로 다시 로그인했을 때만 되살린다(ACC-001 규칙 7, COM-009 규칙 3·4).
public struct PendingInput: Equatable, Sendable {
    public let text: String
    public let subject: String

    public init(text: String, subject: String) {
        self.text = text
        self.subject = subject
    }
}

/// 자식 → 부모. 라우팅은 부모가 정한다.
@MainActor
public protocol LoggedInListener: AnyObject {
    /// 사용자가 `로그아웃`을 쳐서 이 기기의 세션을 끝냈다.
    func didSignOut()
    /// 로그인이 만료됐다. 되살릴 줄이 없거나 계정을 알 수 없으면 nil.
    func didExpire(pendingInput: PendingInput?)
}

@MainActor
public protocol LoggedInBuildable: Buildable {
    /// `pendingInput`은 만료 전에 치던 줄이다. 로그인한 계정이 같을 때만 입력줄에 되살린다.
    func build(listener: any LoggedInListener, pendingInput: PendingInput?) -> any ViewableRouting
}
