import GrepCore
import RIBs

/// 로그인 화면(W1·W2·W3·W10)에 그릴 값 전체. 플랫폼은 이 값만 보고 그린다.
/// 문구는 담지 않는다. 플랫폼 뷰가 ACC-001 사용자 문구 원문으로 바꾼다.
public struct LoggedOutViewState: Equatable, Sendable {
    public enum Notice: Equatable, Sendable {
        /// `✗ 로그인 취소됨`
        case cancelled
        /// `✗ 로그인 실패: <이유>`
        case failed(SignInFailureReason)
        /// `! 로그인 만료 → 다시 로그인`
        case expired
        /// `✓ 로그아웃됨`
        case signedOut
    }

    public var notice: Notice?
    /// 로그인 창이 열려 있다. 이때 버튼을 눌러도 창을 하나 더 띄우지 않는다(ACC-001 규칙 9).
    public var isSigningIn: Bool

    public init(notice: Notice? = nil, isSigningIn: Bool = false) {
        self.notice = notice
        self.isSigningIn = isSigningIn
    }
}

/// 뷰 → 코어.
public enum LoggedOutViewAction: Equatable, Sendable {
    case signInTapped(AuthProvider)
}

@MainActor
public protocol LoggedOutPresentableListener: AnyObject {
    func handle(_ action: LoggedOutViewAction)
}

/// 코어 → 뷰. 플랫폼이 구현한다.
@MainActor
public protocol LoggedOutPresentable: Presentable {
    var listener: (any LoggedOutPresentableListener)? { get set }
    func render(_ state: LoggedOutViewState)
}

@MainActor
public protocol LoggedOutViewControllable: ViewControllable {}

@MainActor
public protocol LoggedOutViewContract: LoggedOutPresentable, LoggedOutViewControllable {}

@MainActor
public protocol LoggedOutViewFactory: AnyObject {
    func makeLoggedOutView() -> any LoggedOutViewContract
}
