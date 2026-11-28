import GrepAndroid

// MARK: - AuthService

/// Kotlin이 구현한다(`:bridge`의 `AndroidAuthPort`).
public protocol AuthServiceBridge {
    func startSignIn(requestID: Int64, provider: String)
    func startSignOut(requestID: Int64)
    func startAccessToken(requestID: Int64)
}

public final class AuthServiceHandle: Sendable {
    public init() {}

    public func install(bridge: any AuthServiceBridge) {
        nonisolated(unsafe) let bridge = bridge
        MainActor.assumeIsolated {
            precondition(controller == nil, "AuthServiceHandle.install must be called before SwiftBridge.start")
            authService = AndroidAuthService(executor: BridgeAuthExecutor(bridge: bridge))
        }
    }

    public func uninstall() {
        MainActor.assumeIsolated { authService = nil }
    }

    /// `outcome`: `"success"`, `"cancelled"`, `"failed"`. `reason`: `"disconnected"`, `"timedOut"`, `"denied"`, or `""`.
    public func completeSignIn(requestID: Int64, outcome: String, reason: String) {
        MainActor.assumeIsolated { authService?.completeSignIn(requestID: requestID, outcome: outcome, reason: reason) }
    }

    public func completeSignOut(requestID: Int64) {
        MainActor.assumeIsolated { authService?.completeSignOut(requestID: requestID) }
    }

    public func completeAccessToken(requestID: Int64, token: String?) {
        MainActor.assumeIsolated { authService?.completeAccessToken(requestID: requestID, token: token) }
    }
}

@MainActor
private final class BridgeAuthExecutor: AndroidAuthExecutor {
    private let bridge: any AuthServiceBridge
    init(bridge: any AuthServiceBridge) { self.bridge = bridge }
    func startSignIn(requestID: Int64, provider: String) { bridge.startSignIn(requestID: requestID, provider: provider) }
    func startSignOut(requestID: Int64) { bridge.startSignOut(requestID: requestID) }
    func startAccessToken(requestID: Int64) { bridge.startAccessToken(requestID: requestID) }
}
