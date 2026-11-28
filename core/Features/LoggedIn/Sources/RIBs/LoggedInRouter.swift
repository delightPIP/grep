import FeatureLoggedInInterface
import GrepCore
import RIBs

/// 컨테이너의 화면은 자식 터미널의 화면이다. 보관함·설정 탭은 자식으로 붙이고, 화면을 어디에 둘지는 플랫폼이 정한다.
final class LoggedInRouter: ViewableRouter<LoggedInInteractor, any ViewControllable> {
    private let terminal: any ViewableRouting
    private let tabs: [any ViewableRouting]

    init(interactor: LoggedInInteractor, terminal: any ViewableRouting, tabs: [any ViewableRouting]) {
        self.terminal = terminal
        self.tabs = tabs
        super.init(interactor: interactor, viewController: terminal.viewControllable)
    }

    override func didLoad() {
        attachChild(terminal)
        tabs.forEach(attachChild)
    }
}
