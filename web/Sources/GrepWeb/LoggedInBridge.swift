import JavaScriptKit

/// 출력 한 줄. `LoggedInViewState.Line`은 다른 패키지에 있어 `@JS`를 붙일 수 없으므로 경계용 값 타입을 따로 둔다.
/// `kind`는 `web/support/view-state.ts`의 `TerminalLine.kind`와 같다. `text`는 `prompt`의 친 줄, `unknownCommand`의 명령 이름이다.
@JS struct TerminalLineRow {
    let kind: String
    let text: String
}

/// 웹 뷰가 구현한다. `features/logged-in/adapter.tsx`가 구현한다.
@JS protocol LoggedInViewBridge {
    func mount(host: JSObject, handle: LoggedInScreenHandle)
    func render(itemCount: Int?, lines: [TerminalLineRow], input: String)
}

@JS final class LoggedInScreenHandle: Sendable {
    private let onInputChanged: @MainActor @Sendable (String) -> Void
    private let onSubmitted: @MainActor @Sendable (String) -> Void

    init(
        onInputChanged: @escaping @MainActor @Sendable (String) -> Void,
        onSubmitted: @escaping @MainActor @Sendable (String) -> Void
    ) {
        self.onInputChanged = onInputChanged
        self.onSubmitted = onSubmitted
    }

    @JS func inputChanged(text: String) {
        MainActor.assumeIsolated { onInputChanged(text) }
    }

    @JS func submitted(text: String) {
        MainActor.assumeIsolated { onSubmitted(text) }
    }
}
