#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// 기기 시간대와 지금 시각. 테스트는 고정한 값을 넣는다.
public struct DeviceTime: Sendable {
    /// 날짜 경계 계산에 쓴다.
    public let timeZone: TimeZone
    /// 서버 `/groups?tz=`에 보내는 IANA 이름(예 `Asia/Seoul`). 웹은 시간대 DB가 없어
    /// `timeZone`이 고정 오프셋일 수 있으므로 이름을 따로 둔다.
    public let timeZoneID: String
    public let now: @Sendable () -> Date

    public init(timeZone: TimeZone, timeZoneID: String? = nil, now: @escaping @Sendable () -> Date) {
        self.timeZone = timeZone
        self.timeZoneID = timeZoneID ?? timeZone.identifier
        self.now = now
    }

    public static var system: DeviceTime { DeviceTime(timeZone: .current, now: { Date() }) }
}
