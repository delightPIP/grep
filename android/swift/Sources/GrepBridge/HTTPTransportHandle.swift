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
