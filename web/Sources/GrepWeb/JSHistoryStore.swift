import GrepCore
import JavaScriptKit

/// JS가 구현한 기록 저장소(`web/ports/history-store.ts`의 `HistoryStore`)를 코어의 `HistoryStore`로 잇는다.
@MainActor
final class JSHistoryStore: HistoryStore {
    private let store: JSObject

    init(store: JSObject) {
        self.store = store
    }

    func load() -> HistoryRecord? {
        guard let record = store.load!().object,
            let subject = record.subject.string,
            let payload = record.payload.string
        else { return nil }
        return HistoryRecord(subject: subject, payload: payload)
    }

    func save(_ record: HistoryRecord) {
        let value: [String: String] = ["subject": record.subject, "payload": record.payload]
        _ = store.save!(value)
    }

    func clear() {
        _ = store.clear!()
    }
}
