import Foundation
import GrepCore

// Supabase `/auth/v1/token` 교환: PKCE 코드 → 세션, 갱신 토큰 → 새 접근 토큰.
extension WebAuthService {
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

    func exchangeCodeForSession(code: String, verifier: String) async -> SignInResult {
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

    func refreshAccessToken(refreshToken: String, fallbackToken: String) async -> String? {
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
}
