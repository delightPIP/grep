import Foundation

// 순수 뷰 모델(ADR-0015). `FeatureTerminalUI`는 SwiftUI와 Foundation에만 의존하고 `GrepCore`·`RIBs`를 모른다.
// 넘기기·안내·휴지통 블록이 쓰는 행 값.

public struct TerminalHandoffPresentation: Equatable, Sendable {
    public let items: [TerminalItemRef]
    public let charCountText: String
    public let missingSummaryCount: Int
    public let text: String

    public init(
        items: [TerminalItemRef],
        charCountText: String,
        missingSummaryCount: Int,
        text: String
    ) {
        self.items = items
        self.charCountText = charCountText
        self.missingSummaryCount = missingSummaryCount
        self.text = text
    }
}

public struct TerminalChoiceItem: Equatable, Sendable, Identifiable {
    public var id: String { command }
    public let command: String
    public let label: String

    public init(command: String, label: String) {
        self.command = command
        self.label = label
    }
}

public struct TerminalGuideRow: Equatable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let english: String
    public let meaning: String

    public init(name: String, english: String, meaning: String) {
        self.name = name
        self.english = english
        self.meaning = meaning
    }
}

/// 휴지통 목록 한 줄. `meta`의 끝은 영구 삭제까지 남은 날(`30일 남음`, ARC-008 규칙 10).
public struct TerminalTrashRow: Equatable, Sendable, Identifiable {
    public var id: Int { number }
    public let number: Int
    public let title: String
    public let meta: String

    public init(number: Int, title: String, meta: String) {
        self.number = number
        self.title = title
        self.meta = meta
    }
}
