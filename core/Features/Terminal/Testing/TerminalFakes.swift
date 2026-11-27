import FeatureTerminalInterface
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
    /// 만료를 알릴 때 함께 온 입력줄 글.
    public private(set) var expiredInputs: [String] = []

    public init() {}

    public func didRequestSignOut() { signOutRequestCount += 1 }

    public func didExpire(input: String) { expiredInputs.append(input) }
}
