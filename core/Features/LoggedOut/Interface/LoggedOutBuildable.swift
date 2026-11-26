import GrepCore
import RIBs

@MainActor
public protocol LoggedOutDependency: Dependency {
    var authService: any AuthService { get }
}

/// 자식 → 부모: 로그인 성공. 라우팅은 부모가 정한다.
@MainActor
public protocol LoggedOutListener: AnyObject {
    func didSignIn()
}

@MainActor
public protocol LoggedOutBuildable: Buildable {
    /// `notice`는 화면이 뜰 때 보여 줄 알림이다(로그인 만료, 로그아웃). 없으면 nil.
    func build(listener: any LoggedOutListener, notice: LoggedOutViewState.Notice?) -> any ViewableRouting
}
