import GrepCore
import RIBs

/// 뷰 → 코어. 연결 끊기·로그아웃·휴지통은 터미널에 있던 명령을 그대로 쓴다.
public enum SettingsViewAction: Equatable, Sendable {
    /// 설정 탭을 열었다. 계정과 AI 도구 연결을 받는다.
    case open
}

@MainActor
public protocol SettingsPresentableListener: AnyObject {
    func handle(_ action: SettingsViewAction)
}

/// 코어 → 뷰. 처음 열기 전이면 nil을 그린다.
@MainActor
public protocol SettingsPresentable: Presentable {
    var listener: (any SettingsPresentableListener)? { get set }
    func render(_ state: SettingsState?)
}

@MainActor
public protocol SettingsViewControllable: ViewControllable {}

@MainActor
public protocol SettingsViewContract: SettingsPresentable, SettingsViewControllable {}

@MainActor
public protocol SettingsViewFactory: AnyObject {
    func makeSettingsView() -> any SettingsViewContract
}

/// 설정 화면을 아직 그리지 않는 플랫폼이 쓰는 빈 뷰. 받은 상태를 버린다.
@MainActor
public final class HeadlessSettingsView: SettingsViewContract {
    public weak var listener: (any SettingsPresentableListener)?

    public init() {}

    public func render(_ state: SettingsState?) {}
}
