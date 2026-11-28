import FeatureArchiveInterface
import RIBs

@MainActor
public final class FakeArchiveView: ArchiveViewContract {
    public weak var listener: (any ArchivePresentableListener)?
    /// 그려진 상태를 순서대로 모은다.
    public private(set) var states: [ArchiveState?] = []
    public var state: ArchiveState? { states.last ?? nil }

    public init() {}

    public func render(_ state: ArchiveState?) { states.append(state) }
}

@MainActor
public final class FakeArchiveViewFactory: ArchiveViewFactory {
    public private(set) var views: [FakeArchiveView] = []

    public init() {}

    public func makeArchiveView() -> any ArchiveViewContract {
        let view = FakeArchiveView()
        views.append(view)
        return view
    }
}

@MainActor
public final class FakeArchiveListener: ArchiveListener {
    public private(set) var expiredCount = 0

    public init() {}

    public func archiveDidExpire() { expiredCount += 1 }
}
