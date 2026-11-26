import JavaScriptKit
import RIBs
import RIBsWeb

/// DOM 요소 하나로 그려지는 RIB 뷰. 부모 화면은 공유 코드가 넘긴 `any ViewControllable`을 이 타입으로 바꿔 붙인다.
@MainActor
public protocol DOMScreen: ViewControllable {
    var element: JSObject { get }
}

/// 화면 자리(빈 요소)를 만든다. 안쪽은 JS 뷰가 그린다.
@MainActor
public enum DOMBuilder {
    public static func element(_ tag: String, id: String) -> JSObject {
        let node = JSObject.global.document.object!.createElement!(tag).object!
        node.id = .string(id)
        return node
    }
}

/// `WebScreenSlot`을 구독해 지금 화면의 요소만 `container` 안에 둔다.
@MainActor
public final class SlotRenderer {
    private var subscription: WebSlotSubscription?

    public init(slot: WebScreenSlot, container: JSObject) {
        subscription = slot.observe { screen in
            _ = container.replaceChildren!()
            guard let screen else { return }
            guard let domScreen = screen as? any DOMScreen else {
                preconditionFailure("\(type(of: screen)) should conform to \((any DOMScreen).self)")
            }
            _ = container.appendChild!(domScreen.element)
        }
    }

    public func stop() {
        subscription?.cancel()
        subscription = nil
    }
}
