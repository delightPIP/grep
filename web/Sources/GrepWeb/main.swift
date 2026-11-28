import GrepAppRoot
import JavaScriptEventLoop
import JavaScriptKit

// 브라우저 쪽 진입점. 앱은 JS(`web/app.ts`)가 시작한다.
// JS가 넘기는 것: 피처별 웹 뷰, 로그인 모듈(`web/auth/auth-service.ts`의 `AuthService`),
// 브라우저 포트 셋(`web/ports/*.ts`의 `ClipboardPort`·`FilePort`·`HistoryStore`), 서버 주소.

/// JS가 넘긴 플랫폼 객체들. 한 번에 메인 액터로 옮기려고 묶는다.
private struct JSPlatform {
    let authService: JSObject
    let clipboard: JSObject
    let files: JSObject
    let historyStore: JSObject
}

@JS func startGrepApp(
    loggedOutView: any LoggedOutViewBridge,
    loggedInView: any LoggedInViewBridge,
    authService: JSObject,
    clipboard: JSObject,
    files: JSObject,
    historyStore: JSObject,
    apiBaseURL: String
) {
    nonisolated(unsafe) let (loggedOutView, loggedInView) = (loggedOutView, loggedInView)
    nonisolated(unsafe) let platform = JSPlatform(
        authService: authService, clipboard: clipboard, files: files, historyStore: historyStore
    )
    MainActor.assumeIsolated {
        let composer = LoggedInComposer()
        GrepWebApp.start(
            viewFactory: WebViewFactory(
                loggedOut: ViewMounts.loggedOut(loggedOutView),
                loggedIn: ViewMounts.loggedIn(loggedInView, composer: composer),
                composer: composer
            ),
            platform: PlatformServices(
                authService: JSAuthService(service: platform.authService),
                httpTransport: FetchHTTPTransport(baseURL: apiBaseURL),
                clipboard: JSClipboardPort(port: platform.clipboard),
                files: JSFilePort(port: platform.files),
                historyStore: JSHistoryStore(store: platform.historyStore),
                deviceTime: BrowserTime.deviceTime()
            )
        )
    }
}

JavaScriptEventLoop.installGlobalExecutor()
