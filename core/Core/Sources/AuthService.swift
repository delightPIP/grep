/// 로그인 방식. ACC-001 값: Google, GitHub 둘뿐이다.
public enum AuthProvider: String, Equatable, Sendable, CaseIterable {
    case google
    case github
}

/// 외부 로그인 실패 이유. ACC-001 사용자 문구 `✗ 로그인 실패: <이유>`의 세 가지.
public enum SignInFailureReason: Equatable, Sendable {
    /// `연결 끊김`
    case disconnected
    /// `응답 없음`
    case timedOut
    /// `권한 거부`
    case denied
}

public enum SignInResult: Equatable, Sendable {
    case success
    /// 사용자가 로그인 창을 닫았다(ACC-001 규칙 8).
    case cancelled
    case failed(SignInFailureReason)
}

/// 로그인. 플랫폼이 구현한다(웹: supabase-js, ADR-BCK-006 결정 2·7). 코어는 Supabase를 모른다.
@MainActor
public protocol AuthService: AnyObject {
    /// 외부 로그인 창을 연다. 끝날 때까지 기다린다.
    func signIn(_ provider: AuthProvider) async -> SignInResult
    /// 이 기기의 세션을 끝낸다.
    func signOut() async
    /// 유효한 접근 토큰. 만료됐으면 갱신 토큰으로 조용히 새로 받는다(ACC-001 규칙 6).
    /// 세션이 없거나 갱신에 실패하면 nil이다. 코어는 이를 로그인 만료로 본다.
    func accessToken() async -> String?
}
