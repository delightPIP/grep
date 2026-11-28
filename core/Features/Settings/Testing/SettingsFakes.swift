import FeatureSettingsInterface
import RIBs

@MainActor
public final class FakeSettingsView: SettingsViewContract {
    public weak var listener: (any SettingsPresentableListener)?
    /// 그려진 상태를 순서대로 모은다.
    public private(set) var states: [SettingsState?] = []
    public var state: SettingsState? { states.last ?? nil }

    public init() {}

    public func render(_ state: SettingsState?) { states.append(state) }
}

@MainActor
public final class FakeSettingsViewFactory: SettingsViewFactory {
    public private(set) var views: [FakeSettingsView] = []

    public init() {}

    public func makeSettingsView() -> any SettingsViewContract {
        let view = FakeSettingsView()
        views.append(view)
        return view
    }
}

@MainActor
public final class FakeSettingsListener: SettingsListener {
    public private(set) var expiredCount = 0

    public init() {}

    public func settingsDidExpire() { expiredCount += 1 }
}
