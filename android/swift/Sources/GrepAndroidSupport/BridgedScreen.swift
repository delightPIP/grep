import RIBs
import RIBsAndroid

/// 상태를 타입 있는 통로(swift-java 핸들)로 내보내는 화면의 기반.
/// 화면 트리에는 `kind`와 `id`(자식이 있으면 `child`)만 싣고, 상태는 `attach`로 붙은 플랫폼 뷰에 직접 넘긴다.
@MainActor
open class BridgedScreen<State>: AndroidScreen {
    private var viewState: State
    private var onRender: ((State) -> Void)?

    public init(kind: String, context: ScreenContext, initialState: State) {
        viewState = initialState
        super.init(kind: kind, renderer: context.renderer)
        context.registry.track(self)
    }

    /// 플랫폼 뷰를 붙인다. 붙는 즉시 현재 상태를 한 번 그리게 한다.
    public final func attach(onRender: @escaping (State) -> Void) {
        self.onRender = onRender
        onRender(viewState)
    }

    public final func detach() {
        onRender = nil
    }

    public final var currentState: State { viewState }

    public final func setViewState(_ state: State) {
        viewState = state
        onRender?(state)
    }
}

/// 화면이 태어날 때 필요한 렌더러와 등록부. 피처별 뷰 팩토리가 받아 화면에 넘긴다.
@MainActor
public struct ScreenContext {
    public let renderer: AndroidRenderer
    public let registry: ScreenRegistry

    public init(renderer: AndroidRenderer, registry: ScreenRegistry) {
        self.renderer = renderer
        self.registry = registry
    }
}

/// 살아 있는 화면을 화면 트리의 `id`로 찾는다. Kotlin 핸들이 이 id로 화면에 붙는다. 화면은 약하게 쥔다.
@MainActor
public final class ScreenRegistry {
    private var screens: [WeakScreen] = []

    public init() {}

    func track(_ screen: AndroidScreen) {
        screens = screens.filter { $0.screen != nil } + [WeakScreen(screen: screen)]
    }

    /// 다른 종류의 화면이거나 이미 내려갔으면 nil.
    public func screen<Screen: AndroidScreen>(id: Int64, as type: Screen.Type) -> Screen? {
        screens.lazy.compactMap(\.screen).first { $0.id == id } as? Screen
    }
}

private struct WeakScreen {
    weak var screen: AndroidScreen?
}
