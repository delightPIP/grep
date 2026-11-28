import GrepAndroid

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
