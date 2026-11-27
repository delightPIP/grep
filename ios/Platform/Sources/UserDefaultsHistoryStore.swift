import Foundation
import GrepCore

/// `UserDefaults`로 구현한 터미널 기록 저장소(COM-009).
/// 기록 본문(`payload`)은 코어가 만든 JSON 문자열이며 여기서는 해석하지 않는다.
@MainActor
public final class UserDefaultsHistoryStore: HistoryStore {
    public static let defaultKey = "com.unwrap.grep.history.v1"

    private struct StoredRecord: Codable {
        let subject: String
        let payload: String
    }

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = UserDefaultsHistoryStore.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> HistoryRecord? {
        guard let data = defaults.data(forKey: key) else { return nil }
        guard let stored = try? JSONDecoder().decode(StoredRecord.self, from: data) else { return nil }
        return HistoryRecord(subject: stored.subject, payload: stored.payload)
    }

    public func save(_ record: HistoryRecord) {
        let stored = StoredRecord(subject: record.subject, payload: record.payload)
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: key)
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
