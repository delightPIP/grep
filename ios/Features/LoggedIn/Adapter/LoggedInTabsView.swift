import FeatureLoggedInUI
import SwiftUI

/// 하단 탭 컨테이너에 터미널·보관함·설정 화면을 엮는 어댑터 뷰.
public struct LoggedInTabsView<TerminalContent: View>: View {
    @Bindable private var model: LoggedInTabsModel
    private let hidesTabBar: Bool
    private let terminalContent: () -> TerminalContent
    @State private var isSettingsModalPresented = false

    public init(
        model: LoggedInTabsModel,
        hidesTabBar: Bool = false,
        @ViewBuilder terminalContent: @escaping () -> TerminalContent
    ) {
        self.model = model
        self.hidesTabBar = hidesTabBar
        self.terminalContent = terminalContent
    }

    public var body: some View {
        LoggedInTabContainerView(
            selectedTab: $model.selectedTab,
            hidesTabBar: hidesTabBar || isSettingsModalPresented || model.isPickingInArchive,
            onReselectTab: { tab in
                model.reselect(tab: tab)
            }
        ) {
            terminalContent()
        } archiveContent: {
            ArchiveView(
                presentation: model.archivePresentation,
                scrollToTopTrigger: model.archiveScrollToTopTrigger,
                onRefresh: {
                    await model.refreshArchive()
                },
                onLoadMore: {
                    Task { await model.loadMoreArchive() }
                },
                onTogglePick: { number in
                    model.togglePick(number: number)
                },
                onMovePickedToTerminal: {
                    model.moveToTerminalForHandoff()
                },
                onClearPicked: {
                    model.clearPicked()
                }
            )
        } settingsContent: {
            SettingsView(
                presentation: model.settingsPresentation,
                resetToRootTrigger: model.settingsResetToRootTrigger,
                onSignOut: {
                    model.requestSignOut()
                },
                onModalVisibilityChange: { visible in
                    isSettingsModalPresented = visible
                }
            )
        }
        .task(id: model.selectedTab) {
            if model.selectedTab == .archive {
                await model.loadArchiveIfNeeded()
            }
        }
    }
}
