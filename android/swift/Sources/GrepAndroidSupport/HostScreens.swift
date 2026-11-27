import RIBs
import RIBsAndroid

/// 조립 쪽 화면 종류. Kotlin `:bridge` 모듈의 `HostKind`와 같은 문자열이다.
public enum HostScreenKind {
    public static let root = "root"
    public static let placeholder = "placeholder"
}

/// 자식 화면 하나를 화면 트리의 `child`로 내보낸다. 단독 실행 앱에서는 부모 대신 받은 이벤트를 `event`로 함께 싣는다.
@MainActor
public final class HostRootScreen: AndroidScreen {
    private lazy var slot = AndroidScreenSlot(owner: self)
    private var event: String?

    public init(context: ScreenContext) {
        super.init(kind: HostScreenKind.root, renderer: context.renderer)
        context.registry.track(self)
    }

    public func showScreen(_ screen: any ViewControllable) { slot.show(screen) }
    public func hideScreen(_ screen: any ViewControllable) { slot.hide(screen) }

    /// 단독 실행 앱이 부모 대신 받은 이벤트를 보여 줄 때 쓴다.
    public func showEvent(_ event: String) {
        self.event = event
        setNeedsRender()
    }

    override public func state() -> [String: RibValue] {
        var values: [String: RibValue] = ["child": slot.renderedValue]
        if let event { values["event"] = .string(event) }
        return values
    }
}

public struct PlaceholderState: Equatable, Sendable {
    public let title: String
    public let actionTitle: String
}

/// 단독 실행 앱에서 자식 피처 대신 붙이는 화면. 제목과 버튼 하나만 있다.
@MainActor
public final class PlaceholderScreen: BridgedScreen<PlaceholderState> {
    private let action: () -> Void

    public init(context: ScreenContext, title: String, actionTitle: String, action: @escaping () -> Void) {
        self.action = action
        super.init(
            kind: HostScreenKind.placeholder,
            context: context,
            initialState: PlaceholderState(title: title, actionTitle: actionTitle)
        )
    }

    public func tapAction() { action() }
}
