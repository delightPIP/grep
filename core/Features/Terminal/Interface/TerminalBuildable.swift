import GrepCore
import RIBs

@MainActor
public protocol TerminalDependency: Dependency {
    var authService: any AuthService { get }
    var httpTransport: any HTTPTransport { get }
    /// `넘기기`가 넘길 글을 넣는다(COM-008).
    var clipboard: any ClipboardPort { get }
    /// 끌어다 놓은 파일을 올린다(COM-004).
    var files: any FilePort { get }
    /// 터미널 기록을 이 기기에 남긴다(COM-009).
    var historyStore: any HistoryStore { get }
    /// 처리 중 자료 폴링(ARC-005)과 다시 연결 확인(COM-010)의 주기를 기다린다.
    var sleeper: any Sleeper { get }
}

/// 터미널 → 부모(컨테이너). 세션을 끝내는 일은 부모가 한다.
@MainActor
public protocol TerminalListener: AnyObject {
    /// 사용자가 `로그아웃`을 쳤다.
    func didRequestSignOut()
    /// 서버가 세션 만료로 답했거나 접근 토큰을 받지 못했다. `input`은 그때 입력줄에 있던 줄이다(ACC-001 규칙 7).
    func didExpire(input: String)
}

/// 부모(컨테이너) → 터미널. 계정에 딸린 값은 컨테이너가 받아 넘긴다.
@MainActor
public protocol TerminalHandle: AnyObject {
    /// 지금 입력줄에 있는 줄.
    var input: String { get }
    /// 만료 전에 치던 줄을 입력줄에 되살린다. 사용자가 그새 친 글이 있으면 덮어쓰지 않는다.
    func restoreInput(_ text: String)
    /// 상태줄 `자료 N`(서버 `GET /me`의 itemCount).
    func showItemCount(_ itemCount: Int)
    /// 컨테이너의 요청이 서버에 닿았는지. 터미널 자신의 요청과 같이 `연결 끊김` 표시에 쓴다(COM-010).
    func observeReachability(_ isReachable: Bool)
}

/// 붙일 Router와, 붙인 뒤 값을 넘길 손잡이.
@MainActor
public struct TerminalBuild {
    public let router: any ViewableRouting
    public let handle: any TerminalHandle

    public init(router: any ViewableRouting, handle: any TerminalHandle) {
        self.router = router
        self.handle = handle
    }
}

@MainActor
public protocol TerminalBuildable: Buildable {
    func build(listener: any TerminalListener) -> TerminalBuild
}
