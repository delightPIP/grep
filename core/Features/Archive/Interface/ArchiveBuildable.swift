import GrepCore
import RIBs

@MainActor
public protocol ArchiveDependency: Dependency {
    var authService: any AuthService { get }
    var httpTransport: any HTTPTransport { get }
    /// 날짜 묶음(오늘·이번 주·이번 달·그 전)을 나눌 기기 시간대와 지금 시각(ARC-007 값).
    var deviceTime: DeviceTime { get }
}

public extension ArchiveDependency {
    var deviceTime: DeviceTime { .system }
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
