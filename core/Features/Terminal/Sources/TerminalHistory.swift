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
        json(of: kept(lines).map(StoredLine.init))
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
    let charCount: Int
    let missingSummaryCount: Int
    let text: String

    init(_ result: HandoffResult) {
        items = result.items.map(StoredRef.init)
        charCount = result.charCount
        missingSummaryCount = result.missingSummaryCount
        text = result.text
    }

    var result: HandoffResult {
        HandoffResult(
            items: items.map(\.ref), charCount: charCount, missingSummaryCount: missingSummaryCount, text: text
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
    }

    let kind: Kind
    var text: String?
    var command: String?
    var reason: String?
    var number: Int?
    var numbers: [Int]?
    var total: Int?
    var hasMore: Bool?
    var items: [ItemSummary]?
    var refs: [StoredRef]?
    var query: StoredQuery?
    var handoff: StoredHandoff?
    var saveFailure: StoredSaveFailure?
    var recovery: StoredRecovery?

    init(_ line: TerminalViewState.Line) {
        switch line {
        case .prompt(let text):
            kind = .prompt
            self.text = text
        case .unknownCommand(let name):
            kind = .unknownCommand
            text = name
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
        case .recentList(let items, let hasMore):
            kind = .recentList
            self.items = items
            self.hasMore = hasMore
        case .searchResult(let query, let total, let items, let hasMore):
            kind = .searchResult
            self.query = StoredQuery(query)
            self.total = total
            self.items = items
            self.hasMore = hasMore
        case .noResults(let query, let recent):
            kind = .noResults
            self.query = StoredQuery(query)
            items = recent
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
        }
    }

    /// 종류에 필요한 칸이 없으면 nil. 그 줄만 버린다.
    var line: TerminalViewState.Line? {
        let commandName = command.flatMap(CommandName.init(storedName:))
        let failure = reason.flatMap(CommandFailure.init(storedName:))
        switch kind {
        case .prompt: return text.map { .prompt($0) }
        case .unknownCommand: return text.map { .unknownCommand($0) }
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
            return .recentList(items: items, hasMore: hasMore)
        case .searchResult:
            guard let query, let total, let items, let hasMore else { return nil }
            return .searchResult(query: query.query, total: total, items: items, hasMore: hasMore)
        case .noResults:
            guard let query, let items else { return nil }
            return .noResults(query: query.query, recent: items)
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
