import FeatureLoggedInInterface
import GrepWebSupport
import JavaScriptKit
import RIBs

/// 터미널 화면의 웹 화면을 만든다. 화면을 그리는 JS 뷰는 조립 쪽이 `mount`에서 붙인다.
@MainActor
public final class LoggedInWebViewFactory: LoggedInViewFactory {
    private let mount: @MainActor (LoggedInWebScreen) -> Void

    public init(mount: @escaping @MainActor (LoggedInWebScreen) -> Void) {
        self.mount = mount
    }

    public func makeLoggedInView() -> any LoggedInViewContract {
        let screen = LoggedInWebScreen()
        mount(screen)
        return screen
    }
}

@MainActor
public final class LoggedInWebScreen: WebScreen<LoggedInViewState>, LoggedInViewContract {
    public weak var listener: (any LoggedInPresentableListener)?

    init() {
        super.init(tag: "section", id: "loggedIn", initialState: LoggedInViewState())
    }

    public func render(_ state: LoggedInViewState) { setViewState(state) }

    public func send(_ action: LoggedInViewAction) { listener?.handle(action) }
}
