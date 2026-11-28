import FeatureTerminalInterface
import GrepCore
import JavaScriptKit

/// 끌어다 놓은 파일 하나. `web/support/view-state.ts`의 `DroppedFile`과 같다.
/// `DroppedFile`은 다른 패키지에 있어 `@JS`를 붙일 수 없으므로 경계용 값 타입을 따로 둔다.
@JS struct DroppedFileRow {
    let id: String
    let name: String
    let size: Int
}

/// 웹 뷰가 구현한다. `features/logged-in/adapter.tsx`가 구현한다.
@JS protocol LoggedInViewBridge {
    func mount(host: JSObject, handle: LoggedInScreenHandle)
    /// `state`는 `web/support/view-state.ts`의 `LoggedInState`와 같은 모양의 객체다(`TerminalStateValue.swift`).
    func render(state: JSObject)
}

/// 웹 뷰가 `mount`에서 받아 쥐고 입력을 보낸다. 메서드는 `TerminalViewAction`의 case와 하나씩 짝이다.
@JS final class LoggedInScreenHandle: Sendable {
    private let send: @MainActor @Sendable (TerminalViewAction) -> Void

    init(send: @escaping @MainActor @Sendable (TerminalViewAction) -> Void) {
        self.send = send
    }

    @JS func inputChanged(text: String) {
        MainActor.assumeIsolated { send(.inputChanged(text)) }
    }

    @JS func submitted(text: String) {
        MainActor.assumeIsolated { send(.submitted(text)) }
    }

    @JS func pasted(text: String) {
        MainActor.assumeIsolated { send(.pasted(text)) }
    }

    @JS func filesDropped(files: [DroppedFileRow]) {
        let dropped = files.map { DroppedFile(id: $0.id, name: $0.name, size: $0.size) }
        MainActor.assumeIsolated { send(.filesDropped(dropped)) }
    }

    @JS func moreRequested() {
        MainActor.assumeIsolated { send(.moreRequested) }
    }

    @JS func samplesRequested() {
        MainActor.assumeIsolated { send(.samplesRequested) }
    }

    @JS func reviseSubmitted(number: Int, title: String, summary: String) {
        MainActor.assumeIsolated { send(.reviseSubmitted(number: number, title: title, summary: summary)) }
    }

    @JS func reviseCancelled() {
        MainActor.assumeIsolated { send(.reviseCancelled) }
    }

    @JS func archiveOpen() {
        MainActor.assumeIsolated { send(.archiveOpen) }
    }

    /// `kind`는 `ArchiveFilter`의 kind. `group`은 auto일 때만, `value`는 auto의 값·묶음 이름·찾아둔 검색어.
    /// 계약에 없는 값이면 무시한다.
    @JS func archiveSelect(kind: String, group: String?, value: String?) {
        guard let filter = ArchiveFilter(bridgeKind: kind, group: group, value: value) else { return }
        MainActor.assumeIsolated { send(.archiveSelect(filter)) }
    }

    @JS func archiveMore() {
        MainActor.assumeIsolated { send(.archiveMore) }
    }

    @JS func settingsOpen() {
        MainActor.assumeIsolated { send(.settingsOpen) }
    }
}

extension ArchiveFilter {
    init?(bridgeKind kind: String, group: String?, value: String?) {
        switch (kind, group.flatMap(AutoGroup.init(rawValue:)), value) {
        case ("all", _, _): self = .all
        case ("auto", let group?, let value?): self = .auto(group: group, value: value)
        case ("bundle", _, let name?): self = .bundle(name: name)
        case ("savedSearch", _, let query?): self = .savedSearch(query: query)
        default: return nil
        }
    }
}
