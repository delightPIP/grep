import FeatureArchiveInterface
import GrepCore
import RIBs

public final class ArchiveBuilder: Builder<any ArchiveDependency>, ArchiveBuildable {
    private let viewFactory: any ArchiveViewFactory

    public init(dependency: any ArchiveDependency, viewFactory: any ArchiveViewFactory) {
        self.viewFactory = viewFactory
        super.init(dependency: dependency)
    }

    public func build(listener: any ArchiveListener) -> ArchiveBuild {
        let view = viewFactory.makeArchiveView()
        let interactor = ArchiveInteractor(
            presenter: view,
            repository: dependency.archiveRepository,
            listener: listener
        )
        return ArchiveBuild(router: ArchiveRouter(interactor: interactor, viewController: view), handle: interactor)
    }
}
