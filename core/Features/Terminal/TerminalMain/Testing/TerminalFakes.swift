import FeatureTerminalInterface
import TerminalDomain
import GrepCoreTesting
import RIBs

@MainActor
public final class FakeTerminalView: TerminalViewContract {
    public weak var listener: (any TerminalPresentableListener)?
    /// 그려진 상태를 순서대로 모은다.
    public private(set) var states: [TerminalViewState] = []
    public var state: TerminalViewState? { states.last }

    public init() {}

    public func render(_ state: TerminalViewState) { states.append(state) }
}

@MainActor
public final class FakeTerminalViewFactory: TerminalViewFactory {
    public private(set) var views: [FakeTerminalView] = []

    public init() {}

    public func makeTerminalView() -> any TerminalViewContract {
        let view = FakeTerminalView()
        views.append(view)
        return view
    }
}

@MainActor
public final class FakeTerminalListener: TerminalListener {
    public private(set) var signOutRequestCount = 0
    public private(set) var signOutEverywhereRequestCount = 0
    /// 만료를 알릴 때 함께 온 입력줄 글.
    public private(set) var expiredInputs: [String] = []
    /// 자료가 바뀌었다고 알린 횟수.
    public private(set) var itemsChangedCount = 0
    /// 연결이 바뀌었다고 알린 횟수.
    public private(set) var connectionsChangedCount = 0

    public init() {}

    public func didRequestSignOut() { signOutRequestCount += 1 }
    public func didRequestSignOutEverywhere() { signOutEverywhereRequestCount += 1 }

    public func didExpire(input: String) { expiredInputs.append(input) }
    public func didChangeItems() { itemsChangedCount += 1 }
    public func didChangeConnections() { connectionsChangedCount += 1 }
}
