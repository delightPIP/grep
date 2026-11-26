import FeatureLoggedOutInterface
import GrepCoreTesting
import RIBs

@MainActor
public final class FakeLoggedOutView: LoggedOutViewContract {
    public weak var listener: (any LoggedOutPresentableListener)?
    /// 그려진 상태를 순서대로 모은다.
    public private(set) var states: [LoggedOutViewState] = []
    public var state: LoggedOutViewState? { states.last }

    public init() {}

    public func render(_ state: LoggedOutViewState) { states.append(state) }
}

@MainActor
public final class FakeLoggedOutViewFactory: LoggedOutViewFactory {
    public private(set) var views: [FakeLoggedOutView] = []

    public init() {}

    public func makeLoggedOutView() -> any LoggedOutViewContract {
        let view = FakeLoggedOutView()
        views.append(view)
        return view
    }
}

@MainActor
public final class FakeLoggedOutListener: LoggedOutListener {
    public private(set) var signInCount = 0

    public init() {}

    public func didSignIn() { signInCount += 1 }
}
