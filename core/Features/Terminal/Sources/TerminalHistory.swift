#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FeatureTerminalInterface
import GrepCore

/// 이 기기에 남기는 터미널 기록의 모양(COM-009). `HistoryRecord.payload`에 JSON으로 넣는다.
/// 플랫폼은 해석하지 않는다. 읽지 못하는 기록은 없는 것으로 본다.
enum TerminalHistory {
    /// 남기는 출력 줄 수(COM-009 값). 넘으면 오래된 줄부터 버린다.
    static let maxLines = 200
    private static let version = 1

    /// 남기는 값: 출력, 치던 글, 선택(COM-009 규칙 1).
    struct Snapshot: Equatable {
        var lines: [TerminalViewState.Line]
        var input: String
        var selection: [ItemRef]
    }

    private struct Payload: Codable {
        let version: Int
        let input: String
        let selection: [StoredRef]
        /// 줄들의 JSON. 줄이 그대로면 다시 만들지 않도록 글로 둔다.
        let lines: String
    }

    static func encode(_ snapshot: Snapshot) -> String {
        payload(linesJSON: encodeLines(snapshot.lines), input: snapshot.input, selection: snapshot.selection)
    }

    /// 최근 `maxLines`줄을 JSON으로 만든다.
    static func encodeLines(_ lines: [TerminalViewState.Line]) -> String {
        json(of: kept(lines).compactMap(StoredLine.init))
    }

    static func payload(linesJSON: String, input: String, selection: [ItemRef]) -> String {
        json(of: Payload(version: version, input: input, selection: selection.map(StoredRef.init), lines: linesJSON))
    }

    /// 모양이 다르거나 버전이 다르면 nil.
    static func decode(_ payload: String) -> Snapshot? {
        guard let payload = value(Payload.self, from: payload), payload.version == version,
              let lines = value([StoredLine].self, from: payload.lines) else { return nil }
        return Snapshot(
            lines: lines.compactMap(\.line), input: payload.input, selection: payload.selection.map(\.ref)
        )
    }

    /// 넘친 만큼 앞을 버린다. 덩어리 중간에서 시작하지 않도록 명령 줄부터 남긴다.
    private static func kept(_ lines: [TerminalViewState.Line]) -> [TerminalViewState.Line] {
        guard lines.count > maxLines else { return lines }
        let recent = lines.suffix(maxLines)
        let fromPrompt = recent.drop { !$0.isPrompt }
        return Array(fromPrompt.isEmpty ? recent : fromPrompt)
    }

    private static func json(of value: some Encodable) -> String {
        // 고정 모양의 값이라 인코딩은 실패하지 않는다.
        let data = (try? JSONEncoder().encode(value)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    private static func value<T: Decodable>(_ type: T.Type, from json: String) -> T? {
        try? JSONDecoder().decode(type, from: Data(json.utf8))
    }
}

extension TerminalViewState.Line {
    fileprivate var isPrompt: Bool {
        if case .prompt = self { true } else { false }
    }
}

// MARK: 남기는 모양

private struct StoredRef: Codable {
    let number: Int
    let title: String

    init(_ ref: ItemRef) {
        number = ref.number
        title = ref.title
    }

    var ref: ItemRef { ItemRef(number: number, title: title) }
}

private struct StoredQuery: Codable {
    let text: String
    let words: String
    let tags: [String]

    init(_ query: SearchQuery) {
        text = query.text
        words = query.words
        tags = query.tags
    }

    var query: SearchQuery { SearchQuery(text: text, words: words, tags: tags) }
}

private struct StoredHandoff: Codable {
    let items: [StoredRef]
    /// 계약 2. 그 전 기록에는 없다.
    let bundle: String?
    let removedCount: Int?
    let charCount: Int
    let missingSummaryCount: Int
    let text: String

    init(_ result: HandoffResult) {
        items = result.items.map(StoredRef.init)
        bundle = result.bundle
        removedCount = result.removedCount
        charCount = result.charCount
        missingSummaryCount = result.missingSummaryCount
        text = result.text
    }

    var result: HandoffResult {
        HandoffResult(
            items: items.map(\.ref),
            bundle: bundle,
            removedCount: removedCount ?? 0,
            charCount: charCount,
            missingSummaryCount: missingSummaryCount,
            text: text
        )
    }
}

private struct StoredSaveFailure: Codable {
    enum Kind: String, Codable {
        case disconnected, timedOut, serverError, unsupportedFormat, tooLarge
    }

    let kind: Kind
    var fileExtension: String?
    var fileName: String?
    var bytes: Int?

    init(_ failure: SaveFailure) {
        switch failure {
        case .disconnected: kind = .disconnected
        case .timedOut: kind = .timedOut
        case .serverError: kind = .serverError
        case .unsupportedFormat(let fileExtension):
            kind = .unsupportedFormat
            self.fileExtension = fileExtension
        case .tooLarge(let fileName, let bytes):
            kind = .tooLarge
            self.fileName = fileName
            self.bytes = bytes
        }
    }

    var failure: SaveFailure? {
        switch kind {
        case .disconnected: .disconnected
        case .timedOut: .timedOut
        case .serverError: .serverError
        case .unsupportedFormat: fileExtension.map { .unsupportedFormat(fileExtension: $0) }
        case .tooLarge:
            if let fileName, let bytes { .tooLarge(fileName: fileName, bytes: bytes) } else { nil }
        }
    }
}

private struct StoredRecovery: Codable {
    enum Kind: String, Codable {
        case inputKept, retry, file
    }

    let kind: Kind
    var text: String?

    init(_ recovery: SaveRecovery) {
        switch recovery {
        case .inputKept: kind = .inputKept
        case .retry(let command):
            kind = .retry
            text = command
        case .file(let name):
            kind = .file
            text = name
        }
    }

    var recovery: SaveRecovery? {
        switch kind {
        case .inputKept: .inputKept
        case .retry: text.map { .retry($0) }
        case .file: text.map { .file(name: $0) }
        }
    }
}

/// 출력 한 줄. 줄 종류마다 쓰는 칸만 채운다.
private struct StoredLine: Codable {
    enum Kind: String, Codable {
        case prompt, unknownCommand, missingArgument, missingTag, saved, alreadySaved, inTrash, saveFailed
        case recentList, searchResult, noResults, picked, notFound, invalidNumber, handedOff, handoffFailed
        case commandFailed, handoffConfirm, cancelled, welcome, guide, about, reconnected
        case dropConfirm, dropped, revived, binList, binEmptyConfirm, binEmptied
        case revised, tagsRemoved, samplesSaved, unpicked, pickCleared, signOutEverywhereConfirm
        case bundleList, bundleAdded, bundleView, bundleNotFound, bundleUnpicked, notInBundle
        case bundleDeleteConfirm, bundleDeleted, bundleNameInvalid
    }

    let kind: Kind
    var text: String?
    var suggestion: String?
    var command: String?
    var reason: String?
    var number: Int?
    var numbers: [Int]?
    var total: Int?
    var hasMore: Bool?
    var items: [ItemSummary]?
    var refs: [StoredRef]?
    var trashEntries: [TrashEntry]?
    var period: Period?
    var tags: [String]?
    var firstNumber: Int?
    var lastNumber: Int?
    var count: Int?
    var query: StoredQuery?
    var handoff: StoredHandoff?
    var saveFailure: StoredSaveFailure?
    var recovery: StoredRecovery?
    var name: String?
    var extraCount: Int?
    var bundles: [BundleEntry]?

    /// 아직 남기지 않는 줄(계약 2, 각 이슈에서 더한다)이면 nil.
    init?(_ line: TerminalViewState.Line) {
        switch line {
        case .prompt(let text):
            kind = .prompt
            self.text = text
        case .unknownCommand(let name, let suggestion):
            kind = .unknownCommand
            text = name
            self.suggestion = suggestion
        case .missingArgument(let command):
            kind = .missingArgument
            self.command = command.storedName
        case .missingTag: kind = .missingTag
        case .saved(let item):
            kind = .saved
            items = [item]
        case .alreadySaved(let item):
            kind = .alreadySaved
            items = [item]
        case .inTrash(let number):
            kind = .inTrash
            self.number = number
        case .saveFailed(let failure, let recovery):
            kind = .saveFailed
            saveFailure = StoredSaveFailure(failure)
            self.recovery = StoredRecovery(recovery)
        case .recentList(let items, let hasMore, let total, let period):
            kind = .recentList
            self.items = items
            self.hasMore = hasMore
            self.total = total
            self.period = period
        case .searchResult(let query, let total, let items, let hasMore, let period):
            kind = .searchResult
            self.query = StoredQuery(query)
            self.total = total
            self.items = items
            self.hasMore = hasMore
            self.period = period
        case .noResults(let query, let recent, let period):
            kind = .noResults
            self.query = StoredQuery(query)
            items = recent
            self.period = period
        case .picked(let refs):
            kind = .picked
            self.refs = refs.map(StoredRef.init)
        case .notFound(let numbers):
            kind = .notFound
            self.numbers = numbers
        case .invalidNumber(let input):
            kind = .invalidNumber
            text = input
        case .handedOff(let result):
            kind = .handedOff
            handoff = StoredHandoff(result)
        case .handoffFailed(let reason, let preview):
            kind = .handoffFailed
            self.reason = reason.storedName
            text = preview
        case .commandFailed(let command, let reason, let retry):
            kind = .commandFailed
            self.command = command.storedName
            self.reason = reason.storedName
            text = retry
        case .handoffConfirm(let total):
            kind = .handoffConfirm
            self.total = total
        case .cancelled: kind = .cancelled
        case .welcome: kind = .welcome
        case .guide: kind = .guide
        case .about(let command):
            kind = .about
            self.command = command.storedName
        case .reconnected: kind = .reconnected
        case .dropConfirm(let total):
            kind = .dropConfirm
            self.total = total
        case .dropped(let refs):
            kind = .dropped
            self.refs = refs.map(StoredRef.init)
        case .revived(let refs):
            kind = .revived
            self.refs = refs.map(StoredRef.init)
        case .binList(let total, let entries, let hasMore):
            kind = .binList
            self.total = total
            self.trashEntries = entries
            self.hasMore = hasMore
        case .binEmptyConfirm(let total):
            kind = .binEmptyConfirm
            self.total = total
        case .binEmptied(let count):
            kind = .binEmptied
            self.count = count
        case .revised(let item):
            kind = .revised
            self.items = [item]
        case .tagsRemoved(let item, let tags):
            kind = .tagsRemoved
            self.items = [item]
            self.tags = tags
        case .samplesSaved(let firstNumber, let lastNumber, let items):
            kind = .samplesSaved
            self.firstNumber = firstNumber
            self.lastNumber = lastNumber
            self.items = items
        case .unpicked(let refs, let remaining):
            kind = .unpicked
            self.refs = refs.map(StoredRef.init)
            self.count = remaining
        case .pickCleared(let count):
            kind = .pickCleared
            self.count = count
        case .signOutEverywhereConfirm(let connectionCount):
            kind = .signOutEverywhereConfirm
            count = connectionCount
        case .bundleList(let bundles):
            kind = .bundleList
            self.bundles = bundles
        case .bundleAdded(let name, let count, let alreadyCount):
            kind = .bundleAdded
            self.name = name
            self.count = count
            extraCount = alreadyCount
        case .bundleView(let name, let total, let items, let hasMore):
            kind = .bundleView
            self.name = name
            self.total = total
            self.items = items
            self.hasMore = hasMore
        case .bundleNotFound(let name):
            kind = .bundleNotFound
            self.name = name
        case .bundleUnpicked(let name, let remaining):
            kind = .bundleUnpicked
            self.name = name
            count = remaining
        case .notInBundle(let name, let numbers):
            kind = .notInBundle
            self.name = name
            self.numbers = numbers
        case .bundleDeleteConfirm(let name, let itemCount):
            kind = .bundleDeleteConfirm
            self.name = name
            count = itemCount
        case .bundleDeleted(let name):
            kind = .bundleDeleted
            self.name = name
        case .bundleNameInvalid(let problem):
            kind = .bundleNameInvalid
            reason = problem.rawValue
        case .folderHint, .itemDetail, .oneNumberOnly,
             .searchSaved, .savedSearchList, .savedSearchPeriod, .savedSearchTooLong, .savedSearchDeleteConfirm,
             .savedSearchDeleted, .savedSearchNotFound, .connectionList, .disconnectConfirm, .disconnected,
             .connectionNotFound, .connectionEnded, .importPrompt, .importProgress, .importFinished:
            return nil
        }
    }

    /// 종류에 필요한 칸이 없으면 nil. 그 줄만 버린다.
    var line: TerminalViewState.Line? {
        let commandName = command.flatMap(CommandName.init(storedName:))
        let failure = reason.flatMap(CommandFailure.init(storedName:))
        switch kind {
        case .prompt: return text.map { .prompt($0) }
        case .unknownCommand: return text.map { .unknownCommand($0, suggestion: suggestion) }
        case .missingArgument: return commandName.map { .missingArgument($0) }
        case .missingTag: return .missingTag
        case .saved: return items?.first.map { .saved($0) }
        case .alreadySaved: return items?.first.map { .alreadySaved($0) }
        case .inTrash: return number.map { .inTrash(number: $0) }
        case .saveFailed:
            guard let failure = saveFailure?.failure, let recovery = recovery?.recovery else { return nil }
            return .saveFailed(failure, recovery)
        case .recentList:
            guard let items, let hasMore else { return nil }
            return .recentList(items: items, hasMore: hasMore, total: total, period: period)
        case .searchResult:
            guard let query, let total, let items, let hasMore else { return nil }
            return .searchResult(query: query.query, total: total, items: items, hasMore: hasMore, period: period)
        case .noResults:
            guard let query, let items else { return nil }
            return .noResults(query: query.query, recent: items, period: period)
        case .picked: return refs.map { .picked($0.map(\.ref)) }
        case .notFound: return numbers.map { .notFound(numbers: $0) }
        case .invalidNumber: return text.map { .invalidNumber($0) }
        case .handedOff: return handoff.map { .handedOff($0.result) }
        case .handoffFailed: return failure.map { .handoffFailed(reason: $0, preview: text) }
        case .commandFailed:
            guard let commandName, let failure, let text else { return nil }
            return .commandFailed(command: commandName, reason: failure, retry: text)
        case .handoffConfirm: return total.map { .handoffConfirm(total: $0) }
        case .cancelled: return .cancelled
        case .welcome: return .welcome
        case .guide: return .guide
        case .about: return commandName.map { .about($0) }
        case .reconnected: return .reconnected
        case .dropConfirm: return total.map { .dropConfirm(total: $0) }
        case .dropped: return refs.map { .dropped($0.map(\.ref)) }
        case .revived: return refs.map { .revived($0.map(\.ref)) }
        case .binList:
            guard let total, let trashEntries, let hasMore else { return nil }
            return .binList(total: total, items: trashEntries, hasMore: hasMore)
        case .binEmptyConfirm: return total.map { .binEmptyConfirm(total: $0) }
        case .binEmptied: return count.map { .binEmptied(count: $0) }
        case .revised: return items?.first.map { .revised($0) }
        case .tagsRemoved:
            guard let item = items?.first, let tags else { return nil }
            return .tagsRemoved(item: item, tags: tags)
        case .samplesSaved:
            guard let firstNumber, let lastNumber, let items else { return nil }
            return .samplesSaved(firstNumber: firstNumber, lastNumber: lastNumber, items: items)
        case .unpicked:
            guard let refs, let count else { return nil }
            return .unpicked(items: refs.map(\.ref), remaining: count)
        case .pickCleared: return count.map { .pickCleared(count: $0) }
        case .signOutEverywhereConfirm: return .signOutEverywhereConfirm(connectionCount: count)
        default: return bundleLine
        }
    }

    private var bundleLine: TerminalViewState.Line? {
        switch kind {
        case .bundleList: return bundles.map { .bundleList($0) }
        case .bundleAdded:
            guard let name, let count, let extraCount else { return nil }
            return .bundleAdded(name: name, count: count, alreadyCount: extraCount)
        case .bundleView:
            guard let name, let total, let items, let hasMore else { return nil }
            return .bundleView(name: name, total: total, items: items, hasMore: hasMore)
        case .bundleNotFound: return name.map { .bundleNotFound(name: $0) }
        case .bundleUnpicked:
            guard let name, let count else { return nil }
            return .bundleUnpicked(name: name, remaining: count)
        case .notInBundle:
            guard let name, let numbers else { return nil }
            return .notInBundle(name: name, numbers: numbers)
        case .bundleDeleteConfirm:
            guard let name, let count else { return nil }
            return .bundleDeleteConfirm(name: name, itemCount: count)
        case .bundleDeleted: return name.map { .bundleDeleted(name: $0) }
        case .bundleNameInvalid: return reason.flatMap(BundleNameProblem.init(rawValue:)).map { .bundleNameInvalid($0) }
        default: return nil
        }
    }
}

extension CommandName {
    fileprivate var storedName: String {
        switch self {
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

    fileprivate init?(storedName: String) {
        guard let command = Self.allCases.first(where: { $0.storedName == storedName }) else { return nil }
        self = command
    }
}

extension CommandFailure {
    private static let all: [CommandFailure] = [.disconnected, .timedOut, .serverError, .clipboardDenied]

    fileprivate var storedName: String {
        switch self {
        case .disconnected: "disconnected"
        case .timedOut: "timedOut"
        case .serverError: "serverError"
        case .clipboardDenied: "clipboardDenied"
        }
    }

    fileprivate init?(storedName: String) {
        guard let failure = Self.all.first(where: { $0.storedName == storedName }) else { return nil }
        self = failure
    }
}
