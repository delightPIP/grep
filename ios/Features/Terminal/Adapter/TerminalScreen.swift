import FeatureTerminalInterface
import FeatureTerminalUI
import GrepCore
import Observation
import RIBs
import RIBsSwiftUI
import SwiftUI

/// 터미널 피처의 어댑터를 만든다(ADR-0015).
@MainActor
public final class TerminalScreenFactory: TerminalViewFactory {
    private let wrapContent: (@MainActor (AnyView, Binding<Bool>) -> AnyView)?

    public init(wrapContent: (@MainActor (AnyView, Binding<Bool>) -> AnyView)? = nil) {
        self.wrapContent = wrapContent
    }

    public func makeTerminalView() -> any TerminalViewContract {
        TerminalScreen(wrapContent: wrapContent)
    }
}

/// 코어 `TerminalViewContract`를 구현하고 상태를 풀어 순수 뷰(`FeatureTerminalUI`)에 넘긴다.
@MainActor
final class TerminalScreen: TerminalViewContract, SwiftUIRenderable {
    weak var listener: (any TerminalPresentableListener)?
    private let model = TerminalModel()
    private let wrapContent: (@MainActor (AnyView, Binding<Bool>) -> AnyView)?

    init(wrapContent: (@MainActor (AnyView, Binding<Bool>) -> AnyView)? = nil) {
        self.wrapContent = wrapContent
    }

    func render(_ state: TerminalViewState) {
        model.presentation = TerminalStateMapper.map(state)
    }

    func makeView() -> AnyView {
        AnyView(
            TerminalContent(
                model: model,
                wrapContent: wrapContent
            ) { [weak self] action in
                self?.listener?.handle(action)
            }
        )
    }
}

@MainActor @Observable
final class TerminalModel {
    var presentation = TerminalPresentation()
}

private struct TerminalContent: View {
    let model: TerminalModel
    let wrapContent: (@MainActor (AnyView, Binding<Bool>) -> AnyView)?
    let send: (TerminalViewAction) -> Void
    @State private var isKeyboardVisible = false

    var body: some View {
        let terminalView = AnyView(
            TerminalView(
                presentation: model.presentation,
                onInputChange: { send(.inputChanged($0)) },
                onSubmit: { send(.submitted($0)) },
                onPaste: { send(.pasted($0)) },
                onMoreRequested: { send(.moreRequested) },
                onKeyboardVisibilityChange: { isKeyboardVisible = $0 }
            )
        )
        if let wrapContent {
            wrapContent(terminalView, $isKeyboardVisible)
        } else {
            terminalView
        }
    }
}
