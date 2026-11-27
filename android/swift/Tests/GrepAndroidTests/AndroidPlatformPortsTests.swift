import GrepAndroid
import GrepCore
import Testing

@MainActor
struct AndroidPlatformPortsTests {
    @Test
    func HTTP요청중일때_타임아웃으로실패하면_timedOut에러를던지는지() async {
        // given
        let sender = SpyHTTPSender()
        let transport = AndroidHTTPTransport(sender: sender)

        // when
        let task = Task { @MainActor () -> HTTPTransportError? in
            do {
                _ = try await transport.send(HTTPRequest(method: .get, path: "/me"))
                return nil
            } catch let error as HTTPTransportError {
                return error
            } catch {
                return nil
            }
        }
        await Task.yield()
        let requestID = sender.started.first?.requestID ?? -1
        transport.fail(requestID: requestID, isTimeout: true)
        let error = await task.value

        // then
        #expect(error == .timedOut)
    }

    @Test
    func 인증서비스에로그인요청했을때_취소로응답하면_cancelled를돌려주는지() async {
        // given
        let executor = SpyAuthExecutor()
        let auth = AndroidAuthService(executor: executor)

        // when
        let task = Task { @MainActor in await auth.signIn(.google) }
        await Task.yield()
        let requestID = executor.signInRequests.first?.requestID ?? -1
        auth.completeSignIn(requestID: requestID, outcome: "cancelled", reason: "")
        let result = await task.value

        // then
        #expect(executor.signInRequests.first?.provider == "google")
        #expect(result == .cancelled)
    }

    @Test
    func 기록을저장했을때_다시읽으면_같은계정과본문을돌려주는지() {
        // given
        let executor = InMemoryHistoryExecutor()
        let store = AndroidHistoryStore(executor: executor)
        let record = HistoryRecord(subject: "user-42", payload: "{\"lines\":[]}")

        // when
        store.save(record)
        let loaded = store.load()

        // then
        #expect(loaded == record)
    }
}

@MainActor
private final class SpyHTTPSender: AndroidHTTPSender {
    struct Started { let requestID: Int64; let method: String; let path: String }
    var started: [Started] = []
    var cancelled: [Int64] = []

    func start(requestID: Int64, method: String, path: String, headers: String, body: String) {
        started.append(Started(requestID: requestID, method: method, path: path))
    }

    func cancel(requestID: Int64) {
        cancelled.append(requestID)
    }
}

@MainActor
private final class SpyAuthExecutor: AndroidAuthExecutor {
    struct SignIn { let requestID: Int64; let provider: String }
    var signInRequests: [SignIn] = []

    func startSignIn(requestID: Int64, provider: String) {
        signInRequests.append(SignIn(requestID: requestID, provider: provider))
    }

    func startSignOut(requestID: Int64) {}
    func startAccessToken(requestID: Int64) {}
}

@MainActor
private final class InMemoryHistoryExecutor: AndroidHistoryExecutor {
    private var encoded: String?

    func loadEncoded() -> String? { encoded }

    func save(subject: String, payload: String) {
        encoded = "\(subject)\n\(payload)"
    }

    func clear() { encoded = nil }
}
