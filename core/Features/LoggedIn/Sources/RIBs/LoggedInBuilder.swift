import FeatureLoggedInInterface
import FeatureTerminalInterface
import GrepCore
import RIBs

public final class LoggedInBuilder: Builder<any LoggedInDependency>, LoggedInBuildable {
    private let terminalBuilder: any TerminalBuildable

    public init(dependency: any LoggedInDependency, terminalBuilder: any TerminalBuildable) {
        self.terminalBuilder = terminalBuilder
        super.init(dependency: dependency)
    }

    public func build(listener: any LoggedInListener, pendingInput: PendingInput?) -> any ViewableRouting {
        let interactor = LoggedInInteractor(
            authService: dependency.authService,
            httpTransport: dependency.httpTransport,
            listener: listener,
            pendingInput: pendingInput
        )
        let terminal = terminalBuilder.build(listener: interactor)
        interactor.terminal = terminal.handle
        return LoggedInRouter(interactor: interactor, terminal: terminal.router)
    }
}
