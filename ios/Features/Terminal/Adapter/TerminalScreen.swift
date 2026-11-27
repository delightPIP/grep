import FeatureTerminalInterface
import FeatureTerminalUI
import GrepCore
import Observation
import RIBs
import RIBsSwiftUI
import SwiftUI

/// 터미널을 감싸는 호스트(하단 탭 컨테이너)와 주고받는 최소 컨텍스트.
@MainActor
public struct TerminalHostContext {
    public let isKeyboardVisible: Binding<Bool>
    public let scrollToBottomTrigger: Binding<Int>
    public let itemCount: Int?
    public let pickedNumbers: Set<Int>
    public let sendCommand: @MainActor (String) -> Void

    public init(
        isKeyboardVisible: Binding<Bool>,
        scrollToBottomTrigger: Binding<Int>,
        itemCount: Int?,
        pickedNumbers: Set<Int>,
        sendCommand: @escaping @MainActor (String) -> Void
    ) {
        self.isKeyboardVisible = isKeyboardVisible
        self.scrollToBottomTrigger = scrollToBottomTrigger
        self.itemCount = itemCount
        self.pickedNumbers = pickedNumbers
        self.sendCommand = sendCommand
    }
}

/// 터미널 피처의 어댑터를 만든다(ADR-0015).
@MainActor
public final class TerminalScreenFactory: TerminalViewFactory {
    private let wrapContent: (@MainActor (AnyView, TerminalHostContext) -> AnyView)?

    public init(wrapContent: (@MainActor (AnyView, TerminalHostContext) -> AnyView)? = nil) {
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
    private let wrapContent: (@MainActor (AnyView, TerminalHostContext) -> AnyView)?

    init(wrapContent: (@MainActor (AnyView, TerminalHostContext) -> AnyView)? = nil) {
        self.wrapContent = wrapContent
    }

    func render(_ state: TerminalViewState) {
        model.presentation = TerminalStateMapper.map(state)
        model.itemCount = state.itemCount
        model.pickedNumbers = Set(state.selection.map(\.number))
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
    var itemCount: Int?
    var pickedNumbers: Set<Int> = []
}

private struct TerminalContent: View {
    let model: TerminalModel
    let wrapContent: (@MainActor (AnyView, TerminalHostContext) -> AnyView)?
    let send: (TerminalViewAction) -> Void
    @State private var isKeyboardVisible = false
    @State private var scrollToBottomTrigger = 0

    var body: some View {
        let terminalView = AnyView(
            TerminalView(
                presentation: model.presentation,
                scrollToBottomTrigger: scrollToBottomTrigger,
                onInputChange: { send(.inputChanged($0)) },
                onSubmit: { send(.submitted($0)) },
                onPaste: { send(.pasted($0)) },
                onMoreRequested: { send(.moreRequested) },
                onReviseSubmit: { number, title, summary in
                    send(.reviseSubmitted(number: number, title: title, summary: summary))
                },
                onReviseCancel: { send(.reviseCancelled) },
                onKeyboardVisibilityChange: { isKeyboardVisible = $0 }
            )
        )
        if let wrapContent {
            let context = TerminalHostContext(
                isKeyboardVisible: $isKeyboardVisible,
                scrollToBottomTrigger: $scrollToBottomTrigger,
                itemCount: model.itemCount,
                pickedNumbers: model.pickedNumbers,
                sendCommand: { command in
                    send(.submitted(command))
                }
            )
            wrapContent(terminalView, context)
        } else {
            terminalView
        }
    }
}
