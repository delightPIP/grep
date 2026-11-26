import GrepCore
import RIBs

/// 터미널 화면에 그릴 값 전체. 문구는 담지 않는다(플랫폼 뷰가 정책 원문으로 바꾼다).
public struct LoggedInViewState: Equatable, Sendable {
    /// 출력 한 줄. #31에서 쓰는 것만 둔다. 다른 이슈가 case를 더한다.
    public enum Line: Equatable, Sendable {
        /// 사용자가 친 명령 줄(`그렙 ~ $ <text>`).
        case prompt(String)
        /// `✗ 없는 명령: <name>`
        case unknownCommand(String)
    }

    /// 상태줄 `자료 N`. 서버 `GET /me`의 itemCount. 받기 전이면 nil.
    public var itemCount: Int?
    public var lines: [Line]
    /// 입력줄 내용. 로그인 만료 뒤 다시 로그인하면 되살린 값이 들어온다(ACC-001 규칙 7).
    public var input: String

    public init(itemCount: Int? = nil, lines: [Line] = [], input: String = "") {
        self.itemCount = itemCount
        self.lines = lines
        self.input = input
    }
}

/// 뷰 → 코어.
public enum LoggedInViewAction: Equatable, Sendable {
    /// 입력줄이 바뀌었다. 코어가 만료 때 보존할 줄을 알기 위해 받는다.
    case inputChanged(String)
    /// 엔터.
    case submitted(String)
}

@MainActor
public protocol LoggedInPresentableListener: AnyObject {
    func handle(_ action: LoggedInViewAction)
}

@MainActor
public protocol LoggedInPresentable: Presentable {
    var listener: (any LoggedInPresentableListener)? { get set }
    func render(_ state: LoggedInViewState)
}

@MainActor
public protocol LoggedInViewControllable: ViewControllable {}

@MainActor
public protocol LoggedInViewContract: LoggedInPresentable, LoggedInViewControllable {}

@MainActor
public protocol LoggedInViewFactory: AnyObject {
    func makeLoggedInView() -> any LoggedInViewContract
}
