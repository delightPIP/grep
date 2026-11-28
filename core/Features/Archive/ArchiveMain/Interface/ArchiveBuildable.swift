import ArchiveDomain
import GrepCore
import RIBs

@MainActor
public protocol ArchiveDependency: Dependency {
    /// 보관함이 받는 값. 조립 쪽이 `ArchiveRepositoryImpl`(ArchiveData)을 넣는다.
    var archiveRepository: any ArchiveRepository { get }
}

/// 보관함 → 부모(컨테이너).
@MainActor
public protocol ArchiveListener: AnyObject {
    /// 서버가 세션 만료로 답했거나 접근 토큰을 받지 못했다.
    func archiveDidExpire()
}

/// 부모(컨테이너) → 보관함.
@MainActor
public protocol ArchiveHandle: AnyObject {
    /// 자료가 바뀌었다(저장·버리기·되살리기·묶음 넣기). 보관함을 연 적이 있을 때만 다시 받는다.
    func refreshIfOpened()
}

@MainActor
public struct ArchiveBuild {
    public let router: any ViewableRouting
    public let handle: any ArchiveHandle

    public init(router: any ViewableRouting, handle: any ArchiveHandle) {
        self.router = router
        self.handle = handle
    }
}

@MainActor
public protocol ArchiveBuildable: Buildable {
    func build(listener: any ArchiveListener) -> ArchiveBuild
}
