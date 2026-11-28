import AuthenticationServices
import CryptoKit
import Foundation
import GrepCore
import Security
#if canImport(UIKit)
import UIKit
#endif

/// 이 기기에 보관하는 로그인 세션.
public struct AuthSession: Codable, Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date

    public init(accessToken: String, refreshToken: String?, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }
}

/// 세션 저장소 계약. 기본 구현은 키체인이다.
@MainActor
public protocol AuthSessionStore: AnyObject {
    func load() -> AuthSession?
    func save(_ session: AuthSession)
    func clear()
}

/// 키체인에 세션을 저장한다.
@MainActor
public final class KeychainSessionStore: AuthSessionStore {
    private let service: String
    private let account: String

    public init(service: String = "com.unwrap.grep.auth", account: String = "session") {
        self.service = service
        self.account = account
    }

    public func load() -> AuthSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    public func save(_ session: AuthSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery.merge(attributes) { _, new in new }
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    public func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// 외부 OAuth 브라우저 세션을 여는 계약.
@MainActor
public protocol AuthWebSessionRunner: AnyObject {
    func authenticate(url: URL, callbackScheme: String) async throws -> URL
}

/// `ASWebAuthenticationSession` 기반 OAuth 브라우저 실행기.
@MainActor
public final class ASWebAuthSessionRunner: NSObject, AuthWebSessionRunner, ASWebAuthenticationPresentationContextProviding {
    private var activeSession: ASWebAuthenticationSession?

    public override init() {
        super.init()
    }

    public func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { [weak self] callbackURL, error in
                Task { @MainActor in
                    self?.activeSession = nil
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let callbackURL {
                        continuation.resume(returning: callbackURL)
                    } else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                    }
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.activeSession = session
            if !session.start() {
                self.activeSession = nil
                continuation.resume(throwing: URLError(.cannotOpenFile))
            }
        }
    }

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let keyWindow = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return keyWindow
        }
        if let firstScene = scenes.first {
            return ASPresentationAnchor(windowScene: firstScene)
        }
        #endif
        return ASPresentationAnchor()
    }
}

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

    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: Double?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
        }
    }

    private static let refreshLeeway: TimeInterval = 30

    private let configuration: Configuration
    private let webSession: any AuthWebSessionRunner
    private let sessionStore: any AuthSessionStore
    private let urlSession: URLSession
    private let now: @MainActor () -> Date
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
        let verifier = Self.generateCodeVerifier()
        let challenge = Self.codeChallenge(for: verifier)
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

    private func exchangeCodeForSession(code: String, verifier: String) async -> SignInResult {
        guard var components = URLComponents(
            url: configuration.supabaseURL.appending(path: "auth/v1/token"),
            resolvingAgainstBaseURL: false
        ) else {
            return .failed(.denied)
        }
        components.queryItems = [URLQueryItem(name: "grant_type", value: "pkce")]
        guard let url = components.url else { return .failed(.denied) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = URLSessionHTTPTransport.defaultTimeout
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["auth_code": code, "code_verifier": verifier]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return .failed(.denied)
            }
            let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
            let expiresIn = decoded.expiresIn ?? 3600
            let session = AuthSession(
                accessToken: decoded.accessToken,
                refreshToken: decoded.refreshToken,
                expiresAt: now().addingTimeInterval(expiresIn)
            )
            sessionStore.save(session)
            return .success
        } catch let urlError as URLError {
            return .failed(Self.failureReason(for: urlError))
        } catch {
            return .failed(.denied)
        }
    }

    private func refreshAccessToken(refreshToken: String, fallbackToken: String) async -> String? {
        guard var components = URLComponents(
            url: configuration.supabaseURL.appending(path: "auth/v1/token"),
            resolvingAgainstBaseURL: false
        ) else {
            return nil
        }
        components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = URLSessionHTTPTransport.defaultTimeout
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse else { return fallbackToken }
            if (200..<300).contains(http.statusCode) {
                guard let decoded = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
                    sessionStore.clear()
                    return nil
                }
                let expiresIn = decoded.expiresIn ?? 3600
                let updated = AuthSession(
                    accessToken: decoded.accessToken,
                    refreshToken: decoded.refreshToken ?? refreshToken,
                    expiresAt: now().addingTimeInterval(expiresIn)
                )
                sessionStore.save(updated)
                return updated.accessToken
            }
            if (500..<600).contains(http.statusCode) {
                return fallbackToken
            }
            // 4xx: 갱신 토큰이 만료·거부됐다. 로그인 만료로 본다.
            sessionStore.clear()
            return nil
        } catch {
            // 네트워크 문제로 갱신하지 못하면 오프라인으로 처리하도록 마지막 토큰을 유지한다.
            return fallbackToken
        }
    }

    private static func failureReason(for error: URLError) -> SignInFailureReason {
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

    private static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URLEncoded(Data(bytes))
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URLEncoded(Data(digest))
    }

    private static func base64URLEncoded(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Supabase 설정이 없을 때 사용하는 미설정 인증 서비스.
@MainActor
public final class UnconfiguredAuthService: AuthService {
    public init() {}

    public func signIn(_ provider: AuthProvider) async -> SignInResult { .failed(.denied) }
    public func signOut() async {}
    public func accessToken() async -> String? { nil }
}
