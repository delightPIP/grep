import FeatureTerminalInterface
import GrepWebSupport
import JavaScriptKit
import RIBs

/// 터미널 화면의 웹 화면을 만든다. 화면을 그리는 JS 뷰는 조립 쪽이 `mount`에서 붙인다.
@MainActor
public final class TerminalWebViewFactory: TerminalViewFactory {
    private let mount: @MainActor (TerminalWebScreen) -> Void

    public init(mount: @escaping @MainActor (TerminalWebScreen) -> Void) {
        self.mount = mount
    }

    public func makeTerminalView() -> any TerminalViewContract {
        let screen = TerminalWebScreen()
        mount(screen)
        return screen
    }
}

@MainActor
public final class TerminalWebScreen: WebScreen<TerminalViewState>, TerminalViewContract {
    public weak var listener: (any TerminalPresentableListener)?

    init() {
        super.init(tag: "section", id: "loggedIn", initialState: TerminalViewState())
    }

    public func render(_ state: TerminalViewState) { setViewState(state) }

    public func send(_ action: TerminalViewAction) { listener?.handle(action) }
}
