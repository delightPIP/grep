import FeatureLoggedInWeb
import FeatureLoggedOutWeb
import GrepCore
import GrepWebSupport

/// 피처의 웹 화면과 JS 뷰(브리지 프로토콜 구현)를 잇는다. 화면 상태를 브리지 인자로 풀고, 핸들 호출을 액션으로 묶는다.
/// 피처 화면 타깃은 `@JS` 타입을 모른다. 둘을 아는 곳은 여기 하나다.
@MainActor
enum ViewMounts {
    static func loggedOut(_ view: any LoggedOutViewBridge) -> LoggedOutWebViewFactory {
        LoggedOutWebViewFactory { screen in
            let handle = LoggedOutScreenHandle { [weak screen] providerName in
                guard let provider = AuthProvider(rawValue: providerName) else { return }
                screen?.send(.signInTapped(provider))
            }
            view.mount(host: screen.element, handle: handle)
            screen.attach { state in
                view.render(
                    noticeKind: state.notice?.bridgeKind,
                    failureReason: state.notice?.bridgeFailureReason,
                    isSigningIn: state.isSigningIn
                )
            }
        }
    }

    static func loggedIn(_ view: any LoggedInViewBridge) -> LoggedInWebViewFactory {
        LoggedInWebViewFactory { screen in
            let handle = LoggedInScreenHandle(
                onInputChanged: { [weak screen] text in screen?.send(.inputChanged(text)) },
                onSubmitted: { [weak screen] text in screen?.send(.submitted(text)) }
            )
            view.mount(host: screen.element, handle: handle)
            screen.attach { state in
                view.render(itemCount: state.itemCount, lines: state.lines.map(\.bridgeRow), input: state.input)
            }
        }
    }
}
