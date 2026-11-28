import Foundation

/// 설정 탭 순수 뷰가 그리는 값 전체(시안 `MobileSettings.dc.html` M10).
public struct SettingsPresentation: Equatable, Sendable {
    public var accountLabel: String?
    public var accountDetail: String?
    public var isSigningOut: Bool
    /// 설정의 `모든 기기 로그아웃`을 쓸 수 있는지(ACC-002 규칙 4). 앱이 이어 주지 않으면 `준비 중`으로 막는다.
    public var canSignOutEverywhere: Bool
    public var appVersionLabel: String

    public init(
        accountLabel: String? = nil,
        accountDetail: String? = nil,
        isSigningOut: Bool = false,
        canSignOutEverywhere: Bool = false,
        appVersionLabel: String = "그렙 0.1"
    ) {
        self.accountLabel = accountLabel
        self.accountDetail = accountDetail
        self.isSigningOut = isSigningOut
        self.canSignOutEverywhere = canSignOutEverywhere
        self.appVersionLabel = appVersionLabel
    }
}
