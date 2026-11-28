import FeatureLoggedOut
import FeatureLoggedOutAndroid
import FeatureLoggedOutInterface
import FeatureTerminalAndroid
import FeatureTerminalInterface
import GrepAndroidSupport
import GrepCore
import GrepCoreTesting
import RIBs
import RIBsAndroid

@MainActor
final class DemoAuthService: AuthService {
    private let result: SignInResult
    private var token: String?

    init(result: SignInResult) {
        self.result = result
    }

    func signIn(_ provider: AuthProvider) async -> SignInResult {
        if result == .success {
            token = fakeAccessToken(subject: "demo-\(provider.rawValue)")
        }
        return result
    }

    func signOut() async {
        token = nil
    }

    func accessToken() async -> String? { token }
}
