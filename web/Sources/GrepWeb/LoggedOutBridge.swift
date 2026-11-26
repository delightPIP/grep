import JavaScriptKit

// BridgeJS가 JS로 내보내는 층. 격리 없는 타입만 `@JS`로 두고 `@MainActor` 뷰 계약은 감춘다.
// Wasm은 단일 스레드라 모든 호출이 메인에서 온다. `MainActor.assumeIsolated`로 확인한다.

/// 웹 뷰가 구현한다. `features/logged-out/adapter.tsx`가 구현한다.
/// 화면 종류마다 뷰 객체는 하나이고, 그 객체가 같은 종류의 화면 여러 개를 차례로 맡는다(로그아웃할 때마다 새 화면이 생긴다).
@JS protocol LoggedOutViewBridge {
    /// 새 로그인 화면이 생길 때 불린다. `host` 안에 화면을 그리고 `handle`로 입력을 보낸다.
    func mount(host: JSObject, handle: LoggedOutScreenHandle)
    /// 가장 최근에 `mount`한 화면의 상태를 그린다. 값은 `web/support/view-state.ts`의 `LoggedOutState`와 같은 이름을 쓴다.
    /// `failureReason`은 `noticeKind`가 `failed`일 때만 있다.
    func render(noticeKind: String?, failureReason: String?, isSigningIn: Bool)
}

/// 웹 뷰가 `mount`에서 받아 쥐고 입력을 보낸다. 화면이 이미 내려갔으면 호출은 아무 일도 하지 않는다.
@JS final class LoggedOutScreenHandle: Sendable {
    private let onSignInTapped: @MainActor @Sendable (String) -> Void

    init(onSignInTapped: @escaping @MainActor @Sendable (String) -> Void) {
        self.onSignInTapped = onSignInTapped
    }

    /// `provider`는 `google` 또는 `github`. 다른 값이면 무시한다.
    @JS func signInTapped(provider: String) {
        MainActor.assumeIsolated { onSignInTapped(provider) }
    }
}
