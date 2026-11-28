import FeatureTerminalInterface
import Foundation
import GrepCore

/// `TerminalViewState`를 Android Kotlin 어댑터가 읽는 JSON 문자열로 직렬화한다.
/// Swift-Java 브리지 시그니처를 단순하게 유지하면서 이후 피처 확장을 쉽게 하기 위한 전송 형식이다.
public enum TerminalStateEncoder {
    public static func encode(_ state: TerminalViewState) -> String {
        let dto = StateDTO(state)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(dto),
              let json = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return json
    }
}

private struct StateDTO: Encodable {
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

private struct ItemRefDTO: Encodable {
    let number: Int
    let title: String

    init(_ ref: ItemRef) {
        number = ref.number
        title = ref.title
    }
}

private struct ItemSummaryDTO: Encodable {
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

private struct SearchQueryDTO: Encodable {
    let text: String
    let words: String
    let tags: [String]

    init(_ query: SearchQuery) {
        text = query.text
        words = query.words
        tags = query.tags
    }
}

private struct HandoffResultDTO: Encodable {
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

private struct NameCountDTO: Encodable {
    let name: String
    let count: Int
}

private struct TrashEntryDTO: Encodable {
    let item: ItemSummaryDTO
    let daysLeft: Int

    init(_ entry: TrashEntry) {
        item = ItemSummaryDTO(entry.item)
        daysLeft = entry.daysLeft
    }
}

private struct ConnectionDTO: Encodable {
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

private struct ItemDetailDTO: Encodable {
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

private struct ImportResultDTO: Encodable {
    let saved: Int
    let skipped: Int
    let failed: Int
    let overLimit: Int
    let failedUrls: [String]
}

private struct LineDTO: Encodable {
    let kind: String
    var text: String? = nil
    var suggestion: String? = nil
    var command: String? = nil
    var item: ItemSummaryDTO? = nil
    var items: [ItemSummaryDTO]? = nil
    var refs: [ItemRefDTO]? = nil
    var number: Int? = nil
    var numbers: [Int]? = nil
    var hasMore: Bool? = nil
    var total: Int? = nil
    var query: SearchQueryDTO? = nil
    var failure: String? = nil
    var fileExtension: String? = nil
    var fileName: String? = nil
    var bytes: Int? = nil
    var recovery: String? = nil
    var retry: String? = nil
    var handoff: HandoffResultDTO? = nil
    var preview: String? = nil
    var sub: String? = nil
    var name: String? = nil
    var count: Int? = nil
    var alreadyCount: Int? = nil
    var remaining: Int? = nil
    var firstNumber: Int? = nil
    var lastNumber: Int? = nil
    var already: Bool? = nil
    var tags: [String]? = nil
    var trash: [TrashEntryDTO]? = nil
    var entries: [NameCountDTO]? = nil
    var connections: [ConnectionDTO]? = nil
    var detail: ItemDetailDTO? = nil
    var importResult: ImportResultDTO? = nil
    var done: Int? = nil

    init(_ line: TerminalViewState.Line) {
        switch line {
        case .prompt(let text):
            self.kind = "prompt"
            self.text = text
        case .unknownCommand(let name, let suggestion):
            self.kind = "unknownCommand"
            self.text = name
            self.suggestion = suggestion
        case .missingArgument(let cmd, let sub):
            self.kind = "missingArgument"
            self.command = Self.encodeCommand(cmd)
            self.sub = sub?.rawValue
        case .missingTag:
            self.kind = "missingTag"
        case .saved(let item):
            self.kind = "saved"
            self.item = ItemSummaryDTO(item)
        case .alreadySaved(let item):
            self.kind = "alreadySaved"
            self.item = ItemSummaryDTO(item)
        case .inTrash(let number):
            self.kind = "inTrash"
            self.number = number
        case .saveFailed(let failure, let recovery):
            self.kind = "saveFailed"
            switch failure {
            case .disconnected:
                self.failure = "disconnected"
            case .timedOut:
                self.failure = "timedOut"
            case .serverError:
                self.failure = "serverError"
            case .unsupportedFormat(let ext):
                self.failure = "unsupportedFormat"
                self.fileExtension = ext
            case .tooLarge(let fileName, let bytes):
                self.failure = "tooLarge"
                self.fileName = fileName
                self.bytes = bytes
            }
            switch recovery {
            case .inputKept:
                self.recovery = "inputKept"
            case .retry(let cmd):
                self.recovery = "retry"
                self.retry = cmd
            case .file(let name):
                self.recovery = "file"
                self.fileName = self.fileName ?? name
            }
        case .recentList(let items, let hasMore, let total, _):
            self.kind = "recentList"
            self.items = items.map(ItemSummaryDTO.init)
            self.hasMore = hasMore
            self.total = total
        case .searchResult(let query, let total, let items, let hasMore, _, _):
            self.kind = "searchResult"
            self.query = SearchQueryDTO(query)
            self.total = total
            self.items = items.map(ItemSummaryDTO.init)
            self.hasMore = hasMore
        case .noResults(let query, let recent, _, _):
            self.kind = "noResults"
            self.query = SearchQueryDTO(query)
            self.items = recent.map(ItemSummaryDTO.init)
        case .picked(let refs):
            self.kind = "picked"
            self.refs = refs.map(ItemRefDTO.init)
        case .notFound(let numbers):
            self.kind = "notFound"
            self.numbers = numbers
        case .invalidNumber(let text):
            self.kind = "invalidNumber"
            self.text = text
        case .handedOff(let result):
            self.kind = "handedOff"
            self.handoff = HandoffResultDTO(result)
        case .handoffFailed(let reason, let preview):
            self.kind = "handoffFailed"
            self.failure = Self.encodeCommandFailure(reason)
            self.preview = preview
        case .commandFailed(let cmd, let reason, let retry):
            self.kind = "commandFailed"
            self.command = Self.encodeCommand(cmd)
            self.failure = Self.encodeCommandFailure(reason)
            self.retry = retry
        case .handoffConfirm(let total):
            self.kind = "handoffConfirm"
            self.total = total
        case .cancelled:
            self.kind = "cancelled"
        case .welcome:
            self.kind = "welcome"
        case .guide:
            self.kind = "guide"
        case .about(let cmd):
            self.kind = "about"
            self.command = Self.encodeCommand(cmd)
        case .reconnected:
            self.kind = "reconnected"
        // #93 정리(ARC-008)
        case .dropConfirm(let total):
            self.kind = "dropConfirm"
            self.total = total
        case .dropped(let refs):
            self.kind = "dropped"
            self.refs = refs.map(ItemRefDTO.init)
        case .revived(let refs):
            self.kind = "revived"
            self.refs = refs.map(ItemRefDTO.init)
        case .binList(let total, let items, let hasMore):
            self.kind = "binList"
            self.total = total
            self.trash = items.map(TrashEntryDTO.init)
            self.hasMore = hasMore
        case .binEmptyConfirm(let total):
            self.kind = "binEmptyConfirm"
            self.total = total
        case .binEmptied(let count):
            self.kind = "binEmptied"
            self.count = count
        // #93 고치기·샘플, #108 고르기 빼기, #111 모든 기기 로그아웃
        case .revised(let item):
            self.kind = "revised"
            self.item = ItemSummaryDTO(item)
        case .tagsRemoved(let item, let tags):
            self.kind = "tagsRemoved"
            self.item = ItemSummaryDTO(item)
            self.tags = tags
        case .samplesSaved(let firstNumber, let lastNumber, let items):
            self.kind = "samplesSaved"
            self.firstNumber = firstNumber
            self.lastNumber = lastNumber
            self.items = items.map(ItemSummaryDTO.init)
        case .unpicked(let refs, let remaining):
            self.kind = "unpicked"
            self.refs = refs.map(ItemRefDTO.init)
            self.remaining = remaining
        case .pickCleared(let count):
            self.kind = "pickCleared"
            self.count = count
        case .signOutEverywhereConfirm(let connectionCount):
            self.kind = "signOutEverywhereConfirm"
            self.count = connectionCount
        // 계약 2 묶음(ARC-003)
        case .bundleList(let bundles):
            self.kind = "bundleList"
            self.entries = bundles.map { NameCountDTO(name: $0.name, count: $0.count) }
        case .bundleAdded(let name, let count, let alreadyCount):
            self.kind = "bundleAdded"
            self.name = name
            self.count = count
            self.alreadyCount = alreadyCount
        case .bundleView(let name, let total, let items, let hasMore):
            self.kind = "bundleView"
            self.name = name
            self.total = total
            self.items = items.map(ItemSummaryDTO.init)
            self.hasMore = hasMore
        case .bundleNotFound(let name):
            self.kind = "bundleNotFound"
            self.name = name
        case .bundleUnpicked(let name, let remaining):
            self.kind = "bundleUnpicked"
            self.name = name
            self.remaining = remaining
        case .notInBundle(let name, let numbers):
            self.kind = "notInBundle"
            self.name = name
            self.numbers = numbers
        case .bundleDeleteConfirm(let name, let itemCount):
            self.kind = "bundleDeleteConfirm"
            self.name = name
            self.count = itemCount
        case .bundleDeleted(let name):
            self.kind = "bundleDeleted"
            self.name = name
        case .bundleNameInvalid(let problem):
            self.kind = "bundleNameInvalid"
            self.failure = problem.rawValue
        case .folderHint:
            self.kind = "folderHint"
        // 계약 2 자세히 보기(ARC-011)
        case .itemDetail(let detail):
            self.kind = "itemDetail"
            self.detail = ItemDetailDTO(detail)
        case .oneNumberOnly(let cmd):
            self.kind = "oneNumberOnly"
            self.command = Self.encodeCommand(cmd)
        // 계약 2 찾아두기(ARC-012)
        case .searchSaved(let query, let total, let already):
            self.kind = "searchSaved"
            self.text = query
            self.total = total
            self.already = already
        case .savedSearchList(let searches):
            self.kind = "savedSearchList"
            self.entries = searches.map { NameCountDTO(name: $0.query, count: $0.count) }
        case .savedSearchPeriod(let period, let suggestion):
            self.kind = "savedSearchPeriod"
            self.text = period
            self.suggestion = suggestion
        case .savedSearchTooLong:
            self.kind = "savedSearchTooLong"
        case .savedSearchDeleteConfirm(let query):
            self.kind = "savedSearchDeleteConfirm"
            self.text = query
        case .savedSearchDeleted(let query):
            self.kind = "savedSearchDeleted"
            self.text = query
        case .savedSearchNotFound(let query):
            self.kind = "savedSearchNotFound"
            self.text = query
        // 계약 2 AI 도구 연결(ACC-002)
        case .connectionList(let mcpUrl, let connections):
            self.kind = "connectionList"
            self.text = mcpUrl
            self.connections = connections.map(ConnectionDTO.init)
        case .disconnectConfirm(let number, let client):
            self.kind = "disconnectConfirm"
            self.number = number
            self.name = client
        case .disconnected(let client, let already):
            self.kind = "disconnected"
            self.name = client
            self.already = already
        case .connectionNotFound(let number):
            self.kind = "connectionNotFound"
            self.number = number
        case .connectionEnded(let client, let reason):
            self.kind = "connectionEnded"
            self.name = client
            self.failure = reason.rawValue
        // 계약 2 북마크 가져오기(commands 6절)
        case .importPrompt:
            self.kind = "importPrompt"
        case .importProgress(let done, let total):
            self.kind = "importProgress"
            self.done = done
            self.total = total
        case .importFinished(let saved, let skipped, let failed, let overLimit, let failedUrls):
            self.kind = "importFinished"
            self.importResult = ImportResultDTO(
                saved: saved, skipped: skipped, failed: failed, overLimit: overLimit, failedUrls: failedUrls
            )
        case .importSuggest(let fileName):
            self.kind = "importSuggest"
            self.fileName = fileName
        }
    }

    private static func encodeCommand(_ command: CommandName) -> String {
        switch command {
        case .keep: "keep"
        case .recent: "recent"
        case .seek: "seek"
        case .pick: "pick"
        case .handoff: "handoff"
        case .guide: "guide"
        case .about: "about"
        case .signOut: "signOut"
        case .revise: "revise"
        case .drop: "drop"
        case .revive: "revive"
        case .bin: "bin"
        case .pack: "pack"
        case .peek: "peek"
        case .gather: "gather"
        case .bring: "bring"
        case .plug: "plug"
        }
    }

    private static func encodeCommandFailure(_ failure: CommandFailure) -> String {
        switch failure {
        case .disconnected: "disconnected"
        case .timedOut: "timedOut"
        case .serverError: "serverError"
        case .clipboardDenied: "clipboardDenied"
        }
    }
}
