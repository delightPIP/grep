#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FeatureTerminalInterface
import TerminalDomain
import GrepCore
import RIBs

public final class TerminalBuilder: Builder<any TerminalDependency>, TerminalBuildable {
    private let viewFactory: any TerminalViewFactory

    public init(dependency: any TerminalDependency, viewFactory: any TerminalViewFactory) {
        self.viewFactory = viewFactory
        super.init(dependency: dependency)
    }

    public func build(listener: any TerminalListener) -> TerminalBuild {
        let view = viewFactory.makeTerminalView()
        let interactor = TerminalInteractor(
            presenter: view,
            authService: dependency.authService,
            httpTransport: dependency.httpTransport,
            clipboard: dependency.clipboard,
            files: dependency.files,
            historyStore: dependency.historyStore,
            sleeper: dependency.sleeper,
            listener: listener
        )
        return TerminalBuild(router: TerminalRouter(interactor: interactor, viewController: view), handle: interactor)
    }
}
