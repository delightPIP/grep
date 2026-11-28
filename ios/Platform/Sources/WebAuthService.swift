import AuthenticationServices
import Foundation
import GrepCore

/// `ASWebAuthenticationSession` + PKCE로 구현한 iOS `AuthService`(ACC-001).
/// Supabase Auth REST API(`/auth/v1/authorize`, `/auth/v1/token`)만 부른다(ADR-BCK-006).
@MainActor
public final class WebAuthService: AuthService {
    public struct Configuration: Equatable, Sendable {
        public let supabaseURL: URL
        public let publishableKey: String
        public let callbackScheme: String

        public init(supabaseURL: URL, publishableKey: String, callbackScheme: String = "grep") {
            self.supabaseURL = supabaseURL
            self.publishableKey = publishableKey
            self.callbackScheme = callbackScheme
        }
    }

    private static let refreshLeeway: TimeInterval = 30

    let configuration: Configuration
    private let webSession: any AuthWebSessionRunner
    let sessionStore: any AuthSessionStore
    let urlSession: URLSession
    let now: @MainActor () -> Date
    private var inFlightSignIn: Task<SignInResult, Never>?

    public init(
        configuration: Configuration,
        webSession: any AuthWebSessionRunner = ASWebAuthSessionRunner(),
        sessionStore: any AuthSessionStore = KeychainSessionStore(),
        urlSession: URLSession = .shared,
        now: @escaping @MainActor () -> Date = Date.init
    ) {
        self.configuration = configuration
        self.webSession = webSession
        self.sessionStore = sessionStore
        self.urlSession = urlSession
        self.now = now
    }

    public func signIn(_ provider: AuthProvider) async -> SignInResult {
        // ACC-001 규칙 9: 로그인 창이 열려 있으면 하나 더 띄우지 않고 진행 중인 결과를 기다린다.
        if let existing = inFlightSignIn {
            return await existing.value
        }

        let task = Task { @MainActor [weak self] () -> SignInResult in
            guard let self else { return .cancelled }
            defer { self.inFlightSignIn = nil }
            return await self.performSignIn(provider)
        }
        inFlightSignIn = task
        return await task.value
    }

    public func signOut() async {
        sessionStore.clear()
    }

    /// ACC-002 규칙 4·5: 서버의 모든 갱신 토큰을 끊고 이 기기는 바로 로그아웃한다(웹 `signOut({ scope: "global" })`과 같음).
    /// 서버에 닿지 못해도 이 기기 세션은 지운다. 다른 기기는 접근 토큰이 만료될 때(최대 1시간) 로그아웃된다.
    public func signOutEverywhere() async {
        defer { sessionStore.clear() }
        guard let session = sessionStore.load(),
              var components = URLComponents(
                  url: configuration.supabaseURL.appending(path: "auth/v1/logout"),
                  resolvingAgainstBaseURL: false
              ) else {
            return
        }
        components.queryItems = [URLQueryItem(name: "scope", value: "global")]
        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = URLSessionHTTPTransport.defaultTimeout
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        _ = try? await urlSession.data(for: request)
    }

    public func accessToken() async -> String? {
        guard let session = sessionStore.load() else { return nil }
        if session.expiresAt > now().addingTimeInterval(Self.refreshLeeway) {
            return session.accessToken
        }
        guard let refreshToken = session.refreshToken, !refreshToken.isEmpty else {
            sessionStore.clear()
            return nil
        }
        return await refreshAccessToken(refreshToken: refreshToken, fallbackToken: session.accessToken)
    }

    private func performSignIn(_ provider: AuthProvider) async -> SignInResult {
        let verifier = AuthPKCE.generateCodeVerifier()
        let challenge = AuthPKCE.codeChallenge(for: verifier)
        guard let authorizeURL = buildAuthorizeURL(provider: provider, challenge: challenge) else {
            return .failed(.denied)
        }

        let callbackURL: URL
        do {
            callbackURL = try await webSession.authenticate(
                url: authorizeURL,
                callbackScheme: configuration.callbackScheme
            )
        } catch let authError as ASWebAuthenticationSessionError where authError.code == .canceledLogin {
            return .cancelled
        } catch let urlError as URLError {
            return .failed(Self.failureReason(for: urlError))
        } catch {
            return .failed(.denied)
        }

        let params = Self.parseCallbackParams(from: callbackURL)
        if params["error"] == "access_denied" {
            // ACC-001 비고: 동의 화면에서 취소·거부를 누르면 로그인 취소로 본다.
            return .cancelled
        }
        if params["error"] != nil {
            return .failed(.denied)
        }
        guard let code = params["code"], !code.isEmpty else {
            return .failed(.denied)
        }

        return await exchangeCodeForSession(code: code, verifier: verifier)
    }

    private func buildAuthorizeURL(provider: AuthProvider, challenge: String) -> URL? {
        guard var components = URLComponents(
            url: configuration.supabaseURL.appending(path: "auth/v1/authorize"),
            resolvingAgainstBaseURL: false
        ) else {
            return nil
        }
        var items = [
            URLQueryItem(name: "provider", value: provider.rawValue),
            URLQueryItem(name: "redirect_to", value: "\(configuration.callbackScheme)://auth-callback"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        if provider == .google {
            items.append(URLQueryItem(name: "prompt", value: "select_account"))
        }
        components.queryItems = items
        return components.url
    }


    static func failureReason(for error: URLError) -> SignInFailureReason {
        switch error.code {
        case .timedOut:
            return .timedOut
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return .disconnected
        default:
            return .denied
        }
    }

    private static func parseCallbackParams(from url: URL) -> [String: String] {
        var result: [String: String] = [:]
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            for item in components.queryItems ?? [] {
                result[item.name] = item.value ?? ""
            }
            if let fragment = components.fragment, !fragment.isEmpty {
                var fragmentComponents = URLComponents()
                fragmentComponents.query = fragment
                for item in fragmentComponents.queryItems ?? [] {
                    result[item.name] = item.value ?? ""
                }
            }
        }
        return result
    }
}
