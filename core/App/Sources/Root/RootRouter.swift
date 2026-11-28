import FeatureLoggedIn
import FeatureLoggedInInterface
import FeatureLoggedOut
import FeatureLoggedOutInterface
import FeatureTerminal
import FeatureTerminalInterface
import GrepCore
import RIBs

final class RootRouter<RootView: RootViewControllable>: LaunchRouter<RootInteractor, RootView>, RootRouting {
    private let loggedOutBuilder: any LoggedOutBuildable
    private let loggedInBuilder: any LoggedInBuildable
    private var loggedOut: (any ViewableRouting)?
    private var loggedIn: (any ViewableRouting)?

    init(
        interactor: RootInteractor,
        viewController: RootView,
        loggedOutBuilder: any LoggedOutBuildable,
        loggedInBuilder: any LoggedInBuildable
    ) {
        self.loggedOutBuilder = loggedOutBuilder
        self.loggedInBuilder = loggedInBuilder
        super.init(interactor: interactor, viewController: viewController)
        interactor.router = self
    }

    func routeToLoggedOut(notice: LoggedOutViewState.Notice?) {
        guard loggedOut == nil else { return }
        let child = loggedOutBuilder.build(listener: interactor, notice: notice)
        attachChild(child)
        viewController.showScreen(child.viewControllable)
        loggedOut = child
    }

    func routeAwayFromLoggedOut() {
        guard let child = loggedOut else { return }
        detachChild(child)
        viewController.hideScreen(child.viewControllable)
        loggedOut = nil
    }

    func routeToLoggedIn(pendingInput: PendingInput?) {
        guard loggedIn == nil else { return }
        let child = loggedInBuilder.build(listener: interactor, pendingInput: pendingInput)
        attachChild(child)
        viewController.showScreen(child.viewControllable)
        loggedIn = child
    }

    func routeAwayFromLoggedIn() {
        guard let child = loggedIn else { return }
        detachChild(child)
        viewController.hideScreen(child.viewControllable)
        loggedIn = nil
    }
}
