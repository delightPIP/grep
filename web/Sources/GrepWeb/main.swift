import JavaScriptEventLoop
import JavaScriptKit

// 브라우저 쪽 진입점. 앱은 JS(`web/app.ts`)가 시작한다.
// JS가 넘기는 것: 피처별 웹 뷰, 로그인 모듈(`web/auth/auth-service.ts`의 `AuthService`), 서버 주소.

@JS func startGrepApp(
    loggedOutView: any LoggedOutViewBridge,
    loggedInView: any LoggedInViewBridge,
    authService: JSObject,
    apiBaseURL: String
) {
    nonisolated(unsafe) let (loggedOutView, loggedInView, authService) = (loggedOutView, loggedInView, authService)
    MainActor.assumeIsolated {
        GrepWebApp.start(
            viewFactory: WebViewFactory(
                loggedOut: ViewMounts.loggedOut(loggedOutView),
                loggedIn: ViewMounts.loggedIn(loggedInView)
            ),
            authService: authService,
            apiBaseURL: apiBaseURL
        )
    }
}

JavaScriptEventLoop.installGlobalExecutor()
