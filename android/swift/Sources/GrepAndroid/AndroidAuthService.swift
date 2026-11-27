import GrepCore

/// Kotlin이 구현하는 인증 포트 실행자.
@MainActor
public protocol AndroidAuthExecutor: AnyObject {
    func startSignIn(requestID: Int64, provider: String)
    func startSignOut(requestID: Int64)
    func startAccessToken(requestID: Int64)
}

/// Android의 `AuthService` 어댑터. 요청은 Kotlin으로 넘기고 결과를 `requestID`로 짝 맞춘다.
@MainActor
public final class AndroidAuthService: AuthService {
    private let executor: any AndroidAuthExecutor
    private var pendingSignIn: [Int64: CheckedContinuation<SignInResult, Never>] = [:]
    private var pendingSignOut: [Int64: CheckedContinuation<Void, Never>] = [:]
    private var pendingAccessToken: [Int64: CheckedContinuation<String?, Never>] = [:]
    private var nextRequestID: Int64 = 1

    public init(executor: any AndroidAuthExecutor) {
        self.executor = executor
    }

    public func signIn(_ provider: AuthProvider) async -> SignInResult {
        let requestID = nextID()
        return await withCheckedContinuation { continuation in
            pendingSignIn[requestID] = continuation
            executor.startSignIn(requestID: requestID, provider: provider.rawValue)
        }
    }

    public func signOut() async {
        let requestID = nextID()
        await withCheckedContinuation { continuation in
            pendingSignOut[requestID] = continuation
            executor.startSignOut(requestID: requestID)
        }
    }

    public func accessToken() async -> String? {
        let requestID = nextID()
        return await withCheckedContinuation { continuation in
            pendingAccessToken[requestID] = continuation
            executor.startAccessToken(requestID: requestID)
        }
    }

    public func completeSignIn(requestID: Int64, outcome: String, reason: String) {
        let result: SignInResult = switch outcome {
        case "success":
            .success
        case "cancelled":
            .cancelled
        default:
            .failed(Self.failureReason(from: reason))
        }
        pendingSignIn.removeValue(forKey: requestID)?.resume(returning: result)
    }

    public func completeSignOut(requestID: Int64) {
        pendingSignOut.removeValue(forKey: requestID)?.resume()
    }

    public func completeAccessToken(requestID: Int64, token: String?) {
        pendingAccessToken.removeValue(forKey: requestID)?.resume(returning: token)
    }

    private func nextID() -> Int64 {
        let id = nextRequestID
        nextRequestID += 1
        return id
    }

    private static func failureReason(from raw: String) -> SignInFailureReason {
        switch raw {
        case "disconnected": .disconnected
        case "timedOut": .timedOut
        default: .denied
        }
    }
}
