import FeatureTerminalInterface
import Foundation
import GrepCore

struct StateDTO: Encodable {
    let itemCount: Int?
    let input: String
    let selection: [ItemRefDTO]
    let processingCount: Int
    let isOffline: Bool
    let lines: [LineDTO]

    init(_ state: TerminalViewState) {
        itemCount = state.itemCount
        input = state.input
        selection = state.selection.map(ItemRefDTO.init)
        processingCount = state.processingCount
        isOffline = state.isOffline
        lines = state.lines.map(LineDTO.init)
    }
}

struct ItemRefDTO: Encodable {
    let number: Int
    let title: String

    init(_ ref: ItemRef) {
        number = ref.number
        title = ref.title
    }
}

struct ItemSummaryDTO: Encodable {
    let number: Int
    let kind: String
    let title: String
    let source: String?
    let status: String
    let blockedReason: String?
    let listSummary: String?
    let summarySource: String?
    let partialNote: String?
    let tags: [String]
    let matchedIn: String?
    let savedAt: String

    init(_ item: ItemSummary) {
        number = item.number
        kind = item.kind.rawValue
        title = item.title
        source = item.source
        status = item.status.rawValue
        blockedReason = item.blockedReason?.rawValue
        listSummary = item.listSummary
        summarySource = item.summarySource?.rawValue
        partialNote = item.partialNote
        tags = item.tags
        matchedIn = item.matchedIn?.rawValue
        savedAt = item.savedAt
    }
}

struct SearchQueryDTO: Encodable {
    let text: String
    let words: String
    let tags: [String]

    init(_ query: SearchQuery) {
        text = query.text
        words = query.words
        tags = query.tags
    }
}

struct HandoffResultDTO: Encodable {
    let items: [ItemRefDTO]
    let charCount: Int
    let missingSummaryCount: Int
    let text: String

    init(_ result: HandoffResult) {
        items = result.items.map(ItemRefDTO.init)
        charCount = result.charCount
        missingSummaryCount = result.missingSummaryCount
        text = result.text
    }
}

struct NameCountDTO: Encodable {
    let name: String
    let count: Int
}

struct TrashEntryDTO: Encodable {
    let item: ItemSummaryDTO
    let daysLeft: Int

    init(_ entry: TrashEntry) {
        item = ItemSummaryDTO(entry.item)
        daysLeft = entry.daysLeft
    }
}

struct ConnectionDTO: Encodable {
    let number: Int
    let client: String
    let connectedAt: String
    let lastReadAt: String?

    init(_ entry: ConnectionEntry) {
        number = entry.number
        client = entry.client
        connectedAt = entry.connectedAt
        lastReadAt = entry.lastReadAt
    }
}

struct ItemDetailDTO: Encodable {
    let item: ItemSummaryDTO
    let url: String?
    let handoffSummary: String?
    let allTags: [String]
    let bundles: [String]
    let bodyLength: Int?
    let body: String?
    let bodyFromImage: Bool
    let originalUrl: String?
    let previewUrl: String?

    init(_ detail: ItemDetail) {
        item = ItemSummaryDTO(detail.item)
        url = detail.url
        handoffSummary = detail.handoffSummary
        allTags = detail.allTags
        bundles = detail.bundles
        bodyLength = detail.bodyLength
        body = detail.body
        bodyFromImage = detail.bodyFromImage
        originalUrl = detail.originalUrl
        previewUrl = detail.previewUrl
    }
}

struct ImportResultDTO: Encodable {
    let saved: Int
    let skipped: Int
    let failed: Int
    let overLimit: Int
    let failedUrls: [String]
}
