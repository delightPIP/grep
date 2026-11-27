import FeatureTerminalInterface
import GrepAndroidSupport
import RIBs

/// 터미널 피처의 Android 화면을 만든다.
@MainActor
public final class TerminalAndroidViewFactory: TerminalViewFactory {
    nonisolated public static let kind = "terminal"
    private let context: ScreenContext

    public init(context: ScreenContext) {
        self.context = context
    }

    public func makeTerminalView() -> any TerminalViewContract {
        TerminalAndroidScreen(context: context)
    }
}

@MainActor
public final class TerminalAndroidScreen: BridgedScreen<TerminalViewState>, TerminalViewContract {
    public weak var listener: (any TerminalPresentableListener)?

    init(context: ScreenContext) {
        super.init(kind: TerminalAndroidViewFactory.kind, context: context, initialState: TerminalViewState())
    }

    public func render(_ state: TerminalViewState) { setViewState(state) }

    public func send(_ action: TerminalViewAction) { listener?.handle(action) }
}
