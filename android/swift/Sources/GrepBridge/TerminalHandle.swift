import FeatureTerminalAndroid
import FeatureTerminalInterface

/// Kotlin 어댑터가 구현한다(`:feature:terminal:adapter`).
public protocol TerminalViewBridge {
    /// `TerminalStateEncoder`가 직렬화한 UTF-8 JSON 문자열을 받는다.
    func render(stateJson: String)
}

/// Kotlin 터미널 뷰가 화면 트리의 `id`로 만들어 쥔다.
public final class TerminalScreenHandle: Sendable {
    private let screenID: Int64

    public init(screenID: Int64) {
        self.screenID = screenID
    }

    public func attach(view: any TerminalViewBridge) {
        nonisolated(unsafe) let view = view
        MainActor.assumeIsolated {
            screen?.attach { state in
                view.render(stateJson: TerminalStateEncoder.encode(state))
            }
        }
    }

    public func detach() {
        MainActor.assumeIsolated { screen?.detach() }
    }

    public func inputChanged(text: String) {
        MainActor.assumeIsolated { screen?.send(.inputChanged(text)) }
    }

    public func submitCommand(text: String) {
        MainActor.assumeIsolated { screen?.send(.submitted(text)) }
    }

    public func pasteText(text: String) {
        MainActor.assumeIsolated { screen?.send(.pasted(text)) }
    }

    public func requestMore() {
        MainActor.assumeIsolated { screen?.send(.moreRequested) }
    }

    @MainActor private var screen: TerminalAndroidScreen? {
        controller?.screen(id: screenID, as: TerminalAndroidScreen.self)
    }
}
