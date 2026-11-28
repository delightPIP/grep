import AuthenticationServices
import Foundation
import GrepCore
import GrepPlatform
import Testing

@MainActor
private final class InMemorySessionStore: AuthSessionStore {
    var session: AuthSession?

    init(session: AuthSession? = nil) {
        self.session = session
    }

    func load() -> AuthSession? { session }
    func save(_ session: AuthSession) { self.session = session }
    func clear() { session = nil }
}

@MainActor
private final class StubWebSessionRunner: AuthWebSessionRunner {
    var requestedURLs: [URL] = []
    var result: Result<URL, Error> = .failure(ASWebAuthenticationSessionError(.canceledLogin))

    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        requestedURLs.append(url)
        return try result.get()
    }
}

@MainActor
@Suite(.serialized)
struct PlatformPortsTests {
    // MARK: - PasteboardClipboardPort

    @Test func 클립보드쓰기가성공할때_복사하면_copied를돌려주고글을전달하는지() async {
        // given
        var written: [String] = []
        let port = PasteboardClipboardPort { text in
            written.append(text)
            return .copied
        }

        // when
        let result = await port.copy("넘길 글")

        // then
        #expect(result == .copied)
        #expect(written == ["넘길 글"])
    }

    @Test func 클립보드가거부될때_복사하면_denied를돌려주는지() async {
        // given
        let port = PasteboardClipboardPort { _ in .denied }

        // when
        let result = await port.copy("넘길 글")

        // then
        #expect(result == .denied)
    }

    // MARK: - UserDefaultsHistoryStore

    @Test func 기록을저장했을때_다시읽으면_같은계정과본문을돌려주는지() {
        // given
        let suiteName = "com.unwrap.grep.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsHistoryStore(defaults: defaults, key: "history")
        let record = HistoryRecord(subject: "user-1", payload: #"{"lines":[]}"#)

        // when
        store.save(record)
        let loaded = store.load()

        // then
        #expect(loaded == record)
    }

    @Test func 기록이있을때_지우기를호출하면_nil을돌려주는지() {
        // given
        let suiteName = "com.unwrap.grep.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsHistoryStore(defaults: defaults, key: "history")
        store.save(HistoryRecord(subject: "user-1", payload: "{}"))

        // when
        store.clear()

        // then
        #expect(store.load() == nil)
    }

    // MARK: - URLSessionFilePort

    @Test func 파일이등록되어있을때_서명주소로올리면_PUT으로바이트를전송하는지() async throws {
        // given
        StubURLProtocol.reset(reply: .response(status: 200, body: Data()))
        let port = URLSessionFilePort(session: StubURLProtocol.makeSession())
        let payload = Data("hello-pdf".utf8)
        let fileID = port.stage(payload, id: "file-1")

        // when
        try await port.upload(fileID, to: "https://storage.test/signed/1")

        // then
        #expect(StubURLProtocol.requests.first?.httpMethod == "PUT")
        #expect(StubURLProtocol.requests.first?.url?.absoluteString == "https://storage.test/signed/1")
        #expect(StubURLProtocol.bodies.first == payload)
    }

    @Test func 파일을놓았을때_업로드를시도하면_missingFile오류를던지는지() async {
        // given
        StubURLProtocol.reset()
        let port = URLSessionFilePort(session: StubURLProtocol.makeSession())
        let fileID = port.stage(Data([1, 2, 3]), id: "file-2")
        port.release(fileID)

        // when
        let error: FileUploadError?
        do throws(FileUploadError) {
            try await port.upload(fileID, to: "https://storage.test/signed/2")
            error = nil
        } catch let uploadError {
            error = uploadError
        }

        // then
        #expect(error == .missingFile)
    }

    @Test func 저장소가2xx가아닌응답을줄때_업로드하면_rejected오류를던지는지() async {
        // given
        StubURLProtocol.reset(reply: .response(status: 403, body: Data()))
        let port = URLSessionFilePort(session: StubURLProtocol.makeSession())
        let fileID = port.stage(Data([1, 2, 3]), id: "file-3")

        // when
        let error: FileUploadError?
        do throws(FileUploadError) {
            try await port.upload(fileID, to: "https://storage.test/signed/3")
            error = nil
        } catch let uploadError {
            error = uploadError
        }

        // then
        #expect(error == .rejected)
    }

    // MARK: - WebAuthService

    @Test func 사용자가로그인창을닫았을때_signIn을호출하면_cancelled를돌려주는지() async {
        // given
        StubURLProtocol.reset()
        let webSession = StubWebSessionRunner()
        webSession.result = .failure(ASWebAuthenticationSessionError(.canceledLogin))
        let service = WebAuthService(
            configuration: .init(supabaseURL: URL(string: "https://auth.test")!, publishableKey: "pub-key"),
            webSession: webSession,
            sessionStore: InMemorySessionStore(),
            urlSession: StubURLProtocol.makeSession()
        )

        // when
        let result = await service.signIn(.google)

        // then
        #expect(result == .cancelled)
        let authorizeURL = webSession.requestedURLs.first?.absoluteString ?? ""
        #expect(authorizeURL.contains("provider=google"))
        #expect(authorizeURL.contains("prompt=select_account"))
        #expect(authorizeURL.contains("code_challenge_method=S256"))
    }

    @Test func 동의화면에서거부했을때_콜백이돌아오면_cancelled를돌려주는지() async {
        // given
        StubURLProtocol.reset()
        let webSession = StubWebSessionRunner()
        webSession.result = .success(URL(string: "grep://auth-callback?error=access_denied")!)
        let service = WebAuthService(
            configuration: .init(supabaseURL: URL(string: "https://auth.test")!, publishableKey: "pub-key"),
            webSession: webSession,
            sessionStore: InMemorySessionStore(),
            urlSession: StubURLProtocol.makeSession()
        )

        // when
        let result = await service.signIn(.github)

        // then
        #expect(result == .cancelled)
    }

    @Test func 인가코드가돌아왔을때_토큰교환에성공하면_세션을저장하고success를돌려주는지() async {
        // given
        StubURLProtocol.reset(
            reply: .response(
                status: 200,
                body: Data(#"{"access_token":"acc-123","refresh_token":"ref-456","expires_in":3600}"#.utf8)
            )
        )
        let webSession = StubWebSessionRunner()
        webSession.result = .success(URL(string: "grep://auth-callback?code=pkce-code")!)
        let store = InMemorySessionStore()
        let service = WebAuthService(
            configuration: .init(supabaseURL: URL(string: "https://auth.test")!, publishableKey: "pub-key"),
            webSession: webSession,
            sessionStore: store,
            urlSession: StubURLProtocol.makeSession()
        )

        // when
        let result = await service.signIn(.google)
        let token = await service.accessToken()

        // then
        #expect(result == .success)
        #expect(token == "acc-123")
        #expect(store.session?.refreshToken == "ref-456")
    }

    @Test func 접근토큰이만료됐을때_갱신토큰이거부되면_세션을지우고nil을돌려주는지() async {
        // given
        StubURLProtocol.reset(reply: .response(status: 400, body: Data()))
        let now = Date(timeIntervalSince1970: 2000)
        let store = InMemorySessionStore(
            session: AuthSession(
                accessToken: "old-token",
                refreshToken: "expired-refresh",
                expiresAt: Date(timeIntervalSince1970: 1000)
            )
        )
        let service = WebAuthService(
            configuration: .init(supabaseURL: URL(string: "https://auth.test")!, publishableKey: "pub-key"),
            webSession: StubWebSessionRunner(),
            sessionStore: store,
            urlSession: StubURLProtocol.makeSession(),
            now: { now }
        )

        // when
        let token = await service.accessToken()

        // then
        #expect(token == nil)
        #expect(store.session == nil)
    }

    @Test func 모든기기로그아웃을확인했을때_signOutEverywhere를호출하면_global로그아웃을보내고세션을지우는지() async throws {
        // given
        StubURLProtocol.reset(reply: .response(status: 204, body: Data()))
        let store = InMemorySessionStore(
            session: AuthSession(accessToken: "acc-123", refreshToken: "ref-456", expiresAt: .distantFuture)
        )
        let service = WebAuthService(
            configuration: .init(supabaseURL: URL(string: "https://auth.test")!, publishableKey: "pub-key"),
            webSession: StubWebSessionRunner(),
            sessionStore: store,
            urlSession: StubURLProtocol.makeSession()
        )

        // when
        await service.signOutEverywhere()

        // then
        let sent = try #require(StubURLProtocol.requests.first)
        #expect(sent.url?.absoluteString == "https://auth.test/auth/v1/logout?scope=global")
        #expect(sent.httpMethod == "POST")
        #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer acc-123")
        #expect(sent.value(forHTTPHeaderField: "apikey") == "pub-key")
        #expect(store.session == nil)
    }

    @Test func 서버에닿지못할때_signOutEverywhere를호출하면_이기기세션은지우는지() async {
        // given
        StubURLProtocol.reset(reply: .failure(.notConnectedToInternet))
        let store = InMemorySessionStore(
            session: AuthSession(accessToken: "acc-123", refreshToken: "ref-456", expiresAt: .distantFuture)
        )
        let service = WebAuthService(
            configuration: .init(supabaseURL: URL(string: "https://auth.test")!, publishableKey: "pub-key"),
            webSession: StubWebSessionRunner(),
            sessionStore: store,
            urlSession: StubURLProtocol.makeSession()
        )

        // when
        await service.signOutEverywhere()

        // then
        #expect(store.session == nil)
    }
}
