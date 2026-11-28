import FeatureSettingsInterface
import GrepCore
import RIBs

public final class SettingsBuilder: Builder<any SettingsDependency>, SettingsBuildable {
    private let viewFactory: any SettingsViewFactory

    public init(dependency: any SettingsDependency, viewFactory: any SettingsViewFactory) {
        self.viewFactory = viewFactory
        super.init(dependency: dependency)
    }

    public func build(listener: any SettingsListener) -> SettingsBuild {
        let view = viewFactory.makeSettingsView()
        let interactor = SettingsInteractor(
            presenter: view,
            authService: dependency.authService,
            httpTransport: dependency.httpTransport,
            listener: listener
        )
        return SettingsBuild(router: SettingsRouter(interactor: interactor, viewController: view), handle: interactor)
    }
}
