import SwiftUI

// 모바일 하단 탭 컨테이너(MOB-001, MTabBar.dc.html).
// 탭을 옮겨도 각 탭의 상태를 유지하고(규칙 6), 보고 있는 탭을 다시 누르면 재선택 콜백을 알린다(규칙 8).

public enum LoggedInTab: Int, CaseIterable, Equatable, Sendable {
    case terminal = 0
    case archive = 1
    case settings = 2

    public var title: String {
        switch self {
        case .terminal: "터미널"
        case .archive: "보관함"
        case .settings: "설정"
        }
    }

    public var systemImage: String {
        switch self {
        case .terminal: "terminal"
        case .archive: "archivebox"
        case .settings: "slider.horizontal.3"
        }
    }
}

public struct LoggedInTabContainerView<
    TerminalContent: View,
    ArchiveContent: View,
    SettingsContent: View
>: View {
    @Binding private var selectedTab: LoggedInTab
    private let hidesTabBar: Bool
    private let onReselectTab: ((LoggedInTab) -> Void)?
    private let terminalContent: () -> TerminalContent
    private let archiveContent: () -> ArchiveContent
    private let settingsContent: () -> SettingsContent

    public init(
        selectedTab: Binding<LoggedInTab>,
        hidesTabBar: Bool = false,
        onReselectTab: ((LoggedInTab) -> Void)? = nil,
        @ViewBuilder terminalContent: @escaping () -> TerminalContent,
        @ViewBuilder archiveContent: @escaping () -> ArchiveContent,
        @ViewBuilder settingsContent: @escaping () -> SettingsContent
    ) {
        self._selectedTab = selectedTab
        self.hidesTabBar = hidesTabBar
        self.onReselectTab = onReselectTab
        self.terminalContent = terminalContent
        self.archiveContent = archiveContent
        self.settingsContent = settingsContent
    }

    private let palette = LoggedInPalette.dark

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                tabSlot(isSelected: selectedTab == .terminal) {
                    terminalContent()
                }
                tabSlot(isSelected: selectedTab == .archive) {
                    archiveContent()
                }
                tabSlot(isSelected: selectedTab == .settings) {
                    settingsContent()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !hidesTabBar {
                tabBar
            }
        }
        .background(palette.surface.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func tabSlot<Content: View>(
        isSelected: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .opacity(isSelected ? 1 : 0)
            .allowsHitTesting(isSelected)
            .accessibilityHidden(!isSelected)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(LoggedInTab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab
                Button {
                    if isSelected {
                        onReselectTab?(tab)
                    } else {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18, weight: isSelected ? .bold : .regular))
                        Text(tab.title)
                            .font(.system(size: 12, weight: isSelected ? .bold : .regular, design: .monospaced))
                    }
                    .foregroundStyle(isSelected ? palette.prompt : palette.inkMuted)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(isSelected ? palette.prompt : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab_\(tab.rawValue)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .background(palette.surfaceRaised.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(palette.line).frame(height: 1)
        }
    }
}
