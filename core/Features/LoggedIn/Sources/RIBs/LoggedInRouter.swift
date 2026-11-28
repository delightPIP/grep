import FeatureLoggedInInterface
import FeatureTerminalInterface
import GrepCore
import RIBs

/// 컨테이너의 화면은 자식 터미널의 화면이다. 탭처럼 컨테이너가 자기 화면을 가지는 플랫폼은 그 이슈에서 뷰 계약을 더한다.
final class LoggedInRouter: ViewableRouter<LoggedInInteractor, any ViewControllable> {
    private let terminal: any ViewableRouting

    init(interactor: LoggedInInteractor, terminal: any ViewableRouting) {
        self.terminal = terminal
        super.init(interactor: interactor, viewController: terminal.viewControllable)
    }

    override func didLoad() {
        attachChild(terminal)
    }
}
