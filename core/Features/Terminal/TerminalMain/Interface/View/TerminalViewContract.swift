import GrepCore
import RIBs
import TerminalDomain

@MainActor
public protocol TerminalPresentableListener: AnyObject {
    func handle(_ action: TerminalViewAction)
}

@MainActor
public protocol TerminalPresentable: Presentable {
    var listener: (any TerminalPresentableListener)? { get set }
    func render(_ state: TerminalViewState)
}

@MainActor
public protocol TerminalViewControllable: ViewControllable {}

@MainActor
public protocol TerminalViewContract: TerminalPresentable, TerminalViewControllable {}

@MainActor
public protocol TerminalViewFactory: AnyObject {
    func makeTerminalView() -> any TerminalViewContract
}
