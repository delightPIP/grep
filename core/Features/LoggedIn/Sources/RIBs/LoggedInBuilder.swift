import FeatureArchiveInterface
import FeatureLoggedInInterface
import FeatureSettingsInterface
import FeatureTerminalInterface
import GrepCore
import RIBs

public final class LoggedInBuilder: Builder<any LoggedInDependency>, LoggedInBuildable {
    private let terminalBuilder: any TerminalBuildable
    private let archiveBuilder: (any ArchiveBuildable)?
    private let settingsBuilder: (any SettingsBuildable)?

    /// 보관함·설정을 붙이지 않는 조립(터미널만 보는 테스트·데모)은 둘을 빼고 만든다.
    public init(
        dependency: any LoggedInDependency,
        terminalBuilder: any TerminalBuildable,
        archiveBuilder: (any ArchiveBuildable)? = nil,
        settingsBuilder: (any SettingsBuildable)? = nil
    ) {
        self.terminalBuilder = terminalBuilder
        self.archiveBuilder = archiveBuilder
        self.settingsBuilder = settingsBuilder
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
        let archive = archiveBuilder?.build(listener: interactor)
        let settings = settingsBuilder?.build(listener: interactor)
        interactor.terminal = terminal.handle
        interactor.archive = archive?.handle
        interactor.settings = settings?.handle
        return LoggedInRouter(
            interactor: interactor,
            terminal: terminal.router,
            tabs: [archive?.router, settings?.router].compactMap { $0 }
        )
    }
}
