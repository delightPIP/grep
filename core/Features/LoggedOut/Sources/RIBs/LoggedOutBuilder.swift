import FeatureLoggedOutInterface
import GrepCore
import RIBs

public final class LoggedOutBuilder: Builder<any LoggedOutDependency>, LoggedOutBuildable {
    private let viewFactory: any LoggedOutViewFactory

    public init(dependency: any LoggedOutDependency, viewFactory: any LoggedOutViewFactory) {
        self.viewFactory = viewFactory
        super.init(dependency: dependency)
    }

    public func build(listener: any LoggedOutListener, notice: LoggedOutViewState.Notice?) -> any ViewableRouting {
        let view = viewFactory.makeLoggedOutView()
        let interactor = LoggedOutInteractor(
            presenter: view,
            authService: dependency.authService,
            listener: listener,
            notice: notice
        )
        return LoggedOutRouter(interactor: interactor, viewController: view)
    }
}
