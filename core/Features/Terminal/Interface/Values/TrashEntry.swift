import GrepCore
import RIBs

/// 휴지통 한 줄(api `TrashItem`). daysLeft는 `30일 남음`(ARC-008 규칙 10).
public struct TrashEntry: Equatable, Sendable, Codable {
    public let item: ItemSummary
    public let trashedAt: String
    public let daysLeft: Int

    public init(item: ItemSummary, trashedAt: String, daysLeft: Int) {
        self.item = item
        self.trashedAt = trashedAt
        self.daysLeft = daysLeft
    }
}
