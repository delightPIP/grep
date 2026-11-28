#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FeatureTerminalInterface
import JavaScriptKit

/// 브라우저의 기기 시간대. 이름은 `Intl`에서 받는다.
/// Wasm에는 시간대 DB가 없을 수 있어, 이름으로 못 만들면 지금 UTC와의 차이로 만든다.
enum BrowserTime {
    private static let fallbackID = "Asia/Seoul"
    private static let secondsPerMinute = 60

    @MainActor
    static func deviceTime() -> DeviceTime {
        let id = timeZoneID() ?? fallbackID
        let timeZone = TimeZone(identifier: id) ?? TimeZone(secondsFromGMT: offsetSeconds()) ?? TimeZone(secondsFromGMT: 0)!
        return DeviceTime(timeZone: timeZone, timeZoneID: id, now: { Date() })
    }

    /// `Intl.DateTimeFormat().resolvedOptions().timeZone`
    @MainActor
    private static func timeZoneID() -> String? {
        guard let constructor = JSObject.global.Intl.object?.DateTimeFormat.function else { return nil }
        let formatter = constructor.new()
        guard let resolve = formatter.resolvedOptions.function else { return nil }
        let id = resolve(this: formatter).object?.timeZone.string
        return id?.isEmpty == false ? id : nil
    }

    /// `-new Date().getTimezoneOffset()`분을 초로.
    @MainActor
    private static func offsetSeconds() -> Int {
        guard let constructor = JSObject.global.Date.function else { return 0 }
        let now = constructor.new()
        guard let offset = now.getTimezoneOffset.function?(this: now).number else { return 0 }
        return -Int(offset) * secondsPerMinute
    }
}
