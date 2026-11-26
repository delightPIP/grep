import GrepCore
import JavaScriptKit

/// JS가 구현한 로그인 모듈(`web/auth/auth-service.ts`의 `AuthService`)을 코어의 `AuthService`로 잇는다.
/// 코어는 Supabase를 모른다. 로그인 코드는 JS 모듈 하나에 있다(ADR-BCK-006 결정 2·7).
@MainActor
final class JSAuthService: AuthService {
    private let service: JSObject

    init(service: JSObject) {
        self.service = service
    }

    /// 계약과 다른 값이 오거나 프로미스가 거절되면 `연결 끊김` 실패로 본다.
    func signIn(_ provider: AuthProvider) async -> SignInResult {
        await JSPromiseValue.await(service.signIn!(provider.rawValue), rejected: .failed(.disconnected)) { value in
            guard let result = value.object else { return .failed(.disconnected) }
            switch result.kind.string {
            case "success": return .success
            case "cancelled": return .cancelled
            default:
                let reason = result.reason.string.flatMap(SignInFailureReason.init(bridgeName:))
                return .failed(reason ?? .disconnected)
            }
        }
    }

    func signOut() async {
        await JSPromiseValue.await(service.signOut!(), rejected: ()) { _ in }
    }

    func accessToken() async -> String? {
        await JSPromiseValue.await(service.accessToken!(), rejected: nil) { $0.string }
    }
}
