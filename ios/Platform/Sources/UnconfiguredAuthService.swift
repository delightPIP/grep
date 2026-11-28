import Foundation
import GrepCore

/// Supabase 설정이 없을 때 사용하는 미설정 인증 서비스.
@MainActor
public final class UnconfiguredAuthService: AuthService {
    public init() {}

    public func signIn(_ provider: AuthProvider) async -> SignInResult { .failed(.denied) }
    public func signOut() async {}
    public func accessToken() async -> String? { nil }
}
