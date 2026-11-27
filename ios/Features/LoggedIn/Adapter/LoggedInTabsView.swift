import FeatureLoggedInUI
import SwiftUI

/// 하단 탭 컨테이너에 터미널·보관함·설정 화면을 엮는 어댑터 뷰.
public struct LoggedInTabsView<TerminalContent: View>: View {
    @Bindable private var model: LoggedInTabsModel
    private let trashModel: TrashScreenModel?
    private let hidesTabBar: Bool
    private let terminalContent: () -> TerminalContent
    @State private var isSettingsModalPresented = false
    @State private var isTrashOpen = false

    /// `trashModel`이 없으면 설정의 `휴지통`은 `준비 중`으로 막아 둔다.
    public init(
        model: LoggedInTabsModel,
        trashModel: TrashScreenModel? = nil,
        hidesTabBar: Bool = false,
        @ViewBuilder terminalContent: @escaping () -> TerminalContent
    ) {
        self.model = model
        self.trashModel = trashModel
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
            settingsContent
        }
        .onChange(of: model.settingsResetToRootTrigger) { _, _ in
            // MOB-001 규칙 8: 설정 탭을 다시 누르면 설정 첫 화면으로 돌아간다.
            isTrashOpen = false
        }
        .task(id: model.selectedTab) {
            if model.selectedTab == .archive {
                await model.loadArchiveIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var settingsContent: some View {
        if isTrashOpen, let trashModel {
            TrashView(
                presentation: trashModel.presentation,
                onBack: { isTrashOpen = false },
                onRefresh: { await trashModel.refresh() },
                onLoadMore: { Task { await trashModel.loadMore() } },
                onRevive: { number in Task { await trashModel.revive(number: number) } },
                onEmpty: { Task { await trashModel.empty() } },
                onModalVisibilityChange: { visible in
                    isSettingsModalPresented = visible
                }
            )
            .task { await trashModel.refresh() }
        } else {
            SettingsView(
                presentation: model.settingsPresentation,
                resetToRootTrigger: model.settingsResetToRootTrigger,
                onSignOut: {
                    model.requestSignOut()
                },
                onOpenTrash: trashModel.map { _ in { isTrashOpen = true } },
                onModalVisibilityChange: { visible in
                    isSettingsModalPresented = visible
                }
            )
        }
    }
}
