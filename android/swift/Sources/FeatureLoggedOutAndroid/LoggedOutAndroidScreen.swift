import FeatureLoggedOutInterface
import GrepAndroidSupport
import RIBs

/// 로그인 전 피처의 Android 화면을 만든다. Kotlin `:feature:loggedout:adapter`가 짝이다.
@MainActor
public final class LoggedOutAndroidViewFactory: LoggedOutViewFactory {
    nonisolated public static let kind = "loggedOut"
    private let context: ScreenContext

    public init(context: ScreenContext) {
        self.context = context
    }

    public func makeLoggedOutView() -> any LoggedOutViewContract {
        LoggedOutAndroidScreen(context: context)
    }
}

@MainActor
public final class LoggedOutAndroidScreen: BridgedScreen<LoggedOutViewState>, LoggedOutViewContract {
    public weak var listener: (any LoggedOutPresentableListener)?

    init(context: ScreenContext) {
        super.init(kind: LoggedOutAndroidViewFactory.kind, context: context, initialState: LoggedOutViewState())
    }

    public func render(_ state: LoggedOutViewState) { setViewState(state) }

    public func send(_ action: LoggedOutViewAction) { listener?.handle(action) }
}
