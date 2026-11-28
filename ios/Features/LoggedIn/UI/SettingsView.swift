import SwiftUI

/// 설정 탭 순수 SwiftUI 뷰(MOB-001, ACC-001, ACC-002, 시안 `MobileSettings.dc.html` · `UiSettingRow.dc.html`).
public struct SettingsView: View {
    let presentation: SettingsPresentation
    let resetToRootTrigger: Int
    let onSignOut: () -> Void
    let onOpenTrash: (() -> Void)?
    let onSignOutEverywhere: (() -> Void)?
    let onModalVisibilityChange: ((Bool) -> Void)?

    @State private var showSignOutSheet = false
    @State private var showSignOutEverywhereSheet = false

    public init(
        presentation: SettingsPresentation,
        resetToRootTrigger: Int = 0,
        onSignOut: @escaping () -> Void,
        onOpenTrash: (() -> Void)? = nil,
        onSignOutEverywhere: (() -> Void)? = nil,
        onModalVisibilityChange: ((Bool) -> Void)? = nil
    ) {
        self.presentation = presentation
        self.resetToRootTrigger = resetToRootTrigger
        self.onSignOut = onSignOut
        self.onOpenTrash = onOpenTrash
        self.onSignOutEverywhere = onSignOutEverywhere
        self.onModalVisibilityChange = onModalVisibilityChange
    }

    private let palette = LoggedInPalette.dark

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                GrepTopBar(title: "설정", plain: false)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            Color.clear.frame(height: 1).id("settingsTop")

                            sectionHeader("계정", isFirst: true)
                            if let accountLabel = presentation.accountLabel {
                                GrepSettingRow(
                                    label: accountLabel,
                                    sub: presentation.accountDetail ?? "",
                                    actionLabel: nil,
                                    actionKind: .secondary,
                                    isActionDisabled: true,
                                    actionAccessibilityId: nil,
                                    onAction: nil
                                )
                            }
                            GrepSettingRow(
                                label: "이 기기 로그아웃",
                                sub: "이 기기의 터미널 기록도 지움",
                                actionLabel: presentation.isSigningOut ? "로그아웃 중…" : "로그아웃",
                                actionKind: .secondary,
                                isActionDisabled: presentation.isSigningOut,
                                actionAccessibilityId: "settingsSignOutButton"
                            ) {
                                showSignOutSheet = true
                            }
                            // ACC-002 규칙 4: 확인을 받은 뒤 계정의 모든 갱신 토큰과 AI 도구 연결을 끊는다.
                            GrepSettingRow(
                                label: "모든 기기 로그아웃",
                                sub: presentation.canSignOutEverywhere ? "AI 도구 연결도 끊김" : "AI 도구 연결도 끊김 · 준비 중",
                                actionLabel: "모든 기기",
                                actionKind: .danger,
                                isActionDisabled: !presentation.canSignOutEverywhere || presentation.isSigningOut,
                                actionAccessibilityId: "settingsSignOutEverywhereButton"
                            ) {
                                showSignOutEverywhereSheet = true
                            }

                            sectionHeader("AI 도구 연결")
                            GrepSettingRow(
                                label: "연결 목록",
                                sub: "연결 주소 · 끊기 · 준비 중",
                                actionLabel: nil,
                                actionKind: .secondary,
                                isActionDisabled: true,
                                actionAccessibilityId: "settingsFuture_connections",
                                onAction: nil
                            )

                            sectionHeader("화면")
                            GrepSettingRow(
                                label: "테마",
                                sub: "어두운 · 준비 중",
                                actionLabel: "바꾸기",
                                actionKind: .secondary,
                                isActionDisabled: true,
                                actionAccessibilityId: "settingsFuture_theme",
                                onAction: nil
                            )

                            sectionHeader("자료")
                            // ARC-008 규칙 11: 모바일은 설정 탭의 `휴지통`으로 들어간다.
                            GrepSettingRow(
                                label: "휴지통",
                                sub: onOpenTrash == nil ? "30일 뒤 영구 삭제 · 준비 중" : "30일 뒤 영구 삭제",
                                actionLabel: "열기",
                                actionKind: .secondary,
                                isActionDisabled: onOpenTrash == nil,
                                actionAccessibilityId: "settingsTrashButton",
                                onAction: onOpenTrash
                            )

                            sectionHeader("정보")
                            GrepSettingRow(
                                label: presentation.appVersionLabel,
                                sub: "만든 팀 Unwrap",
                                actionLabel: nil,
                                actionKind: .secondary,
                                isActionDisabled: true,
                                actionAccessibilityId: nil,
                                onAction: nil
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                    }
                    .onChange(of: resetToRootTrigger) { _, _ in
                        showSignOutSheet = false
                        showSignOutEverywhereSheet = false
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("settingsTop", anchor: .top)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.surface.ignoresSafeArea())

            if showSignOutSheet {
                GrepBottomSheet(
                    title: "로그아웃? 이 기기",
                    lines: [
                        "이 기기의 터미널 기록도 지움",
                        "다른 기기와 AI 도구 연결은 그대로 둠",
                    ],
                    primaryLabel: "로그아웃",
                    primaryKind: .danger,
                    cancelLabel: "취소",
                    onPrimary: {
                        showSignOutSheet = false
                        onSignOut()
                    },
                    onCancel: {
                        showSignOutSheet = false
                    }
                )
            }

            if showSignOutEverywhereSheet {
                // ACC-002 사용자 문구. 끊길 AI 도구 연결 수는 설정 화면이 모르므로 그 칸을 뺀다(웹과 같음).
                GrepBottomSheet(
                    title: "로그아웃? 모든 기기 (다른 기기는 최대 1시간 뒤)",
                    lines: ["AI 도구 연결도 끊김"],
                    primaryLabel: "로그아웃",
                    primaryKind: .danger,
                    cancelLabel: "취소",
                    onPrimary: {
                        showSignOutEverywhereSheet = false
                        onSignOutEverywhere?()
                    },
                    onCancel: {
                        showSignOutEverywhereSheet = false
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: showSignOutSheet) { _, visible in
            onModalVisibilityChange?(visible)
        }
        .onChange(of: showSignOutEverywhereSheet) { _, visible in
            onModalVisibilityChange?(visible)
        }
    }

    private func sectionHeader(_ title: String, isFirst: Bool = false) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundStyle(palette.ink)
            .padding(.top, isFirst ? 0 : 12)
    }
}
