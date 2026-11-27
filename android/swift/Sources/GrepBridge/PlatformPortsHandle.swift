import GrepAndroid

// MARK: - HTTPTransport

/// Kotlin이 구현한다(`:bridge`의 `HttpUrlConnectionTransport`).
public protocol HTTPTransportBridge {
    /// `headers`는 `이름: 값` 줄을 `\n`으로 끝낸 문자열이고, `body`는 본문이 없으면 빈 문자열이다.
    func start(requestID: Int64, method: String, path: String, headers: String, body: String)
    func cancel(requestID: Int64)
}

public final class HTTPTransportHandle: Sendable {
    public init() {}

    public func install(bridge: any HTTPTransportBridge) {
        nonisolated(unsafe) let bridge = bridge
        MainActor.assumeIsolated {
            precondition(controller == nil, "HTTPTransportHandle.install must be called before SwiftBridge.start")
            httpTransport = AndroidHTTPTransport(sender: BridgeHTTPSender(bridge: bridge))
        }
    }

    public func uninstall() {
        MainActor.assumeIsolated { httpTransport = nil }
    }

    public func complete(requestID: Int64, status: Int32, body: String) {
        MainActor.assumeIsolated { httpTransport?.complete(requestID: requestID, status: Int(status), body: body) }
    }

    public func fail(requestID: Int64, isTimeout: Bool) {
        MainActor.assumeIsolated { httpTransport?.fail(requestID: requestID, isTimeout: isTimeout) }
    }
}

@MainActor
private final class BridgeHTTPSender: AndroidHTTPSender {
    private let bridge: any HTTPTransportBridge
    init(bridge: any HTTPTransportBridge) { self.bridge = bridge }
    func start(requestID: Int64, method: String, path: String, headers: String, body: String) {
        bridge.start(requestID: requestID, method: method, path: path, headers: headers, body: body)
    }
    func cancel(requestID: Int64) { bridge.cancel(requestID: requestID) }
}

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

// MARK: - ClipboardPort

/// Kotlin이 구현한다(`:bridge`의 `AndroidClipboardPort`).
public protocol ClipboardPortBridge {
    func startCopy(requestID: Int64, text: String)
}

public final class ClipboardPortHandle: Sendable {
    public init() {}

    public func install(bridge: any ClipboardPortBridge) {
        nonisolated(unsafe) let bridge = bridge
        MainActor.assumeIsolated {
            precondition(controller == nil, "ClipboardPortHandle.install must be called before SwiftBridge.start")
            clipboardPort = AndroidClipboardPort(executor: BridgeClipboardExecutor(bridge: bridge))
        }
    }

    public func uninstall() {
        MainActor.assumeIsolated { clipboardPort = nil }
    }

    public func completeCopy(requestID: Int64, copied: Bool) {
        MainActor.assumeIsolated { clipboardPort?.completeCopy(requestID: requestID, copied: copied) }
    }
}

@MainActor
private final class BridgeClipboardExecutor: AndroidClipboardExecutor {
    private let bridge: any ClipboardPortBridge
    init(bridge: any ClipboardPortBridge) { self.bridge = bridge }
    func startCopy(requestID: Int64, text: String) { bridge.startCopy(requestID: requestID, text: text) }
}

// MARK: - FilePort

/// Kotlin이 구현한다(`:bridge`의 `AndroidFilePort`).
public protocol FilePortBridge {
    func startUpload(requestID: Int64, fileID: String, uploadURL: String)
    func cancelUpload(requestID: Int64)
    func release(fileID: String)
}

public final class FilePortHandle: Sendable {
    public init() {}

    public func install(bridge: any FilePortBridge) {
        nonisolated(unsafe) let bridge = bridge
        MainActor.assumeIsolated {
            precondition(controller == nil, "FilePortHandle.install must be called before SwiftBridge.start")
            filePort = AndroidFilePort(executor: BridgeFileExecutor(bridge: bridge))
        }
    }

    public func uninstall() {
        MainActor.assumeIsolated { filePort = nil }
    }

    public func completeUpload(requestID: Int64) {
        MainActor.assumeIsolated { filePort?.completeUpload(requestID: requestID) }
    }

    /// `reason`: `"cancelled"`, `"unreachable"`, `"timedOut"`, `"rejected"`, `"missingFile"`.
    public func failUpload(requestID: Int64, reason: String) {
        MainActor.assumeIsolated { filePort?.failUpload(requestID: requestID, reason: reason) }
    }
}

@MainActor
private final class BridgeFileExecutor: AndroidFileExecutor {
    private let bridge: any FilePortBridge
    init(bridge: any FilePortBridge) { self.bridge = bridge }
    func startUpload(requestID: Int64, fileID: String, uploadURL: String) {
        bridge.startUpload(requestID: requestID, fileID: fileID, uploadURL: uploadURL)
    }
    func cancelUpload(requestID: Int64) { bridge.cancelUpload(requestID: requestID) }
    func release(fileID: String) { bridge.release(fileID: fileID) }
}

// MARK: - HistoryStore

/// Kotlin이 구현한다(`:bridge`의 `SharedPrefsHistoryStore`).
public protocol HistoryStoreBridge {
    func loadEncoded() -> String?
    func save(subject: String, payload: String)
    func clear()
}

public final class HistoryStoreHandle: Sendable {
    public init() {}

    public func install(bridge: any HistoryStoreBridge) {
        nonisolated(unsafe) let bridge = bridge
        MainActor.assumeIsolated {
            precondition(controller == nil, "HistoryStoreHandle.install must be called before SwiftBridge.start")
            historyStore = AndroidHistoryStore(executor: BridgeHistoryExecutor(bridge: bridge))
        }
    }

    public func uninstall() {
        MainActor.assumeIsolated { historyStore = nil }
    }
}

@MainActor
private final class BridgeHistoryExecutor: AndroidHistoryExecutor {
    private let bridge: any HistoryStoreBridge
    init(bridge: any HistoryStoreBridge) { self.bridge = bridge }
    func loadEncoded() -> String? { bridge.loadEncoded() }
    func save(subject: String, payload: String) { bridge.save(subject: subject, payload: payload) }
    func clear() { bridge.clear() }
}
