import GrepCore
import RIBs

/// 뷰 → 코어.
public enum ArchiveViewAction: Equatable, Sendable {
    /// 보관함 탭을 열었다. 보던 조건의 첫 쪽, 자동 묶음, 묶음, 찾아둔 검색을 받는다.
    case open
    /// 거를 것을 골랐다.
    case select(ArchiveFilter)
    /// 목록 맨 아래 `더 보기`.
    case more
}

@MainActor
public protocol ArchivePresentableListener: AnyObject {
    func handle(_ action: ArchiveViewAction)
}

/// 코어 → 뷰. 처음 열기 전이면 nil을 그린다.
@MainActor
public protocol ArchivePresentable: Presentable {
    var listener: (any ArchivePresentableListener)? { get set }
    func render(_ state: ArchiveState?)
}

@MainActor
public protocol ArchiveViewControllable: ViewControllable {}

@MainActor
public protocol ArchiveViewContract: ArchivePresentable, ArchiveViewControllable {}

@MainActor
public protocol ArchiveViewFactory: AnyObject {
    func makeArchiveView() -> any ArchiveViewContract
}

/// 보관함 화면을 아직 그리지 않는 플랫폼이 쓰는 빈 뷰. 받은 상태를 버린다.
@MainActor
public final class HeadlessArchiveView: ArchiveViewContract {
    public weak var listener: (any ArchivePresentableListener)?

    public init() {}

    public func render(_ state: ArchiveState?) {}
}
