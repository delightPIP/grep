import Foundation

// 순수 뷰 모델(ADR-0015). `FeatureTerminalUI`는 SwiftUI와 Foundation에만 의존하고 `GrepCore`·`RIBs`를 모른다.
// 화면 전체 값과 그 안의 확인 질문·편집 칸.

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
