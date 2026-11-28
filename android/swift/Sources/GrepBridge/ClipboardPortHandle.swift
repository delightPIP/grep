import GrepAndroid

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
