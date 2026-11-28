import FeatureLoggedInUI
import Foundation
import GrepCore
import Observation

/// 하단 탭 3개(터미널·보관함·설정)의 상태와 보관함 로드·설정 로그아웃을 관리한다(MOB-001).
@MainActor @Observable
public final class LoggedInTabsModel {
    public static let defaultPageLimit = 20

    /// MOB-001 규칙 3: 앱을 열면 늘 터미널 탭에서 시작한다.
    public var selectedTab: LoggedInTab
    public private(set) var archivePresentation: ArchivePresentation
    public private(set) var settingsPresentation: SettingsPresentation
    public private(set) var terminalScrollToBottomTrigger = 0
    public private(set) var archiveScrollToTopTrigger = 0
    public private(set) var settingsResetToRootTrigger = 0

    /// MOB-001 규칙 4: 보관함에서 고르기 중이면 탭바를 숨기고 `MPickBar`를 띄운다.
    public var isPickingInArchive: Bool {
        selectedTab == .archive && archivePresentation.pickedCount > 0
    }

    @ObservationIgnored private let archiveLoader: any ArchiveItemLoader
    @ObservationIgnored private let pageLimit: Int
    @ObservationIgnored private let onSignOut: @MainActor () -> Void
    @ObservationIgnored private let onSignOutEverywhere: (@MainActor () -> Void)?
    @ObservationIgnored private let onPickItem: (@MainActor (Int) -> Void)?
    @ObservationIgnored private let onUnpickItem: (@MainActor (Int) -> Void)?
    @ObservationIgnored private let onClearPicked: (@MainActor () -> Void)?
    @ObservationIgnored private let onSessionExpired: (@MainActor () -> Void)?

    @ObservationIgnored private var rawItems: [ItemSummary] = []
    @ObservationIgnored private var nextCursor: String?
    @ObservationIgnored private var hasLoadedArchive = false
    @ObservationIgnored private var itemCount: Int?
    @ObservationIgnored private var pickedNumbers: Set<Int> = []

    public init(
        archiveLoader: any ArchiveItemLoader,
        initialTab: LoggedInTab = .terminal,
        pageLimit: Int = LoggedInTabsModel.defaultPageLimit,
        onSignOut: @escaping @MainActor () -> Void,
        onSignOutEverywhere: (@MainActor () -> Void)? = nil,
        onPickItem: (@MainActor (Int) -> Void)? = nil,
        onUnpickItem: (@MainActor (Int) -> Void)? = nil,
        onClearPicked: (@MainActor () -> Void)? = nil,
        onSessionExpired: (@MainActor () -> Void)? = nil
    ) {
        self.archiveLoader = archiveLoader
        self.selectedTab = initialTab
        self.pageLimit = pageLimit
        self.onSignOut = onSignOut
        self.onSignOutEverywhere = onSignOutEverywhere
        self.onPickItem = onPickItem
        self.onUnpickItem = onUnpickItem
        self.onClearPicked = onClearPicked
        self.onSessionExpired = onSessionExpired
        self.archivePresentation = ArchivePresentation()
        self.settingsPresentation = SettingsPresentation(canSignOutEverywhere: onSignOutEverywhere != nil)
    }

    public func updateTerminalContext(itemCount: Int?, pickedNumbers: Set<Int>) {
        let changed = self.itemCount != itemCount || self.pickedNumbers != pickedNumbers
        self.itemCount = itemCount
        self.pickedNumbers = pickedNumbers
        if changed {
            rebuildArchivePresentation()
        }
    }

    public func loadArchiveIfNeeded() async {
        guard !hasLoadedArchive, !archivePresentation.isLoading else { return }
        await refreshArchive()
    }

    public func refreshArchive() async {
        guard !archivePresentation.isLoading else { return }
        archivePresentation.isLoading = true
        archivePresentation.errorMessage = nil

        let outcome = await archiveLoader.loadPage(limit: pageLimit, cursor: nil)
        archivePresentation.isLoading = false

        switch outcome {
        case .page(let items, let cursor):
            hasLoadedArchive = true
            rawItems = items
            nextCursor = cursor
            archivePresentation.errorMessage = nil
            rebuildArchivePresentation()
        case .sessionExpired:
            onSessionExpired?()
        case .failed(let reason):
            archivePresentation.errorMessage = ArchiveItemMapper.errorMessage(reason)
            rebuildArchivePresentation()
        case .cancelled:
            break
        }
    }

    public func loadMoreArchive() async {
        guard let cursor = nextCursor, !archivePresentation.isLoading, !archivePresentation.isLoadingMore else { return }
        archivePresentation.isLoadingMore = true
        archivePresentation.errorMessage = nil

        let outcome = await archiveLoader.loadPage(limit: pageLimit, cursor: cursor)
        archivePresentation.isLoadingMore = false

        switch outcome {
        case .page(let items, let next):
            let existingNumbers = Set(rawItems.map(\.number))
            let appended = items.filter { !existingNumbers.contains($0.number) }
            rawItems.append(contentsOf: appended)
            nextCursor = next
            archivePresentation.errorMessage = nil
            rebuildArchivePresentation()
        case .sessionExpired:
            onSessionExpired?()
        case .failed(let reason):
            archivePresentation.errorMessage = ArchiveItemMapper.errorMessage(reason)
            rebuildArchivePresentation()
        case .cancelled:
            break
        }
    }

    public func requestSignOut() {
        guard !settingsPresentation.isSigningOut else { return }
        settingsPresentation.isSigningOut = true
        onSignOut()
    }

    /// 설정의 확인 시트에서 `로그아웃`을 누른 뒤에 부른다(ACC-002 규칙 4).
    public func requestSignOutEverywhere() {
        guard !settingsPresentation.isSigningOut, let onSignOutEverywhere else { return }
        settingsPresentation.isSigningOut = true
        onSignOutEverywhere()
    }

    /// 고른 자료를 다시 누르면 뺀다(시안 M6 `빼기`). 빼기 콜백이 없으면 고르기 콜백이 스스로 넣고 뺀다(Example).
    public func togglePick(number: Int) {
        if pickedNumbers.contains(number), let onUnpickItem {
            onUnpickItem(number)
        } else {
            onPickItem?(number)
        }
    }

    public func clearPicked() {
        if let onClearPicked {
            onClearPicked()
        } else {
            pickedNumbers = []
            rebuildArchivePresentation()
        }
    }

    public func moveToTerminalForHandoff() {
        selectedTab = .terminal
    }

    /// MOB-001 규칙 8: 보고 있는 탭을 다시 누르면 각 탭의 시작 위치로 돌아간다.
    public func reselect(tab: LoggedInTab) {
        switch tab {
        case .terminal:
            terminalScrollToBottomTrigger += 1
        case .archive:
            archiveScrollToTopTrigger += 1
        case .settings:
            settingsResetToRootTrigger += 1
        }
    }

    private func rebuildArchivePresentation() {
        let rows = rawItems.map { ArchiveItemMapper.mapRow($0, isPicked: pickedNumbers.contains($0.number)) }
        // ARC-003 규칙 14: `PDF 25 · 글 12 · example.com 3`.
        let pickedSummary = rawItems.filter { pickedNumbers.contains($0.number) }
            .map(ArchiveItemMapper.pickTag)
            .joined(separator: " · ")

        let statusText: String
        if let itemCount {
            statusText = "자료 \(itemCount)"
        } else if hasLoadedArchive {
            statusText = nextCursor == nil ? "자료 \(rows.count)" : "자료 \(rows.count)+"
        } else {
            statusText = "자료"
        }

        archivePresentation = ArchivePresentation(
            statusText: statusText,
            items: rows,
            pickedCount: pickedNumbers.count,
            pickedSummary: pickedSummary.isEmpty ? "\(pickedNumbers.count)건 선택됨" : pickedSummary,
            isLoading: archivePresentation.isLoading,
            isLoadingMore: archivePresentation.isLoadingMore,
            hasMore: nextCursor != nil,
            errorMessage: archivePresentation.errorMessage
        )
    }
}
