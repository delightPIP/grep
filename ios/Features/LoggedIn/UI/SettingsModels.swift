import Foundation

/// 설정 탭 순수 뷰가 그리는 값 전체(시안 `MobileSettings.dc.html` M10).
public struct SettingsPresentation: Equatable, Sendable {
    public var accountLabel: String?
    public var accountDetail: String?
    public var isSigningOut: Bool
    public var appVersionLabel: String

    public init(
        accountLabel: String? = nil,
        accountDetail: String? = nil,
        isSigningOut: Bool = false,
        appVersionLabel: String = "그렙 0.1"
    ) {
        self.accountLabel = accountLabel
        self.accountDetail = accountDetail
        self.isSigningOut = isSigningOut
        self.appVersionLabel = appVersionLabel
    }
}
