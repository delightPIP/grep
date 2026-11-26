import FeatureLoggedInInterface
import GrepCoreTesting
import RIBs

@MainActor
public final class FakeLoggedInView: LoggedInViewContract {
    public weak var listener: (any LoggedInPresentableListener)?
    /// 그려진 상태를 순서대로 모은다.
    public private(set) var states: [LoggedInViewState] = []
    public var state: LoggedInViewState? { states.last }

    public init() {}

    public func render(_ state: LoggedInViewState) { states.append(state) }
}

@MainActor
public final class FakeLoggedInViewFactory: LoggedInViewFactory {
    public private(set) var views: [FakeLoggedInView] = []

    public init() {}

    public func makeLoggedInView() -> any LoggedInViewContract {
        let view = FakeLoggedInView()
        views.append(view)
        return view
    }
}

@MainActor
public final class FakeLoggedInListener: LoggedInListener {
    public private(set) var signOutCount = 0
    /// 만료를 알릴 때 함께 온 치던 줄.
    public private(set) var expiredInputs: [String] = []

    public init() {}

    public func didSignOut() { signOutCount += 1 }

    public func didExpire(pendingInput: String) { expiredInputs.append(pendingInput) }
}
