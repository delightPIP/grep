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
}
