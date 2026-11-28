import GrepCore
import SettingsDomain
import RIBs

@MainActor
public protocol SettingsDependency: Dependency {
    /// 설정이 받는 값. 조립 쪽이 `SettingsRepositoryImpl`(SettingsData)을 넣는다.
    var settingsRepository: any SettingsRepository { get }
}

/// 설정 → 부모(컨테이너).
@MainActor
public protocol SettingsListener: AnyObject {
    /// 서버가 세션 만료로 답했거나 접근 토큰을 받지 못했다.
    func settingsDidExpire()
}

/// 부모(컨테이너) → 설정.
@MainActor
public protocol SettingsHandle: AnyObject {
    /// AI 도구 연결이 바뀌었다(`연결 끊기`). 설정을 연 적이 있을 때만 연결을 다시 받는다.
    func refreshConnectionsIfOpened()
}

@MainActor
public struct SettingsBuild {
    public let router: any ViewableRouting
    public let handle: any SettingsHandle

    public init(router: any ViewableRouting, handle: any SettingsHandle) {
        self.router = router
        self.handle = handle
    }
}

@MainActor
public protocol SettingsBuildable: Buildable {
    func build(listener: any SettingsListener) -> SettingsBuild
}
