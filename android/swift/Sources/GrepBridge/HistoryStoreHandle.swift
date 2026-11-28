import GrepAndroid

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
