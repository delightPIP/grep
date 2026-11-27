import SwiftUI

// 모바일 하단 탭 컨테이너(MOB-001, MTabBar.dc.html).
// 지금은 터미널 탭을 실제 화면으로 연결하고, 보관함·설정 탭은 다음 이슈에서 붙인다.

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

public struct LoggedInTabContainerView<TerminalContent: View>: View {
    @Binding private var selectedTab: LoggedInTab
    private let hidesTabBar: Bool
    private let terminalContent: () -> TerminalContent

    public init(
        selectedTab: Binding<LoggedInTab>,
        hidesTabBar: Bool = false,
        @ViewBuilder terminalContent: @escaping () -> TerminalContent
    ) {
        self._selectedTab = selectedTab
        self.hidesTabBar = hidesTabBar
        self.terminalContent = terminalContent
    }

    private let surface = Color(red: 0x14 / 255, green: 0x17 / 255, blue: 0x1c / 255)
    private let surfaceRaised = Color(red: 0x1c / 255, green: 0x20 / 255, blue: 0x27 / 255)
    private let line = Color(red: 0x2e / 255, green: 0x34 / 255, blue: 0x3d / 255)
    private let prompt = Color(red: 0x7f / 255, green: 0xe0 / 255, blue: 0xa3 / 255)
    private let ink = Color(red: 0xe7 / 255, green: 0xe9 / 255, blue: 0xec / 255)
    private let inkMuted = Color(red: 0x99 / 255, green: 0xa2 / 255, blue: 0xad / 255)

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                terminalContent()
                    .opacity(selectedTab == .terminal ? 1 : 0)
                    .allowsHitTesting(selectedTab == .terminal)

                if selectedTab == .archive {
                    placeholderTab(title: "보관함", message: "보관함 화면은 다음 이슈에서 연결됩니다.")
                } else if selectedTab == .settings {
                    placeholderTab(title: "설정", message: "설정 화면은 다음 이슈에서 연결됩니다.")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !hidesTabBar {
                tabBar
            }
        }
        .background(surface.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(LoggedInTab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18, weight: isSelected ? .bold : .regular))
                        Text(tab.title)
                            .font(.system(size: 12, weight: isSelected ? .bold : .regular, design: .monospaced))
                    }
                    .foregroundStyle(isSelected ? prompt : inkMuted)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(isSelected ? prompt : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab_\(tab.rawValue)")
            }
        }
        .background(surfaceRaised.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(line).frame(height: 1)
        }
    }

    private func placeholderTab(title: String, message: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text("그렙")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(prompt)
                Text("— \(title)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(ink)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(surfaceRaised.ignoresSafeArea(edges: .top))
            Divider().overlay(line)
            Spacer()
            Text(message)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(inkMuted)
                .padding(24)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(surface)
    }
}
