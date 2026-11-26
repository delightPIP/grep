import GrepCore
import RIBs

@MainActor
public protocol LoggedInDependency: Dependency {
    var authService: any AuthService { get }
    var httpTransport: any HTTPTransport { get }
}

/// 자식 → 부모. 라우팅은 부모가 정한다.
@MainActor
public protocol LoggedInListener: AnyObject {
    /// 사용자가 `로그아웃`을 쳐서 이 기기의 세션을 끝냈다.
    func didSignOut()
    /// 로그인이 만료됐다. `pendingInput`은 입력줄에 치던 줄이다(ACC-001 규칙 7).
    func didExpire(pendingInput: String)
}

@MainActor
public protocol LoggedInBuildable: Buildable {
    /// `restoredInput`은 만료 전에 치던 줄이다. 없으면 빈 문자열.
    func build(listener: any LoggedInListener, restoredInput: String) -> any ViewableRouting
}
