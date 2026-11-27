import GrepCore

/// Kotlin이 구현하는 클립보드 포트 실행자.
@MainActor
public protocol AndroidClipboardExecutor: AnyObject {
    func startCopy(requestID: Int64, text: String)
}

/// Android의 `ClipboardPort` 어댑터.
@MainActor
public final class AndroidClipboardPort: ClipboardPort {
    private let executor: any AndroidClipboardExecutor
    private var pending: [Int64: CheckedContinuation<ClipboardResult, Never>] = [:]
    private var nextRequestID: Int64 = 1

    public init(executor: any AndroidClipboardExecutor) {
        self.executor = executor
    }

    public func copy(_ text: String) async -> ClipboardResult {
        let requestID = nextRequestID
        nextRequestID += 1
        return await withCheckedContinuation { continuation in
            pending[requestID] = continuation
            executor.startCopy(requestID: requestID, text: text)
        }
    }

    public func completeCopy(requestID: Int64, copied: Bool) {
        pending.removeValue(forKey: requestID)?.resume(returning: copied ? .copied : .denied)
    }
}
