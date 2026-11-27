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
        lines = state.lines.compactMap(LineDTO.init)
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

    init?(_ line: TerminalViewState.Line) {
        switch line {
        case .prompt(let text):
            self.kind = "prompt"
            self.text = text
        case .unknownCommand(let name, let suggestion):
            self.kind = "unknownCommand"
            self.text = name
            self.suggestion = suggestion
        case .missingArgument(let cmd):
            self.kind = "missingArgument"
            self.command = Self.encodeCommand(cmd)
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
        case .noResults(let query, let recent, _):
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
        // shortcut: #95~#120 후속 Android 피처 이슈에서 각 라인 표시를 추가한다.
        case .dropConfirm, .dropped, .revived, .binList, .binEmptyConfirm, .binEmptied,
             .revised, .tagsRemoved, .samplesSaved, .unpicked, .pickCleared, .signOutEverywhereConfirm,
             .bundleList, .bundleAdded, .bundleView, .bundleNotFound, .bundleUnpicked, .notInBundle,
             .bundleDeleteConfirm, .bundleDeleted, .bundleNameInvalid, .folderHint, .itemDetail, .oneNumberOnly,
             .searchSaved, .savedSearchList, .savedSearchPeriod, .savedSearchTooLong, .savedSearchDeleteConfirm,
             .savedSearchDeleted, .savedSearchNotFound, .connectionList, .disconnectConfirm, .disconnected,
             .connectionNotFound, .connectionEnded, .importPrompt, .importProgress, .importFinished:
            return nil
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
