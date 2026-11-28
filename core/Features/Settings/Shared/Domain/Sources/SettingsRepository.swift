import GrepDomain

/// 설정 탭이 받는 값(#168, ACC-002). 접근 토큰이 없으면 `sessionExpired`.
@MainActor
public protocol SettingsRepository: AnyObject {
    /// 계정 칸. `GET /me`에 있는 값만.
    func account() async -> FetchOutcome<SettingsAccount>
    /// AI 도구 연결.
    func connections() async -> FetchOutcome<[ConnectionEntry]>
}
