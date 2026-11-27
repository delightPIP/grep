import Foundation
import GrepCore
import GrepPlatform
import Testing

/// 네트워크 대신 응답을 돌려주는 `URLProtocol`. 전역 핸들러를 쓰므로 스위트를 직렬 실행한다.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    enum Reply: Sendable {
        case response(status: Int, body: Data)
        case failure(URLError.Code)
        case hang
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var currentReply: Reply = .hang
    nonisolated(unsafe) private static var recordedRequests: [URLRequest] = []
    nonisolated(unsafe) private static var recordedBodies: [Data] = []

    static var reply: Reply {
        get { lock.withLock { currentReply } }
        set { lock.withLock { currentReply = newValue } }
    }

    static var requests: [URLRequest] { lock.withLock { recordedRequests } }
    static var bodies: [Data] { lock.withLock { recordedBodies } }

    static func reset(reply: Reply = .hang) {
        lock.withLock {
            currentReply = reply
            recordedRequests = []
            recordedBodies = []
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    private static func readBody(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }

    override func startLoading() {
        let body = Self.readBody(of: request)
        let activeReply = Self.lock.withLock { () -> Reply in
            Self.recordedRequests.append(request)
            Self.recordedBodies.append(body)
            return Self.currentReply
        }
        switch activeReply {
        case .response(let status, let data):
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case .hang:
            break
        }
    }

    override func stopLoading() {}

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }
}

@MainActor
@Suite(.serialized)
struct URLSessionHTTPTransportTests {
    private let transport: URLSessionHTTPTransport

    init() {
        StubURLProtocol.reset()
        transport = URLSessionHTTPTransport(
            baseURL: URL(string: "https://example.test/api")!,
            session: StubURLProtocol.makeSession()
        )
    }

    @Test func 쿼리가포함된경로일때_요청을보내면_쿼리를유지하고응답을돌려주는지() async throws {
        // given
        StubURLProtocol.reply = .response(status: 200, body: Data(#"{"items":[]}"#.utf8))
        let request = HTTPRequest(method: .get, path: "/items?limit=20&cursor=abc")

        // when
        let response = try await transport.send(request)

        // then
        #expect(response == HTTPResponse(status: 200, body: Array(#"{"items":[]}"#.utf8)))
        #expect(StubURLProtocol.requests.first?.url?.absoluteString == "https://example.test/api/items?limit=20&cursor=abc")
        #expect(StubURLProtocol.requests.first?.httpMethod == "GET")
    }

    @Test func 헤더와본문이있을때_POST요청을보내면_그대로전달하는지() async throws {
        // given
        StubURLProtocol.reply = .response(status: 201, body: Data("{}".utf8))
        let request = HTTPRequest(
            method: .post,
            path: "/items",
            headers: ["Authorization": "Bearer tok", "Content-Type": "application/json"],
            body: #"{"url":"https://a.test"}"#
        )

        // when
        let response = try await transport.send(request)

        // then
        #expect(response.status == 201)
        let sent = try #require(StubURLProtocol.requests.first)
        #expect(sent.httpMethod == "POST")
        #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
        #expect(StubURLProtocol.bodies.first == Data(#"{"url":"https://a.test"}"#.utf8))
    }

    @Test func 서버가오류상태코드를돌려줄때_요청을보내면_던지지않고응답으로반환하는지() async throws {
        // given
        StubURLProtocol.reply = .response(status: 503, body: Data())

        // when
        let response = try await transport.send(HTTPRequest(method: .get, path: "/me"))

        // then
        #expect(response == HTTPResponse(status: 503, body: []))
    }

    @Test func 응답시간이초과될때_요청을보내면_timedOut오류를던지는지() async {
        // given
        StubURLProtocol.reply = .failure(.timedOut)

        // when
        let result: Result<HTTPResponse, HTTPTransportError>
        do throws(HTTPTransportError) {
            result = .success(try await transport.send(HTTPRequest(method: .get, path: "/me")))
        } catch {
            result = .failure(error)
        }

        // then
        #expect(result == .failure(.timedOut))
    }

    @Test func 연결이끊겼을때_요청을보내면_unreachable오류를던지는지() async {
        // given
        StubURLProtocol.reply = .failure(.notConnectedToInternet)

        // when
        let result: Result<HTTPResponse, HTTPTransportError>
        do throws(HTTPTransportError) {
            result = .success(try await transport.send(HTTPRequest(method: .get, path: "/me")))
        } catch {
            result = .failure(error)
        }

        // then
        #expect(result == .failure(.unreachable))
    }

    @Test func 요청이진행중일때_태스크를취소하면_cancelled오류를던지는지() async {
        // given
        StubURLProtocol.reply = .hang
        let task = Task { @MainActor () -> Result<HTTPResponse, HTTPTransportError> in
            do throws(HTTPTransportError) {
                return .success(try await transport.send(HTTPRequest(method: .get, path: "/me")))
            } catch {
                return .failure(error)
            }
        }
        while StubURLProtocol.requests.isEmpty { await Task.yield() }

        // when
        task.cancel()
        let result = await task.value

        // then
        #expect(result == .failure(.cancelled))
    }
}
