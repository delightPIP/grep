import Foundation

/// 보관함 목록의 자료 한 행(시안 `MList.dc.html`).
public struct ArchiveItemRow: Identifiable, Equatable, Sendable {
    public var id: Int { number }
    public let number: Int
    public let title: String
    public let meta: String
    public let summary: String?
    public let summaryIsWarning: Bool
    public let tags: [String]
    public let isPicked: Bool

    public init(
        number: Int,
        title: String,
        meta: String,
        summary: String?,
        summaryIsWarning: Bool,
        tags: [String],
        isPicked: Bool
    ) {
        self.number = number
        self.title = title
        self.meta = meta
        self.summary = summary
        self.summaryIsWarning = summaryIsWarning
        self.tags = tags
        self.isPicked = isPicked
    }
}

/// 보관함 순수 뷰가 그리는 값 전체.
public struct ArchivePresentation: Equatable, Sendable {
    public var statusText: String
    public var items: [ArchiveItemRow]
    public var pickedCount: Int
    public var pickedSummary: String
    public var isLoading: Bool
    public var isLoadingMore: Bool
    public var hasMore: Bool
    public var errorMessage: String?

    public init(
        statusText: String = "자료",
        items: [ArchiveItemRow] = [],
        pickedCount: Int = 0,
        pickedSummary: String = "",
        isLoading: Bool = false,
        isLoadingMore: Bool = false,
        hasMore: Bool = false,
        errorMessage: String? = nil
    ) {
        self.statusText = statusText
        self.items = items
        self.pickedCount = pickedCount
        self.pickedSummary = pickedSummary
        self.isLoading = isLoading
        self.isLoadingMore = isLoadingMore
        self.hasMore = hasMore
        self.errorMessage = errorMessage
    }
}
