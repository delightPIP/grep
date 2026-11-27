import JavaScriptKit
import RIBs
import RIBsWeb

/// 루트 화면. 자식 RIB 화면 하나를 담는다. 그릴 것이 없어 JS 뷰를 두지 않는다.
@MainActor
public final class RootScreen: DOMScreen {
    public let element: JSObject
    private let slot = WebScreenSlot()
    private let renderer: SlotRenderer

    public init() {
        element = DOMBuilder.element("div", id: "root")
        renderer = SlotRenderer(slot: slot, container: element)
    }

    public func showScreen(_ screen: any ViewControllable) { slot.show(screen) }
    public func hideScreen(_ screen: any ViewControllable) { slot.hide(screen) }
}
