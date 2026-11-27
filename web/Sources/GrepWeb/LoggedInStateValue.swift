import FeatureLoggedInInterface
import GrepCore
import JavaScriptKit

// `LoggedInViewState`를 `web/support/view-state.ts`의 `LoggedInState`와 같은 모양의 JS 객체로 만든다.
// 값이 든 줄(자료·검색 조건·넘기기 결과)은 평평한 인자로 나를 수 없어 객체째 넘긴다.
// 필드 이름과 문자열 값의 원본은 view-state.ts다. 받는 쪽 짝은 `web/support/bridge-state.ts`.

private typealias Fields = [String: any ConvertibleToJSValue]

private func object(_ fields: Fields) -> JSValue { fields.jsValue }

private func line(_ kind: String, _ fields: Fields = [:]) -> JSValue {
    object(fields.merging(["kind": kind]) { _, kind in kind })
}

extension LoggedInViewState {
    var bridgeValue: JSObject {
        let state = object([
            "itemCount": itemCount,
            "lines": lines.map(\.bridgeValue),
            "input": input,
            "selection": selection.map(\.bridgeValue),
            "processingCount": processingCount,
            "isOffline": isOffline,
        ])
        guard let object = state.object else { preconditionFailure("state should convert to a JS object") }
        return object
    }
}

extension LoggedInViewState.Line {
    var bridgeValue: JSValue {
        switch self {
        case .prompt(let text): line("prompt", ["text": text])
        case .unknownCommand(let name): line("unknownCommand", ["name": name])
        case .missingArgument(let command): line("missingArgument", ["command": command.bridgeName])
        case .missingTag: line("missingTag")
        case .saved(let item): line("saved", ["item": item.bridgeValue])
        case .alreadySaved(let item): line("alreadySaved", ["item": item.bridgeValue])
        case .inTrash(let number): line("inTrash", ["number": number])
        case .saveFailed(let reason, let recovery):
            line("saveFailed", ["reason": reason.bridgeValue, "recovery": recovery.bridgeValue])
        case .recentList(let items, let hasMore):
            line("recentList", ["items": items.map(\.bridgeValue), "hasMore": hasMore])
        case .searchResult(let query, let total, let items, let hasMore):
            line(
                "searchResult",
                ["query": query.bridgeValue, "total": total, "items": items.map(\.bridgeValue), "hasMore": hasMore]
            )
        case .noResults(let query, let recent):
            line("noResults", ["query": query.bridgeValue, "recent": recent.map(\.bridgeValue)])
        case .picked(let items): line("picked", ["items": items.map(\.bridgeValue)])
        case .notFound(let numbers): line("notFound", ["numbers": numbers])
        case .invalidNumber(let input): line("invalidNumber", ["input": input])
        case .handedOff(let result): line("handedOff", ["result": result.bridgeValue])
        case .handoffFailed(let reason, let preview):
            line("handoffFailed", ["reason": reason.bridgeName, "preview": preview])
        case .commandFailed(let command, let reason, let retry):
            line("commandFailed", ["command": command.bridgeName, "reason": reason.bridgeName, "retry": retry])
        case .handoffConfirm(let total): line("handoffConfirm", ["total": total])
        case .cancelled: line("cancelled")
        case .welcome: line("welcome")
        case .guide: line("guide")
        case .about(let command): line("about", ["command": command.bridgeName])
        case .reconnected: line("reconnected")
        }
    }
}

extension ItemSummary {
    fileprivate var bridgeValue: JSValue {
        object([
            "number": number,
            "kind": kind.rawValue,
            "title": title,
            "source": source,
            "status": status.rawValue,
            "blockedReason": blockedReason?.bridgeName,
            "listSummary": listSummary,
            "summarySource": summarySource?.rawValue,
            "partialNote": partialNote,
            "tags": tags,
            "matchedIn": matchedIn?.rawValue,
            "savedAt": savedAt,
        ])
    }
}

extension ItemRef {
    fileprivate var bridgeValue: JSValue { object(["number": number, "title": title]) }
}

extension SearchQuery {
    fileprivate var bridgeValue: JSValue { object(["text": text, "words": words, "tags": tags]) }
}

extension HandoffResult {
    fileprivate var bridgeValue: JSValue {
        object([
            "items": items.map(\.bridgeValue),
            "charCount": charCount,
            "missingSummaryCount": missingSummaryCount,
            "text": text,
        ])
    }
}

extension SaveRecovery {
    fileprivate var bridgeValue: JSValue {
        switch self {
        case .inputKept: object(["kind": "inputKept"])
        case .retry(let command): object(["kind": "retry", "command": command])
        case .file(let name): object(["kind": "file", "name": name])
        }
    }
}

extension SaveFailure {
    fileprivate var bridgeValue: JSValue {
        switch self {
        case .disconnected: object(["kind": "disconnected"])
        case .timedOut: object(["kind": "timedOut"])
        case .serverError: object(["kind": "serverError"])
        case .unsupportedFormat(let fileExtension):
            object(["kind": "unsupportedFormat", "fileExtension": fileExtension])
        case .tooLarge(let fileName, let bytes):
            object(["kind": "tooLarge", "fileName": fileName, "bytes": bytes])
        }
    }
}
