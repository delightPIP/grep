import Foundation

// 순수 뷰 모델(ADR-0015). `FeatureTerminalUI`는 SwiftUI와 Foundation에만 의존하고 `GrepCore`·`RIBs`를 모른다.

public enum TerminalLineTone: Equatable, Sendable {
    case ok
    case info
    case warn
    case error
}

public struct TerminalItemRef: Equatable, Sendable, Identifiable {
    public var id: Int { number }
    public let number: Int
    public let title: String

    public init(number: Int, title: String) {
        self.number = number
        self.title = title
    }
}

public struct TerminalItemRow: Equatable, Sendable, Identifiable {
    public let id: Int
    public let number: Int
    public let title: String
    public let meta: String
    public let summary: String?
    public let summaryIsWarning: Bool
    public let matchLabel: String?
    public let tags: [String]
    public let isPicked: Bool

    public init(
        number: Int,
        title: String,
        meta: String,
        summary: String?,
        summaryIsWarning: Bool,
        matchLabel: String?,
        tags: [String],
        isPicked: Bool = false
    ) {
        self.id = number
        self.number = number
        self.title = title
        self.meta = meta
        self.summary = summary
        self.summaryIsWarning = summaryIsWarning
        self.matchLabel = matchLabel
        self.tags = tags
        self.isPicked = isPicked
    }
}

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

public enum TerminalOutputBlockLine: Equatable, Sendable {
    case prompt(command: String, failed: Bool)
    case status(tone: TerminalLineTone, boldPrefix: String?, body: String)
    case plain(text: String, dim: Bool)
    case commandHint(prefix: String, command: String, suffix: String)
    case itemRow(TerminalItemRow)
    case list(header: String?, items: [TerminalItemRow], hasMore: Bool)
    case trashList(header: String, rows: [TerminalTrashRow], hasMore: Bool)
    case handedOff(TerminalHandoffPresentation)
    case handoffFailed(reasonLabel: String, preview: String?, isClipboardDenied: Bool)
    case handoffConfirm(total: Int, choices: [TerminalChoiceItem])
    case guide(rows: [TerminalGuideRow])
    case welcome
}

public struct TerminalOutputBlock: Equatable, Sendable, Identifiable {
    public let id: Int
    public let lines: [TerminalOutputBlockLine]

    public init(id: Int, lines: [TerminalOutputBlockLine]) {
        self.id = id
        self.lines = lines
    }
}

/// 답을 기다리는 확인 질문(시안 M9 확인 시트). `answer`는 COM-007 실행 낱말이고 버튼 이름도 같다(MOB-002 규칙 4).
public struct TerminalConfirmPrompt: Equatable, Sendable {
    public let question: String
    public let answer: String

    public init(question: String, answer: String) {
        self.question = question
        self.answer = answer
    }
}

/// `고치기 <번호>` 편집 칸에 넣는 지금 값(시안 20 Edit ①).
public struct TerminalRevisePresentation: Equatable, Sendable {
    public let number: Int
    public let title: String
    public let summary: String

    public init(number: Int, title: String, summary: String) {
        self.number = number
        self.title = title
        self.summary = summary
    }
}

public struct TerminalPresentation: Equatable, Sendable {
    public let title: String
    public let statusText: String
    public let blocks: [TerminalOutputBlock]
    public let selection: [TerminalItemRef]
    public let input: String
    public let isOffline: Bool
    public let pendingConfirm: TerminalConfirmPrompt?
    public let revising: TerminalRevisePresentation?
    /// 0건 첫 화면의 `→ 샘플 8건으로 해 보기`를 보일지(ARC-010 규칙 1). 자료가 0건일 때만 true.
    public let offersSamples: Bool
    /// 터미널 머리 아래 `자료 N건`(COM-009 규칙 5). 건수를 아직 받지 못했으면 nil이고 그 줄을 뺀다.
    public let itemCountLine: String?

    public init(
        title: String = "처음",
        statusText: String = "자료 0 · 선택 0",
        blocks: [TerminalOutputBlock] = [],
        selection: [TerminalItemRef] = [],
        input: String = "",
        isOffline: Bool = false,
        pendingConfirm: TerminalConfirmPrompt? = nil,
        revising: TerminalRevisePresentation? = nil,
        offersSamples: Bool = false,
        itemCountLine: String? = nil
    ) {
        self.title = title
        self.statusText = statusText
        self.blocks = blocks
        self.selection = selection
        self.input = input
        self.isOffline = isOffline
        self.pendingConfirm = pendingConfirm
        self.revising = revising
        self.offersSamples = offersSamples
        self.itemCountLine = itemCountLine
    }
}
