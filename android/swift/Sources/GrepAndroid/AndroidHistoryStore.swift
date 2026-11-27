import GrepCore

/// Kotlin이 구현하는 기록 저장소 실행자.
@MainActor
public protocol AndroidHistoryExecutor: AnyObject {
    /// 저장된 기록을 `"<subject>\n<payload>"` 형태로 돌려준다. 없으면 nil.
    func loadEncoded() -> String?
    func save(subject: String, payload: String)
    func clear()
}

/// Android의 `HistoryStore` 어댑터.
@MainActor
public final class AndroidHistoryStore: HistoryStore {
    private let executor: any AndroidHistoryExecutor

    public init(executor: any AndroidHistoryExecutor) {
        self.executor = executor
    }

    public func load() -> HistoryRecord? {
        guard let encoded = executor.loadEncoded(),
              let separator = encoded.firstIndex(of: "\n")
        else { return nil }
        let subject = String(encoded[..<separator])
        let payload = String(encoded[encoded.index(after: separator)...])
        guard !subject.isEmpty else { return nil }
        return HistoryRecord(subject: subject, payload: payload)
    }

    public func save(_ record: HistoryRecord) {
        executor.save(subject: record.subject, payload: record.payload)
    }

    public func clear() {
        executor.clear()
    }
}
