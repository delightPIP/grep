import GrepCore
import RIBs

/// `고치기 <번호>` 편집 중인 자료(화면 W24).
public struct Revising: Equatable, Sendable, Codable {
    public let number: Int
    public let title: String
    public let summary: String

    public init(number: Int, title: String, summary: String) {
        self.number = number
        self.title = title
        self.summary = summary
    }
}
