import Foundation
import GrepCore

/// `URLSession`으로 보내는 전송 계층. 요청을 보내고 상태 코드와 본문을 그대로 돌려준다.
/// 응답 해석은 공유 코어가 한다.
@MainActor
public final class URLSessionHTTPTransport: HTTPTransport {
    /// COM-010 `응답 없음` 기준(10초).
    public static let defaultTimeout: TimeInterval = 10

    private let baseURL: URL
    private let session: URLSession
    private let timeout: TimeInterval

    /// `baseURL`은 요청 경로 앞에 붙는다(`https://example.com/api` + `/items?limit=20`).
    public init(
        baseURL: URL,
        session: URLSession = .shared,
        timeout: TimeInterval = URLSessionHTTPTransport.defaultTimeout
    ) {
        self.baseURL = baseURL
        self.session = session
        self.timeout = timeout
    }

    public func send(_ request: HTTPRequest) async throws(HTTPTransportError) -> HTTPResponse {
        guard let url = resolveURL(path: request.path) else { throw .unreachable }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = timeout
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        urlRequest.httpBody = request.body.map { Data($0.utf8) }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                throw .cancelled
            }
            if (error as? URLError)?.code == .timedOut {
                throw .timedOut
            }
            throw .unreachable
        }
        guard let http = response as? HTTPURLResponse else { throw .unreachable }
        return HTTPResponse(status: http.statusCode, body: Array(data))
    }

    private func resolveURL(path: String) -> URL? {
        let base = baseURL.absoluteString.hasSuffix("/")
            ? String(baseURL.absoluteString.dropLast())
            : baseURL.absoluteString
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        return URL(string: base + normalizedPath)
    }
}
