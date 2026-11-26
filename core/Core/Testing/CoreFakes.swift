import GrepCore
import RIBs

/// 메인 액터에 쌓인 Task가 다음 대기 지점까지 돌도록 양보한다.
@MainActor
public func runCurrent() async {
    for _ in 0..<50 { await Task.yield() }
}

/// 로그인 창이 닫히는 시점과 결과를 테스트가 정하는 인증 서비스.
@MainActor
public final class FakeAuthService: AuthService {
    public private(set) var signInRequests: [AuthProvider] = []
    public private(set) var signOutCount = 0
    /// `accessToken()`이 돌려줄 값. nil이면 세션이 없거나 갱신에 실패한 것이다.
    public var token: String?
    private var pending: CheckedContinuation<SignInResult, Never>?

    public init(token: String? = nil) {
        self.token = token
    }

    public func signIn(_ provider: AuthProvider) async -> SignInResult {
        signInRequests.append(provider)
        return await withTaskCancellationHandler {
            await withCheckedContinuation { pending = $0 }
        } onCancel: {
            Task { @MainActor in self.respond(.cancelled) }
        }
    }

    /// 열려 있는 로그인 창을 `result`로 끝낸다. 성공이면 토큰이 생긴다.
    public func respond(_ result: SignInResult, token: String = "token") {
        guard let continuation = pending else { return }
        pending = nil
        if result == .success { self.token = token }
        continuation.resume(returning: result)
    }

    public func signOut() async {
        signOutCount += 1
        token = nil
    }

    public func accessToken() async -> String? { token }
}

/// 응답 시점과 내용을 테스트가 정하는 전송 계층. 기다리는 요청이 여럿이면 먼저 온 요청부터 응답한다.
@MainActor
public final class FakeHTTPTransport: HTTPTransport {
    public private(set) var requests: [HTTPRequest] = []
    private var pending: [CheckedContinuation<Result<HTTPResponse, HTTPTransportError>, Never>] = []

    public init() {}

    public func send(_ request: HTTPRequest) async throws(HTTPTransportError) -> HTTPResponse {
        requests.append(request)
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { pending.append($0) }
        } onCancel: {
            Task { @MainActor in self.respond(.failure(.cancelled)) }
        }
        return try result.get()
    }

    /// 가장 먼저 기다리기 시작한 요청에 응답한다. 기다리는 요청이 없으면 아무것도 하지 않는다.
    public func respond(_ result: Result<HTTPResponse, HTTPTransportError>) {
        guard !pending.isEmpty else { return }
        pending.removeFirst().resume(returning: result)
    }

    public func respond(status: Int = 200, json: String) {
        respond(.success(HTTPResponse(status: status, body: Array(json.utf8))))
    }
}

/// 피처를 단독으로 테스트할 때 부모 역할을 하는 Router. 자식을 붙이면 활성화되고, 떼면 비활성화된다.
@MainActor
public final class TestParentRouter {
    public let router = Router(interactor: Interactor())

    public init() {
        router.load()
        router.interactable.activate()
    }

    public func attach(_ child: any Routing) { router.attachChild(child) }

    public func detach(_ child: any Routing) { router.detachChild(child) }
}

/// 자식 Buildable 가짜가 돌려주는 빈 Router. 뷰만 가진다.
public typealias StubRouter<View> = ViewableRouter<Interactor, View>
