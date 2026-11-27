import FeatureLoggedOutInterface
import GrepWebSupport
import JavaScriptKit
import RIBs

/// 로그인 화면의 웹 화면을 만든다. 화면을 그리는 JS 뷰는 조립 쪽이 `mount`에서 붙인다.
@MainActor
public final class LoggedOutWebViewFactory: LoggedOutViewFactory {
    private let mount: @MainActor (LoggedOutWebScreen) -> Void

    public init(mount: @escaping @MainActor (LoggedOutWebScreen) -> Void) {
        self.mount = mount
    }

    public func makeLoggedOutView() -> any LoggedOutViewContract {
        let screen = LoggedOutWebScreen()
        mount(screen)
        return screen
    }
}

@MainActor
public final class LoggedOutWebScreen: WebScreen<LoggedOutViewState>, LoggedOutViewContract {
    public weak var listener: (any LoggedOutPresentableListener)?

    init() {
        super.init(tag: "section", id: "loggedOut", initialState: LoggedOutViewState())
    }

    public func render(_ state: LoggedOutViewState) { setViewState(state) }

    public func send(_ action: LoggedOutViewAction) { listener?.handle(action) }
}
