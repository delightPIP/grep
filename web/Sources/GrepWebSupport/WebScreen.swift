import JavaScriptKit

/// 화면 자리(`element`)와 지금 상태를 든 화면의 기반. 피처별 웹 화면이 상속한다.
/// 안쪽을 누가 그리는지는 모른다. 조립 쪽이 `attach`로 그리는 쪽(JS 뷰)을 붙인다.
@MainActor
open class WebScreen<State>: DOMScreen {
    public let element: JSObject
    private var viewState: State
    private var onRender: ((State) -> Void)?

    public init(tag: String, id: String, initialState: State) {
        element = DOMBuilder.element(tag, id: id)
        viewState = initialState
    }

    /// 그리는 쪽을 붙인다. 붙는 즉시 현재 상태를 한 번 그리게 한다.
    public final func attach(onRender: @escaping (State) -> Void) {
        self.onRender = onRender
        onRender(viewState)
    }

    public final func setViewState(_ state: State) {
        viewState = state
        onRender?(state)
    }
}
